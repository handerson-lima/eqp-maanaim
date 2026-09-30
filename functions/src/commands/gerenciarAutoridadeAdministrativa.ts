import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  PAPEL_ADMINISTRADOR,
  hashAlteracao,
  papeisEfetivos,
  podeAdministrar,
} from '../domain/autoridadeAdministrativa.js';
import { reconciliarClaimAdministrativa } from '../repositories/autoridadeAdministrativa.js';

type Entrada = { alvoUid?: unknown; commandId?: unknown; expectedVersion?: unknown; correlationId?: unknown; conceder?: unknown };
const OPACA = /^[A-Za-z0-9_-]{16,128}$/;
const erro = (code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted') => new HttpsError(code, 'Operação administrativa indisponível.');

export const alterarAutoridadeAdministrativa = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw erro('permission-denied');
  const input = (request.data ?? {}) as Entrada;
  if (typeof input.alvoUid !== 'string' || typeof input.commandId !== 'string' || typeof input.expectedVersion !== 'number' || typeof input.conceder !== 'boolean') throw erro('invalid-argument');
  if (!OPACA.test(input.commandId)) throw erro('invalid-argument');
  if (input.correlationId !== undefined && (typeof input.correlationId !== 'string' || !OPACA.test(input.correlationId))) throw erro('invalid-argument');
  if (!input.conceder && input.alvoUid === request.auth.uid) throw erro('failed-precondition');
  const payloadHash = hashAlteracao({
    alvoUid: input.alvoUid,
    conceder: input.conceder,
    expectedVersion: input.expectedVersion,
  });
  const correlationId = typeof input.correlationId === 'string' ? input.correlationId : input.commandId;
  const db = getFirestore();
  // Valida a existência antes de qualquer gravação e não inclui uid em erro/auditoria.
  const alvoAuth = await getAuth()
    .getUser(input.alvoUid)
    .catch(() => { throw erro('invalid-argument'); });
  if (alvoAuth.disabled) throw erro('failed-precondition');
  const resultado = await db.runTransaction(async tx => {
    const ator = db.collection('autoridadesAdministrativas').doc(request.auth!.uid);
    const alvo = db.collection('autoridadesAdministrativas').doc(input.alvoUid as string);
    const recibo = db.collection('commands').doc(input.commandId as string);
    const [atorSnap, alvoSnap, reciboSnap] = await Promise.all([tx.get(ator), tx.get(alvo), tx.get(recibo)]);
    if (!podeAdministrar(atorSnap.data())) throw erro('permission-denied');
    if (reciboSnap.exists) {
      const r = reciboSnap.data()!;
      // Replay só é aceito quando o conteúdo é idêntico e do mesmo autor; um
      // comando divergente é recusado, sem reexecutar efeito externo.
      if (r.action !== 'ALTERAR_AUTORIDADE_ADMINISTRATIVA' || r.actorUid !== request.auth!.uid || r.payloadHash !== payloadHash) throw erro('aborted');
      return { alvoUid: input.alvoUid as string, repetido: true };
    }
    const atual = alvoSnap.data();
    const versao = atual?.versao ?? 0;
    if (versao !== input.expectedVersion) throw erro('aborted');
    if (!input.conceder) {
      // Só se revoga autoridade vigente; e nunca a última administração ativa.
      if (atual?.ativa !== true) throw erro('failed-precondition');
      const ativos = await tx.get(db.collection('autoridadesAdministrativas').where('ativa', '==', true));
      if (ativos.docs.filter(d => podeAdministrar(d.data())).length <= 1) throw erro('failed-precondition');
    }
    // Converte para o formato plural canônico preservando papéis co-detidos
    // (ex.: COORDENADOR) e remove o campo legado `papel`.
    const atuais = papeisEfetivos(atual);
    const papeis = input.conceder
      ? [...new Set([...atuais, PAPEL_ADMINISTRADOR])]
      : atuais.filter(papel => papel !== PAPEL_ADMINISTRADOR);
    const proxima = { ativa: papeis.length > 0, papeis, papel: FieldValue.delete(), versao: versao + 1, revisao: (atual?.revisao ?? 0) + 1, claimStatus: 'PENDENTE', atualizadoEm: FieldValue.serverTimestamp() };
    tx.set(alvo, proxima, { merge: true });
    tx.create(recibo, { action: 'ALTERAR_AUTORIDADE_ADMINISTRATIVA', actorUid: request.auth!.uid, payloadHash, correlationId, estado: 'PENDENTE_CLAIM', criadoEm: FieldValue.serverTimestamp() });
    tx.create(db.collection('auditOutbox').doc(input.commandId as string), { commandId: input.commandId, correlationId, actorUid: request.auth!.uid, action: input.conceder ? 'AUTORIDADE_CONCEDIDA' : 'AUTORIDADE_REVOGADA', alvoUid: input.alvoUid, antes: atuais, depois: papeis, criadoEm: FieldValue.serverTimestamp() });
    return { alvoUid: input.alvoUid as string, repetido: false };
  });
  // Conclui a projeção também em replay: se a reconciliação anterior falhou, o
  // recibo ficou PENDENTE_CLAIM e o retry precisa terminá-la.
  const reciboRef = db.collection('commands').doc(input.commandId as string);
  const reciboAtual = await reciboRef.get();
  if (reciboAtual.data()?.estado !== 'COMPLETO') {
    if (!await reconciliarClaimAdministrativa(db, resultado.alvoUid)) throw erro('aborted');
    await reciboRef.update({ estado: 'COMPLETO', concluidoEm: FieldValue.serverTimestamp() });
  }
  return { concluido: true, repetido: resultado.repetido };
});

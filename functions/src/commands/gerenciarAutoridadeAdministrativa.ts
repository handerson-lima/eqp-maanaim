import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { PAPEL_ADMINISTRADOR, hashAlteracao, podeAdministrar } from '../domain/autoridadeAdministrativa.js';
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
  const payloadHash = hashAlteracao({ alvoUid: input.alvoUid, conceder: input.conceder });
  const correlationId = typeof input.correlationId === 'string' ? input.correlationId : input.commandId;
  const db = getFirestore();
  // Valida a existência antes de qualquer gravação e não inclui uid em erro/auditoria.
  try { await getAuth().getUser(input.alvoUid); } catch { throw erro('invalid-argument'); }
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
    const proxima = { ativa: input.conceder, papel: PAPEL_ADMINISTRADOR, versao: versao + 1, revisao: (atual?.revisao ?? 0) + 1, claimStatus: 'PENDENTE', atualizadoEm: FieldValue.serverTimestamp() };
    tx.set(alvo, proxima, { merge: true });
    tx.create(recibo, { action: 'ALTERAR_AUTORIDADE_ADMINISTRATIVA', actorUid: request.auth!.uid, payloadHash, correlationId, estado: 'PENDENTE_CLAIM', criadoEm: FieldValue.serverTimestamp() });
    tx.create(db.collection('auditOutbox').doc(input.commandId as string), { commandId: input.commandId, correlationId, actorUid: request.auth!.uid, action: input.conceder ? 'AUTORIDADE_CONCEDIDA' : 'AUTORIDADE_REVOGADA', antes: atual?.ativa === true, depois: input.conceder, criadoEm: FieldValue.serverTimestamp() });
    return { alvoUid: input.alvoUid as string, repetido: false };
  });
  if (!resultado.repetido) {
    if (!await reconciliarClaimAdministrativa(db, resultado.alvoUid)) throw erro('aborted');
    await db.collection('commands').doc(input.commandId as string).update({ estado: 'COMPLETO', concluidoEm: FieldValue.serverTimestamp() });
  }
  return { concluido: true, repetido: resultado.repetido };
});

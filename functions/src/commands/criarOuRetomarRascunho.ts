import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { hashRascunho, validarRascunho } from '../domain/rascunho.js';

const erroPublico = () => new HttpsError('invalid-argument', 'Não foi possível concluir. Revise os campos e tente novamente.');

export const criarOuRetomarRascunho = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
  let input;
  try { input = validarRascunho(request.data); } catch { throw erroPublico(); }
  const uid = request.auth.uid;
  // O recibo fica ligado ao conteúdo: reutilizar o mesmo commandId com dados
  // diferentes é recusado em vez de descartar a edição silenciosamente.
  const payloadHash = hashRascunho(input);
  const db = getFirestore();
  const ficha = db.collection('fichas').doc(uid);
  const recibo = db.collection('commands').doc(input.commandId);
  const igreja = db.collection('igrejas').doc(input.igrejaId);
  const outboxRecriacao = db.collection('auditOutbox').doc(`${input.commandId}-recriado`);
  const cpf = input.cpf.replace(/\D/g, '');
  const dadosFicha = {
    ownerUid: uid, nomeCompleto: input.nomeCompleto, profissao: input.profissao,
    cpf, igrejaId: input.igrejaId, estado: 'RASCUNHO', versao: 1,
    criadoEm: FieldValue.serverTimestamp(), atualizadoEm: FieldValue.serverTimestamp()
  };
  const resultado = await db.runTransaction(async (tx) => {
    const [reciboAtual, fichaAtual, igrejaAtual] = await Promise.all([tx.get(recibo), tx.get(ficha), tx.get(igreja)]);
    if (reciboAtual.exists) {
      const dados = reciboAtual.data() ?? {};
      if (dados.uid !== uid) throw new HttpsError('permission-denied', 'Operação indisponível.');
      if (dados.payloadHash !== payloadHash) throw new HttpsError('already-exists', 'Operação já registrada.');
      // Recibo sem ficha é estado inconsistente: recria o agregado uma vez,
      // revalidando a igreja e deixando evidência correlacionada.
      if (!fichaAtual.exists) {
        if (!igrejaAtual.exists || igrejaAtual.data()?.ativo !== true) throw erroPublico();
        tx.create(ficha, dadosFicha);
        tx.create(outboxRecriacao, { commandId: input.commandId, correlationId: input.commandId, actorUid: uid, action: 'RASCUNHO_RECRIADO', fichaId: uid, criadoEm: FieldValue.serverTimestamp() });
      }
      return { estado: fichaAtual.data()?.estado ?? 'RASCUNHO', retomado: true };
    }
    // Uma ficha existente é o agregado canônico: um novo commandId só retoma
    // quando o conteúdo é idêntico; dados divergentes são recusados em vez de
    // descartados em silêncio.
    if (fichaAtual.exists) {
      const fichaDados = fichaAtual.data() ?? {};
      const mesmoConteudo =
        fichaDados.nomeCompleto === input.nomeCompleto &&
        fichaDados.profissao === input.profissao &&
        fichaDados.cpf === cpf &&
        fichaDados.igrejaId === input.igrejaId;
      if (!mesmoConteudo) throw new HttpsError('already-exists', 'Operação já registrada.');
      return { estado: fichaDados.estado ?? 'RASCUNHO', retomado: true };
    }
    if (!igrejaAtual.exists || igrejaAtual.data()?.ativo !== true) throw erroPublico();
    tx.create(ficha, dadosFicha);
    tx.create(recibo, { uid, action: 'CRIAR_OU_RETOMAR_RASCUNHO', estado: 'COMPLETO', payloadHash, correlationId: input.commandId, criadoEm: FieldValue.serverTimestamp() });
    tx.create(db.collection('auditOutbox').doc(input.commandId), { commandId: input.commandId, correlationId: input.commandId, actorUid: uid, action: 'RASCUNHO_CRIADO', fichaId: uid, criadoEm: FieldValue.serverTimestamp() });
    return { estado: 'RASCUNHO', retomado: false };
  });
  return resultado;
});

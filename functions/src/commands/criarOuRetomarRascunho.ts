import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { validarRascunho } from '../domain/rascunho.js';

const erroPublico = () => new HttpsError('invalid-argument', 'Não foi possível concluir. Revise os campos e tente novamente.');

export const criarOuRetomarRascunho = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
  let input;
  try { input = validarRascunho(request.data); } catch { throw erroPublico(); }
  const db = getFirestore();
  const ficha = db.collection('fichas').doc(request.auth.uid);
  const recibo = db.collection('commands').doc(input.commandId);
  const igreja = db.collection('igrejas').doc(input.igrejaId);
  const resultado = await db.runTransaction(async (tx) => {
    const [reciboAtual, fichaAtual, igrejaAtual] = await Promise.all([tx.get(recibo), tx.get(ficha), tx.get(igreja)]);
    if (reciboAtual.exists) {
      if (reciboAtual.data()?.uid !== request.auth!.uid) throw new HttpsError('permission-denied', 'Operação indisponível.');
      return { estado: fichaAtual.data()?.estado ?? 'RASCUNHO', retomado: true };
    }
    // Uma ficha existente é o agregado canônico: novo commandId não cria recibo
    // nem outbox para uma retomada que não alterou o domínio.
    if (fichaAtual.exists) return { estado: fichaAtual.data()?.estado ?? 'RASCUNHO', retomado: true };
    if (!igrejaAtual.exists || igrejaAtual.data()?.ativo !== true) throw erroPublico();
    tx.create(ficha, {
      ownerUid: request.auth!.uid, nomeCompleto: input.nomeCompleto, profissao: input.profissao,
      cpf: input.cpf.replace(/\D/g, ''), igrejaId: input.igrejaId, estado: 'RASCUNHO', versao: 1,
      criadoEm: FieldValue.serverTimestamp(), atualizadoEm: FieldValue.serverTimestamp()
    });
    tx.create(recibo, { uid: request.auth!.uid, action: 'CRIAR_OU_RETOMAR_RASCUNHO', estado: 'COMPLETO', criadoEm: FieldValue.serverTimestamp() });
    tx.create(db.collection('auditOutbox').doc(input.commandId), { commandId: input.commandId, action: 'RASCUNHO_CRIADO', fichaId: request.auth!.uid, criadoEm: FieldValue.serverTimestamp() });
    return { estado: 'RASCUNHO', retomado: fichaAtual.exists };
  });
  return resultado;
});

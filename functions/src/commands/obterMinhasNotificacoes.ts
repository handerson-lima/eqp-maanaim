import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterMinhasNotificacoesRepo } from '../repositories/notificacao.js';

/**
 * Consulta as notificações pós-compromisso do voluntário autenticado.
 * Apenas o próprio voluntário pode consultar suas notificações.
 */
export const obterMinhasNotificacoes = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    if (
      request.data?.uid &&
      typeof request.data.uid === 'string' &&
      request.data.uid.trim() !== request.auth.uid
    ) {
      throw new HttpsError(
        'permission-denied',
        'Não é permitido consultar as notificações de outro voluntário.',
      );
    }

    const db = getFirestore();
    const notificacoes = await obterMinhasNotificacoesRepo(db, request.auth.uid);

    return {
      notificacoes,
    };
  },
);

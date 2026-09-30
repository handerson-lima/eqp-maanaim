import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterMinhasParticipacoesRepo } from '../repositories/participacao.js';

/**
 * Consulta as participações cadastradas para o voluntário autenticado.
 * Apenas o próprio voluntário pode consultar suas participações.
 */
export const obterMinhasParticipacoes = onCall(
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
        'Não é permitido consultar as participações de outro voluntário.',
      );
    }

    const db = getFirestore();
    const participacoes = await obterMinhasParticipacoesRepo(db, request.auth.uid);

    return {
      participacoes,
    };
  },
);

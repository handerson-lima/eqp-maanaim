import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterHistoricoAceitesRepo } from '../repositories/termos.js';

/**
 * Consulta o histórico de aceites eletrônicos imutáveis do voluntário autenticado.
 */
export const obterHistoricoAceites = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    try {
      const aceites = await obterHistoricoAceitesRepo(db, request.auth.uid);
      return { aceites };
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível obter o histórico de aceites. Tente novamente mais tarde.',
      );
    }
  },
);

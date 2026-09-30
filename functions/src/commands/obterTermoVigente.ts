import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterTermoVigenteRepo } from '../repositories/termos.js';

const erro = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted',
) => new HttpsError(code, 'Operação indisponível.');

/**
 * Obtém os dados da versão atualmente vigente do termo para leitura.
 */
export const obterTermoVigente = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');

    const db = getFirestore();
    const termoId =
      typeof request.data?.termoId === 'string' && request.data.termoId.trim()
        ? request.data.termoId.trim()
        : undefined;

    try {
      const versaoVigente = await obterTermoVigenteRepo(db, termoId);
      return { versaoVigente };
    } catch (falha) {
      if (falha instanceof HttpsError) throw falha;
      throw falha;
    }
  },
);

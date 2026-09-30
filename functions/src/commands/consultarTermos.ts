import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { SemAutoridadeError } from '../domain/termos.js';
import { consultarTermosRepo } from '../repositories/termos.js';

const erro = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted',
) => new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Consulta o acervo completo de versões de termos para administradores.
 */
export const consultarTermos = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');

    const db = getFirestore();
    const termoId =
      typeof request.data?.termoId === 'string' && request.data.termoId.trim()
        ? request.data.termoId.trim()
        : undefined;

    try {
      const termo = await consultarTermosRepo(db, request.auth.uid, termoId);
      return { termo };
    } catch (falha) {
      if (falha instanceof HttpsError) throw falha;
      if (falha instanceof SemAutoridadeError) throw erro('permission-denied');
      throw falha;
    }
  },
);

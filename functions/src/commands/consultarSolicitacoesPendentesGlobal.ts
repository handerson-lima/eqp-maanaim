import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { consultarSolicitacoesPendentesGlobalRepo } from '../repositories/solicitacoesPendentes.js';

/**
 * Consulta read-only de todas as solicitações pendentes no sistema,
 * agrupáveis por equipes, exclusiva para administradores gerais autorizados.
 */
export const consultarSolicitacoesPendentesGlobal = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    try {
      const resultado = await consultarSolicitacoesPendentesGlobalRepo(
        db,
        request.auth.uid,
      );
      return resultado;
    } catch (erro) {
      if (
        erro instanceof Error &&
        erro.message === 'SEM_AUTORIDADE_ADMINISTRATIVA'
      ) {
        throw new HttpsError(
          'permission-denied',
          'Operação exclusiva para administradores autorizados.',
        );
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar as solicitações pendentes. Tente novamente.',
      );
    }
  },
);

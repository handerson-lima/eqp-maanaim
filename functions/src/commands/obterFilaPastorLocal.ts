import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterFilaPastorLocalRepo } from '../repositories/decisaoPastor.js';

/**
 * Retorna as solicitações de voluntários pendentes de avaliação do Pastor Local
 * estritamente pertencentes às igrejas sob responsabilidade vigente do pastor autenticado.
 */
export const obterFilaPastorLocal = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    try {
      const resultado = await obterFilaPastorLocalRepo(db, request.auth.uid);
      return resultado;
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar a fila pastoral. Tente novamente mais tarde.',
      );
    }
  },
);

import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterFilaResponsavelEquipeRepo } from '../repositories/decisaoResponsavelEquipe.js';

/**
 * Retorna as participações de voluntários pendentes de avaliação do Responsável de Equipe
 * estritamente pertencentes às equipes sob responsabilidade vigente do usuário autenticado.
 */
export const obterFilaResponsavelEquipe = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    try {
      const resultado = await obterFilaResponsavelEquipeRepo(db, request.auth.uid);
      return resultado;
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar a fila do responsável de equipe. Tente novamente mais tarde.',
      );
    }
  },
);

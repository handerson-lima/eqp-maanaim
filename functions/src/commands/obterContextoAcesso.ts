import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterContextoAcessoRepo } from '../repositories/contextoAcesso.js';

/**
 * Consulta autenticada de contexto de acesso e capacidades mínimas do usuário (Story 8.3).
 * Revalida no servidor autoridade administrativa, coordenação e vínculos pastorais/equipe
 * ativos sem realizar varreduras em coleções administrativas no cliente (AD-01, AD-02, AD-09).
 */
export const obterContextoAcesso = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    try {
      const email = typeof request.auth.token.email === 'string' ? request.auth.token.email : undefined;
      const resultado = await obterContextoAcessoRepo(db, request.auth.uid, email);
      return resultado;
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar o contexto de acesso. Tente novamente mais tarde.',
      );
    }
  },
);

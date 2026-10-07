import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { SemAutoridadeCoordenadorError } from '../domain/decisaoCoordenador.js';
import { obterFilaCoordenadorRepo } from '../repositories/decisaoCoordenador.js';

/**
 * Consulta as solicitações que contêm ao menos uma participação elegível
 * para a homologação final do Coordenador Geral (`AGUARDANDO_COORDENADOR`).
 */
export const obterFilaCoordenador = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    try {
      const resultado = await obterFilaCoordenadorRepo(db, request.auth.uid);
      return resultado;
    } catch (erro) {
      if (erro instanceof SemAutoridadeCoordenadorError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar a fila do coordenador. Tente novamente mais tarde.',
      );
    }
  },
);

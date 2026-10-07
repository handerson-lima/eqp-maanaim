import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { AcessoNaoAutorizadoError } from '../domain/consultaHistorico.js';
import { consultarLinhaDoTempoAutorizadaRepo } from '../repositories/consultaHistorico.js';

export interface EntradaConsultarLinhaDoTempoPayload {
  fichaId?: string;
  participacaoId?: string;
}

/**
 * Consulta autorizada da linha do tempo histórica com projeção append-only
 * e sanitização contextual por perfil do requisitante (AD-9, AD-12, FR28).
 */
export const consultarLinhaDoTempoAutorizada = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const payload = (request.data ?? {}) as EntradaConsultarLinhaDoTempoPayload;
    const db = getFirestore();

    try {
      const resultado = await consultarLinhaDoTempoAutorizadaRepo(
        db,
        request.auth.uid,
        payload.fichaId,
        payload.participacaoId,
      );

      return resultado;
    } catch (error) {
      if (error instanceof AcessoNaoAutorizadoError) {
        throw new HttpsError('permission-denied', 'Acesso não autorizado para o histórico solicitado.');
      }
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Falha ao consultar a linha do tempo autorizada.',
      );
    }
  },
);

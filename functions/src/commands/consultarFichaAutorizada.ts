import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { AcessoNaoAutorizadoError } from '../domain/consultaHistorico.js';
import { consultarFichaAutorizadaRepo } from '../repositories/consultaHistorico.js';

export interface EntradaConsultarFichaAutorizadaPayload {
  fichaId?: string;
}

/**
 * Consulta autorizada de ficha e participações aplicando revalidação estrita
 * de identidade, papéis, vínculos vigentes e escopo em runtime (AD-9, AD-12).
 */
export const consultarFichaAutorizada = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const payload = (request.data ?? {}) as EntradaConsultarFichaAutorizadaPayload;
    const db = getFirestore();

    try {
      const resultado = await consultarFichaAutorizadaRepo(
        db,
        request.auth.uid,
        payload.fichaId,
      );

      return resultado;
    } catch (error) {
      if (error instanceof AcessoNaoAutorizadoError) {
        throw new HttpsError('permission-denied', 'Acesso não autorizado para a ficha solicitada.');
      }
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Falha ao consultar a ficha autorizada.',
      );
    }
  },
);

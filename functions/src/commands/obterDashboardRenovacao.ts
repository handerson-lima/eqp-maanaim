import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ParametroInvalidoDashboardError,
  PermissaoNegadaDashboardError,
  validarEntradaDashboard,
} from '../domain/dashboardRenovacao.js';
import { obterDashboardRenovacaoRepo } from '../repositories/dashboardRenovacao.js';

/**
 * Endpoint de consulta seguro dos Dashboards de Renovação por Papel (Story 5.4).
 * Revalida dinamicamente identidade, autoridade administrativa e vínculos de pastoreio/equipe
 * no Firestore sem vazar dados fora do escopo legítimo (AD-9, AD-12).
 */
export const obterDashboardRenovacao = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    try {
      const entrada = validarEntradaDashboard(request.data);
      const db = getFirestore();
      const resultado = await obterDashboardRenovacaoRepo(db, request.auth.uid, entrada);
      return resultado;
    } catch (erro) {
      if (erro instanceof PermissaoNegadaDashboardError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof ParametroInvalidoDashboardError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar os dados do dashboard de renovação.',
      );
    }
  },
);

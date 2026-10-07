import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  SolicitacaoReconciliacaoInvalidaError,
  validarParametrosReconciliacao,
} from '../domain/auditoria.js';
import { reconciliarAuditoriaRepo } from '../repositories/auditoria.js';
import { validarAutoridadeCoordenador } from '../repositories/decisaoCoordenador.js';

/**
 * Callable autenticada para acionamento administrativo do job de reconciliação de auditoria (AD-8/AD-10).
 * Restrita a Administrador do Sistema ou Coordenador Geral.
 */
export const reconciliarAuditoria = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();
    const uid = request.auth.uid;
    const ehAdmin = Boolean(request.auth.token.maanaimAdmin);

    const autoridade = await validarAutoridadeCoordenador(db, uid);
    if (!autoridade.autorizado && !ehAdmin) {
      throw new HttpsError(
        'permission-denied',
        'Apenas a coordenação geral ou administração do sistema pode acionar a reconciliação de auditoria.',
      );
    }

    let params: { limite: number };
    try {
      params = validarParametrosReconciliacao(request.data);
    } catch (err) {
      if (err instanceof SolicitacaoReconciliacaoInvalidaError) {
        throw new HttpsError('invalid-argument', err.message);
      }
      throw new HttpsError('invalid-argument', 'Parâmetros de reconciliação inválidos.');
    }

    try {
      const resultado = await reconciliarAuditoriaRepo(db, params);
      return resultado;
    } catch (err) {
      if (err instanceof HttpsError) {
        throw err;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível concluir a reconciliação de auditoria. Tente novamente mais tarde.',
      );
    }
  },
);

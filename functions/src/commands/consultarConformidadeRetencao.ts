import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { consultarConformidadeRetencaoRepo } from '../repositories/retencao.js';
import { validarAutoridadeCoordenador } from '../repositories/decisaoCoordenador.js';

/**
 * Callable autenticada que devolve apenas indicadores de conformidade de retenção
 * (contagens agregadas; nunca IDs de voluntários) à coordenação/administração (AD-12).
 */
export const consultarConformidadeRetencao = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    const autoridade = await validarAutoridadeCoordenador(db, request.auth.uid);
    if (!autoridade.autorizado) {
      throw new HttpsError(
        'permission-denied',
        'Apenas a coordenação geral ou administração pode consultar indicadores de retenção.',
      );
    }

    try {
      return await consultarConformidadeRetencaoRepo(db, {
        agoraIso: new Date().toISOString(),
      });
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar os indicadores de retenção. Tente novamente mais tarde.',
      );
    }
  },
);

import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  SolicitacaoRetencaoInvalidaError,
  validarRotinaRetencao,
} from '../domain/retencao.js';
import { executarRotinaRetencaoRepo } from '../repositories/retencao.js';
import { validarAutoridadeCoordenador } from '../repositories/decisaoCoordenador.js';

/**
 * Callable autenticada da rotina de retenção, anonimização e expurgo (AD-12 / LGPD).
 *
 * Restrita a Coordenador Geral ou Administrador vigente. `dryRun` é o padrão:
 * a execução real exige `dryRun: false` explícito. O relógio e o `retencaoAte`
 * são sempre do servidor (UTC).
 */
export const executarRotinaRetencao = onCall(
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
        'Apenas a coordenação geral ou administração pode executar a rotina de retenção.',
      );
    }

    let entrada;
    try {
      entrada = validarRotinaRetencao(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoRetencaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    // Relógio e ator sempre do servidor: o cliente não controla o tempo nem a autoria.
    entrada = {
      ...entrada,
      agoraIso: new Date().toISOString(),
      atorUid: request.auth.uid,
    };

    try {
      return await executarRotinaRetencaoRepo(db, entrada);
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível executar a rotina de retenção. Tente novamente mais tarde.',
      );
    }
  },
);

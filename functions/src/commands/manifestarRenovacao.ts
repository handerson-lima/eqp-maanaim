import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  FichaNaoEncontradaError,
  JanelaRenovacaoFechadaError,
  ParticipacaoNaoElegivelError,
  ParticipacaoNaoEncontradaError,
  PermissaoNegadaError,
  SolicitacaoInvalidaError,
  validarManifestarRenovacao,
} from '../domain/manifestarRenovacao.js';
import { executarManifestarRenovacaoRepo } from '../repositories/manifestarRenovacao.js';

/**
 * Callable autenticada que registra a manifestação de renovação anual do voluntário
 * por equipe (Story 5.2).
 *
 * Restrito estritamente ao próprio voluntário titular da ficha (AD-9 / AD-11).
 */
export const manifestarRenovacao = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarManifestarRenovacao(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await executarManifestarRenovacaoRepo(
        db,
        {
          commandId: entrada.commandId,
          correlationId: entrada.correlationId,
          uid: request.auth.uid,
        },
        entrada,
      );

      return resultado;
    } catch (erro) {
      if (erro instanceof FichaNaoEncontradaError) {
        throw new HttpsError('not-found', erro.message);
      }
      if (erro instanceof ParticipacaoNaoEncontradaError) {
        throw new HttpsError('not-found', erro.message);
      }
      if (erro instanceof PermissaoNegadaError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof ParticipacaoNaoElegivelError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof JanelaRenovacaoFechadaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ComandoDivergenteError) {
        throw new HttpsError(
          'invalid-argument',
          'Operação já registrada com dados divergentes.',
        );
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível registrar a manifestação de renovação. Tente novamente mais tarde.',
      );
    }
  },
);

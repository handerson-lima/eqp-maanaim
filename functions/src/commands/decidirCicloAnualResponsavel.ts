import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  CicloNaoElegivelError,
  CicloNaoEncontradoError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  JustificativaObrigatoriaError,
  ParticipacaoCicloNaoEncontradaError,
  SemVinculoResponsavelEquipeError,
  validarDecidirCicloAnualResponsavel,
} from '../domain/decisaoCicloAnual.js';
import { decidirCicloAnualResponsavelRepo } from '../repositories/decisaoCicloAnual.js';

/**
 * Callable autenticada para o Responsável de Equipe vigente deliberar sobre a renovação
 * de um ciclo anual de uma participação (Story 5.3).
 */
export const decidirCicloAnualResponsavel = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarDecidirCicloAnualResponsavel(request.data);
    } catch (erro) {
      if (erro instanceof JustificativaObrigatoriaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof DecisaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await decidirCicloAnualResponsavelRepo(
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
      if (erro instanceof CicloNaoEncontradoError) {
        throw new HttpsError('not-found', erro.message);
      }
      if (erro instanceof ParticipacaoCicloNaoEncontradaError) {
        throw new HttpsError('not-found', erro.message);
      }
      if (erro instanceof SemVinculoResponsavelEquipeError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof CicloNaoElegivelError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ConflitoVersaoError) {
        throw new HttpsError('aborted', erro.message);
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
        'Não foi possível registrar a decisão do responsável no ciclo anual.',
      );
    }
  },
);

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
  ReuniaoPastoresNaoConfirmadaError,
  SemAutoridadeCoordenadorError,
  validarConcluirCicloAnualCoordenador,
} from '../domain/decisaoCicloAnual.js';
import { concluirCicloAnualCoordenadorRepo } from '../repositories/decisaoCicloAnual.js';

/**
 * Callable autenticada para o Coordenador Geral homologar e concluir a renovação
 * do ciclo anual com cálculo de nova vigência (Story 5.3).
 */
export const concluirCicloAnualCoordenador = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarConcluirCicloAnualCoordenador(request.data);
    } catch (erro) {
      if (erro instanceof ReuniaoPastoresNaoConfirmadaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
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
      const resultado = await concluirCicloAnualCoordenadorRepo(
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
      if (erro instanceof SemAutoridadeCoordenadorError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof CicloNaoElegivelError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ReuniaoPastoresNaoConfirmadaError) {
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
        'Não foi possível concluir o ciclo anual na coordenação.',
      );
    }
  },
);

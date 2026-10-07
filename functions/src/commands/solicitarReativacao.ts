import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  EquipeJaEmAndamentoError,
  FichaNaoElegivelParaReativacaoError,
  FichaNaoEncontradaError,
  ParticipacaoNaoEncontradaError,
  ParticipacaoNaoTerminalError,
  PermissaoNegadaError,
  SolicitacaoReativacaoInvalidaError,
  TermoInvalidoError,
  validarSolicitarReativacao,
} from '../domain/solicitarReativacao.js';
import { solicitarReativacaoRepo } from '../repositories/solicitarReativacao.js';

/**
 * Callable autenticada que permite a um voluntário com ficha ou participação
 * em estado terminal (CANCELADA, INATIVA, EXPIRADA) solicitar a reativação
 * iniciando um novo ciclo de aprovação completo (Pastor -> Responsável -> Coordenador).
 */
export const solicitarReativacao = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    if (
      request.data?.uid &&
      typeof request.data.uid === 'string' &&
      request.data.uid.trim() !== request.auth.uid
    ) {
      throw new HttpsError(
        'permission-denied',
        'Não é permitido solicitar reativação em nome de outro voluntário.',
      );
    }

    let entrada;
    try {
      entrada = validarSolicitarReativacao(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoReativacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação de reativação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await solicitarReativacaoRepo(
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
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof FichaNaoElegivelParaReativacaoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ParticipacaoNaoEncontradaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ParticipacaoNaoTerminalError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof TermoInvalidoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof EquipeInvalidaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof EquipeJaEmAndamentoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof PermissaoNegadaError) {
        throw new HttpsError('permission-denied', erro.message);
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
        'Não foi possível solicitar a reativação. Tente novamente mais tarde.',
      );
    }
  },
);

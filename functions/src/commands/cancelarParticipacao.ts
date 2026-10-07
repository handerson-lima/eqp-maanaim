import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  MotivoObrigatorioLiderancaError,
  ParticipacaoJaTerminalError,
  ParticipacaoNaoEncontradaError,
  SolicitacaoInvalidaError,
  validarCancelarParticipacao,
} from '../domain/cancelarParticipacao.js';
import { executarCancelarParticipacaoRepo } from '../repositories/cancelamento.js';

/**
 * Callable autenticada que cancela uma participação individual.
 *
 * Pode ser acionada por:
 * - Voluntário titular da participação
 * - Pastor Local vigente da igreja do voluntário
 * - Responsável de Equipe vigente da respectiva equipe
 * - Coordenador Geral
 */
export const cancelarParticipacao = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarCancelarParticipacao(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await executarCancelarParticipacaoRepo(
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
      if (erro instanceof ParticipacaoNaoEncontradaError) {
        throw new HttpsError('not-found', erro.message);
      }
      if (erro instanceof ParticipacaoJaTerminalError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ConflitoVersaoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof MotivoObrigatorioLiderancaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof AutoridadeInsuficienteError) {
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
        'Não foi possível cancelar a participação. Tente novamente mais tarde.',
      );
    }
  },
);

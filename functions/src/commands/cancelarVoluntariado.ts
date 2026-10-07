import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  FichaJaTerminalError,
  FichaNaoEncontradaError,
  MotivoObrigatorioLiderancaError,
  SolicitacaoInvalidaError,
  validarCancelarVoluntariado,
} from '../domain/cancelarVoluntariado.js';
import { executarCancelarVoluntariadoRepo } from '../repositories/cancelamento.js';

/**
 * Callable autenticada que cancela todas as participações e a ficha permanente.
 *
 * Pode ser acionada por:
 * - Voluntário titular da ficha
 * - Pastor Local vigente da igreja do voluntário
 * - Coordenador Geral
 *
 * Responsável de Equipe NÃO tem autoridade para cancelar toda a ficha.
 */
export const cancelarVoluntariado = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarCancelarVoluntariado(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await executarCancelarVoluntariadoRepo(
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
      if (erro instanceof FichaJaTerminalError) {
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
        'Não foi possível cancelar o voluntariado. Tente novamente mais tarde.',
      );
    }
  },
);

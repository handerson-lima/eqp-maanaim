import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  FichaNaoAguardandoCoordenadorError,
  FichaNaoEncontradaError,
  JustificativaObrigatoriaError,
  ReuniaoPastoresNaoConfirmadaError,
  SemAutoridadeCoordenadorError,
  validarDecidirAtivacaoCoordenador,
} from '../domain/decisaoCoordenador.js';
import { decidirAtivacaoCoordenadorRepo } from '../repositories/decisaoCoordenador.js';

/**
 * Registra a decisão final do Coordenador Geral, confirmando a consulta
 * na Reunião de Pastores, ativando as participações elegíveis e gerando
 * o ciclo anual de voluntariado de 1 ano.
 */
export const decidirAtivacaoCoordenador = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarDecidirAtivacaoCoordenador(request.data);
    } catch (erro) {
      if (erro instanceof ReuniaoPastoresNaoConfirmadaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof JustificativaObrigatoriaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof DecisaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de decisão do coordenador inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await decidirAtivacaoCoordenadorRepo(
        db,
        {
          commandId: entrada.commandId,
          correlationId: entrada.correlationId,
          coordenadorUid: request.auth.uid,
        },
        entrada,
      );

      return resultado;
    } catch (erro) {
      if (erro instanceof SemAutoridadeCoordenadorError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof FichaNaoEncontradaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof FichaNaoAguardandoCoordenadorError) {
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
        'Não foi possível registrar a decisão do coordenador. Tente novamente mais tarde.',
      );
    }
  },
);

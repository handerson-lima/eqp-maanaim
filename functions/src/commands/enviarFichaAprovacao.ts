import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DadosIncompletosError,
  EnvioInvalidoError,
  EquipeInativaError,
  FichaNaoEncontradaError,
  FichaNaoRascunhoError,
  IgrejaInativaError,
  PermissaoNegadaError,
  SemParticipacoesError,
  TermoNaoAceitoError,
  validarEnviarFicha,
} from '../domain/enviarFicha.js';
import { enviarFichaAprovacaoRepo } from '../repositories/enviarFicha.js';

/**
 * Submete formalmente a ficha do voluntário autenticado para aprovação do Pastor Local.
 */
export const enviarFichaAprovacao = onCall(
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
        'Não é permitido enviar a ficha em nome de outro voluntário.',
      );
    }

    let entrada;
    try {
      entrada = validarEnviarFicha(request.data);
    } catch (erro) {
      if (erro instanceof EnvioInvalidoError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de envio inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await enviarFichaAprovacaoRepo(
        db,
        {
          commandId: entrada.commandId,
          correlationId: entrada.correlationId,
          uid: request.auth.uid,
        },
        entrada,
      );

      return {
        sucesso: true,
        repetido: resultado.repetido,
        estado: resultado.estado,
        versao: resultado.versao,
        proximaAcao: resultado.proximaAcao,
        igrejaId: resultado.igrejaId,
        enviadoEm: resultado.enviadoEm,
      };
    } catch (erro) {
      if (erro instanceof FichaNaoEncontradaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof FichaNaoRascunhoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ConflitoVersaoError) {
        throw new HttpsError('aborted', erro.message);
      }
      if (erro instanceof DadosIncompletosError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof SemParticipacoesError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof EquipeInativaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof TermoNaoAceitoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof IgrejaInativaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ComandoDivergenteError) {
        throw new HttpsError(
          'invalid-argument',
          'Operação já registrada com dados divergentes.',
        );
      }
      if (erro instanceof PermissaoNegadaError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível enviar a ficha para aprovação. Tente novamente mais tarde.',
      );
    }
  },
);

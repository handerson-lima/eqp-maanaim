import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  CpfInvalidoError,
  FichaInvalidaError,
  IgrejaInvalidaError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  validarSalvarFicha,
} from '../domain/ficha.js';
import { salvarMinhaFichaRepo } from '../repositories/ficha.js';

/**
 * Cria ou atualiza a ficha permanente do voluntário autenticado com persistência transacional,
 * idempotência por commandId e auditoria em outbox.
 */
export const salvarMinhaFicha = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarSalvarFicha(request.data);
    } catch (erro) {
      if (erro instanceof CpfInvalidoError) {
        throw new HttpsError('invalid-argument', 'CPF inválido');
      }
      if (erro instanceof FichaInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados cadastrais inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await salvarMinhaFichaRepo(
        db,
        { commandId: entrada.commandId, uid: request.auth.uid },
        entrada,
      );

      return {
        sucesso: true,
        repetido: resultado.repetido,
        ficha: resultado.ficha,
      };
    } catch (erro) {
      if (erro instanceof IgrejaInvalidaError) {
        throw new HttpsError('invalid-argument', 'Igreja inválida ou inativa');
      }
      if (erro instanceof ComandoDivergenteError) {
        throw new HttpsError(
          'already-exists',
          'Operação já registrada com dados divergentes.',
        );
      }
      if (erro instanceof ConflitoVersaoError) {
        throw new HttpsError(
          'aborted',
          'Conflito de concorrência ao atualizar ficha.',
        );
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível salvar a ficha. Tente novamente mais tarde.',
      );
    }
  },
);

import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  DeclaracaoNaoInformadaError,
  EquipesNaoSelecionadasError,
  FichaNaoEditavelError,
  FichaNaoEncontradaError,
  PermissaoNegadaError,
  TermoInvalidoError,
  TermoNaoVigenteError,
  validarAceitarTermoVigente,
} from '../domain/termos.js';
import { aceitarTermoVigenteRepo } from '../repositories/termos.js';

/**
 * Registra o aceite eletrônico e auditável da versão vigente do termo de voluntariado.
 */
export const aceitarTermoVigente = onCall(
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
        'Não é permitido registrar o aceite em nome de outro voluntário.',
      );
    }

    let entrada;
    try {
      entrada = validarAceitarTermoVigente(request.data);
    } catch (erro) {
      if (
        erro instanceof TermoInvalidoError ||
        erro instanceof DeclaracaoNaoInformadaError
      ) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de aceite inválidos.');
    }

    const db = getFirestore();

    try {
      const comprovante = await aceitarTermoVigenteRepo(
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
        repetido: Boolean(comprovante.repetido),
        comprovante,
      };
    } catch (erro) {
      if (erro instanceof DeclaracaoNaoInformadaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof FichaNaoEncontradaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof FichaNaoEditavelError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof EquipesNaoSelecionadasError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof TermoNaoVigenteError) {
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
        'Não foi possível registrar o aceite. Tente novamente mais tarde.',
      );
    }
  },
);

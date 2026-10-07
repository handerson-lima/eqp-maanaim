import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  EquipeJaSolicitadaError,
  FichaNaoAtivaError,
  FichaNaoEncontradaError,
  PermissaoNegadaError,
  SolicitacaoInvalidaError,
  TermoInvalidoError,
  validarSolicitarEquipeAdicional,
} from '../domain/solicitarEquipeAdicional.js';
import { solicitarEquipeAdicionalRepo } from '../repositories/solicitarEquipeAdicional.js';

/**
 * Callable autenticada que permite a um voluntário com ficha ATIVA
 * solicitar participação em equipe adicional administrável do catálogo.
 */
export const solicitarEquipeAdicional = onCall(
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
        'Não é permitido solicitar equipe em nome de outro voluntário.',
      );
    }

    let entrada;
    try {
      entrada = validarSolicitarEquipeAdicional(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await solicitarEquipeAdicionalRepo(
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
      if (erro instanceof FichaNaoAtivaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof TermoInvalidoError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof EquipeInvalidaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof EquipeJaSolicitadaError) {
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
        'Não foi possível solicitar a equipe adicional. Tente novamente mais tarde.',
      );
    }
  },
);

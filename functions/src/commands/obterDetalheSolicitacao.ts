import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  SemVinculoVigenteError,
  SolicitacaoNaoEncontradaError,
} from '../domain/detalheSolicitacao.js';
import { obterDetalheSolicitacaoRepo } from '../repositories/detalheSolicitacao.js';

/**
 * Retorna o detalhe interno de uma solicitação, reautorizando o vínculo/papel
 * do chamador no momento da abertura (AD-2). Um deep link aberto após troca ou
 * expiração de vínculo é bloqueado com `permission-denied`.
 */
export const obterDetalheSolicitacao = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const fichaId =
      typeof request.data?.fichaId === 'string' ? request.data.fichaId.trim() : '';
    if (!fichaId) {
      throw new HttpsError(
        'invalid-argument',
        'Informe a solicitação que deseja consultar.',
      );
    }

    const db = getFirestore();

    try {
      return await obterDetalheSolicitacaoRepo(db, request.auth.uid, fichaId);
    } catch (erro) {
      if (erro instanceof SemVinculoVigenteError) {
        throw new HttpsError('permission-denied', erro.message);
      }
      if (erro instanceof SolicitacaoNaoEncontradaError) {
        throw new HttpsError('not-found', erro.message);
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível consultar a solicitação. Tente novamente mais tarde.',
      );
    }
  },
);

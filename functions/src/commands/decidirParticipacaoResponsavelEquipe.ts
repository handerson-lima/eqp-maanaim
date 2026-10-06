import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  JustificativaObrigatoriaError,
  ParticipacaoNaoAguardandoResponsavelError,
  ParticipacaoNaoEncontradaError,
  SemVinculoResponsavelEquipeError,
  validarDecidirParticipacaoResponsavel,
} from '../domain/decisaoResponsavelEquipe.js';
import { decidirParticipacaoResponsavelEquipeRepo } from '../repositories/decisaoResponsavelEquipe.js';

/**
 * Registra formal e atomicamente a decisão do Responsável Canônico de Equipe
 * sobre a participação individual do voluntário (`APROVADO` ou `DESFAVORAVEL`).
 */
export const decidirParticipacaoResponsavelEquipe = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarDecidirParticipacaoResponsavel(request.data);
    } catch (erro) {
      if (erro instanceof JustificativaObrigatoriaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof DecisaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de decisão do responsável de equipe inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await decidirParticipacaoResponsavelEquipeRepo(
        db,
        {
          commandId: entrada.commandId,
          correlationId: entrada.correlationId,
          responsavelUid: request.auth.uid,
        },
        entrada,
      );

      return resultado;
    } catch (erro) {
      if (erro instanceof ParticipacaoNaoEncontradaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof ParticipacaoNaoAguardandoResponsavelError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof SemVinculoResponsavelEquipeError) {
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
        'Não foi possível registrar a decisão do responsável de equipe. Tente novamente mais tarde.',
      );
    }
  },
);

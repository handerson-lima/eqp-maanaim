import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  FichaNaoAguardandoPastorError,
  FichaNaoEncontradaError,
  JustificativaObrigatoriaError,
  SemVinculoPastoralError,
  validarDecidirFichaPastor,
} from '../domain/decisaoPastor.js';
import { decidirFichaPastorLocalRepo } from '../repositories/decisaoPastor.js';

/**
 * Registra formal e atomicamente a decisão do Pastor Local vigente
 * sobre uma solicitação de voluntariado (`APROVADO` ou `DESFAVORAVEL`).
 */
export const decidirFichaPastorLocal = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let entrada;
    try {
      entrada = validarDecidirFichaPastor(request.data);
    } catch (erro) {
      if (erro instanceof JustificativaObrigatoriaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      if (erro instanceof DecisaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de decisão pastoral inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await decidirFichaPastorLocalRepo(
        db,
        {
          commandId: entrada.commandId,
          correlationId: entrada.correlationId,
          pastorUid: request.auth.uid,
        },
        entrada,
      );

      return resultado;
    } catch (erro) {
      if (erro instanceof FichaNaoEncontradaError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof FichaNaoAguardandoPastorError) {
        throw new HttpsError('failed-precondition', erro.message);
      }
      if (erro instanceof SemVinculoPastoralError) {
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
        'Não foi possível registrar a decisão pastoral. Tente novamente mais tarde.',
      );
    }
  },
);

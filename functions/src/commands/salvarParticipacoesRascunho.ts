import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  FichaNaoEncontradaError,
  ParticipacaoInvalidaError,
  validarSalvarParticipacoes,
} from '../domain/participacao.js';
import { salvarParticipacoesRascunhoRepo } from '../repositories/participacao.js';

/**
 * Salva e sincroniza as equipes selecionadas no rascunho de participação do voluntário autenticado.
 */
export const salvarParticipacoesRascunho = onCall(
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
        'Não é permitido alterar as participações de outro voluntário.',
      );
    }

    let entrada;
    try {
      entrada = validarSalvarParticipacoes(request.data);
    } catch (erro) {
      if (erro instanceof ParticipacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de participação inválidos.');
    }

    const db = getFirestore();

    try {
      const resultado = await salvarParticipacoesRascunhoRepo(
        db,
        { commandId: entrada.commandId, uid: request.auth.uid },
        entrada,
      );

      return {
        sucesso: true,
        repetido: resultado.repetido,
        participacoes: resultado.participacoes,
      };
    } catch (erro) {
      if (erro instanceof EquipeInvalidaError) {
        throw new HttpsError('invalid-argument', 'Equipe inválida ou inativa');
      }
      if (erro instanceof FichaNaoEncontradaError) {
        throw new HttpsError('failed-precondition', 'Ficha permanente não encontrada');
      }
      if (erro instanceof ComandoDivergenteError) {
        throw new HttpsError(
          'already-exists',
          'Operação já registrada com dados divergentes.',
        );
      }
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível salvar as participações. Tente novamente mais tarde.',
      );
    }
  },
);

import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DataInvalidaError,
  EntidadeInexistenteError,
  OperacaoInvalidaError,
  PessoaInexistenteError,
  SemAutoridadeError,
  SobreposicaoError,
  VigenteExistenteError,
  VinculoInexistenteError,
  validarVinculo,
} from '../domain/vinculos.js';
import {
  ORIGEM_VINCULOS,
  gerenciarVinculo as gerenciarVinculoRepo,
} from '../repositories/vinculos.js';

const erro = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted',
) => new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Única fronteira de atribuição, substituição e encerramento de vínculos de
 * responsabilidade. Exige App Check, Auth e autoridade administrativa vigente,
 * revalidada na transação sobre o documento canônico da igreja/equipe.
 */
export const gerenciarVinculo = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');
    let entrada;
    try {
      entrada = validarVinculo(request.data);
    } catch {
      throw erro('invalid-argument');
    }
    const db = getFirestore();
    // Valida a autoridade do ator antes de qualquer leitura do alvo: um chamador
    // sem papel não pode distinguir entidade/pessoa existente de inexistente.
    const atorPrevio = await db
      .collection('autoridadesAdministrativas')
      .doc(request.auth.uid)
      .get();
    if (!podeAdministrar(atorPrevio.data())) throw erro('permission-denied');
    try {
      const resultado = await gerenciarVinculoRepo(
        db,
        {
          commandId: entrada.commandId,
          correlacaoId: entrada.correlationId ?? entrada.commandId,
          atorUid: request.auth.uid,
          origem: ORIGEM_VINCULOS,
          agoraMs: Date.now(),
        },
        entrada,
      );
      return {
        concluido: true,
        repetido: resultado.repetido,
        tipoEntidade: resultado.tipoEntidade,
        entidadeId: resultado.entidadeId,
        vinculoId: resultado.vinculoId,
        pessoaId: resultado.pessoaId,
        versaoVinculo: resultado.versaoVinculo,
      };
    } catch (falha) {
      if (falha instanceof HttpsError) throw falha;
      if (falha instanceof SemAutoridadeError) throw erro('permission-denied');
      if (
        falha instanceof ComandoDivergenteError ||
        falha instanceof ConflitoVersaoError
      ) {
        throw erro('aborted');
      }
      if (
        falha instanceof EntidadeInexistenteError ||
        falha instanceof PessoaInexistenteError
      ) {
        throw erro('invalid-argument');
      }
      if (
        falha instanceof DataInvalidaError ||
        falha instanceof SobreposicaoError ||
        falha instanceof VigenteExistenteError ||
        falha instanceof VinculoInexistenteError ||
        falha instanceof OperacaoInvalidaError
      ) {
        throw erro('failed-precondition');
      }
      throw falha;
    }
  },
);

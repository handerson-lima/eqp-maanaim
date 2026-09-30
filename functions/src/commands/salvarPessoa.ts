import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  AlvoInexistenteError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  SemAutoridadeError,
  validarPessoa,
} from '../domain/pessoas.js';
import {
  ORIGEM_ADMINISTRATIVA,
  salvarPessoa as salvarPessoaRepo,
} from '../repositories/pessoas.js';

const erro = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted',
) => new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Única fronteira de cadastro/atualização de pessoa: exige App Check, Auth e
 * autoridade administrativa vigente (validada na transação). Provisiona a
 * identidade sem senha quando o e-mail ainda não possui conta.
 */
export const salvarPessoa = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');
    let entrada;
    try {
      entrada = validarPessoa(request.data);
    } catch {
      throw erro('invalid-argument');
    }
    try {
      const resultado = await salvarPessoaRepo(
        getFirestore(),
        getAuth(),
        {
          commandId: entrada.commandId,
          correlacaoId: entrada.correlationId ?? entrada.commandId,
          atorUid: request.auth.uid,
          origem: ORIGEM_ADMINISTRATIVA,
        },
        entrada,
      );
      return {
        uid: resultado.uid,
        coordenador: resultado.coordenador,
        repetido: resultado.repetido,
      };
    } catch (falha) {
      if (falha instanceof SemAutoridadeError) throw erro('permission-denied');
      if (falha instanceof AlvoInexistenteError) throw erro('invalid-argument');
      if (falha instanceof ComandoDivergenteError || falha instanceof ConflitoVersaoError) {
        throw erro('aborted');
      }
      throw falha;
    }
  },
);

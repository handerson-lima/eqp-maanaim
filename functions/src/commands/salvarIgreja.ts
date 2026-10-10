import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  CodigoIgrejaDuplicadoError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  EntidadeInexistenteError,
  EntradaInvalidaError,
  SemAutoridadeError,
  validarSalvarIgreja,
} from '../domain/catalogo.js';
import { salvarIgrejaRepo } from '../repositories/catalogoAdmin.js';

const ORIGEM_CATALOGO = 'painel-administrativo';

const erro = (
  code: 'permission-denied' | 'invalid-argument' | 'aborted' | 'not-found' | 'already-exists',
  msg = 'Operação administrativa indisponível.',
) => new HttpsError(code, msg);

/**
 * Callable administrativo v2 para cadastro e edição autenticada de igreja.
 * Exige App Check, autenticação e autoridade canônica maanaimAdmin.
 * Valida unicidade de código String e controle de concorrência com expectedVersion.
 */
export const salvarIgreja = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');

    let entrada;
    try {
      entrada = validarSalvarIgreja(request.data);
    } catch (e) {
      if (e instanceof EntradaInvalidaError) {
        throw erro('invalid-argument', e.message);
      }
      throw erro('invalid-argument');
    }

    const db = getFirestore();
    const atorSnap = await db
      .collection('autoridadesAdministrativas')
      .doc(request.auth.uid)
      .get();
    if (!podeAdministrar(atorSnap.data())) throw erro('permission-denied');

    try {
      const resultado = await salvarIgrejaRepo(
        db,
        {
          commandId: entrada.commandId,
          correlacaoId: entrada.correlationId ?? entrada.commandId,
          atorUid: request.auth.uid,
          origem: ORIGEM_CATALOGO,
        },
        entrada,
      );

      return {
        concluido: true,
        repetido: resultado.repetido,
        id: resultado.id,
        versao: resultado.versao,
      };
    } catch (falha) {
      if (falha instanceof HttpsError) throw falha;
      if (falha instanceof SemAutoridadeError) throw erro('permission-denied');
      if (falha instanceof CodigoIgrejaDuplicadoError) {
        throw erro('already-exists', `Já existe uma igreja cadastrada com o código ${falha.codigo}.`);
      }
      if (falha instanceof ConflitoVersaoError) {
        throw erro('aborted', 'Conflito de concorrência: os dados da igreja foram alterados por outro usuário.');
      }
      if (falha instanceof ComandoDivergenteError) {
        throw erro('aborted', 'Operação já registrada com dados divergentes.');
      }
      if (falha instanceof EntidadeInexistenteError) {
        throw erro('not-found', 'Igreja não encontrada no catálogo.');
      }
      throw falha;
    }
  },
);

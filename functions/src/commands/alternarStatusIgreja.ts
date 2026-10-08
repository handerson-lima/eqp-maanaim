import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  EntidadeInexistenteError,
  EntradaInvalidaError,
  SemAutoridadeError,
  validarAlternarStatusIgreja,
} from '../domain/catalogo.js';
import { alternarStatusIgrejaRepo } from '../repositories/statusCatalogo.js';

const ORIGEM_CATALOGO = 'painel-administrativo';

const erro = (
  code: 'permission-denied' | 'invalid-argument' | 'aborted' | 'not-found',
  msg = 'Operação administrativa indisponível.',
) => new HttpsError(code, msg);

/**
 * Callable administrativo v2 para inativação ou reativação lógica de igreja.
 * Exige App Check, autenticação e autoridade canônica maanaimAdmin.
 */
export const alternarStatusIgreja = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');

    let entrada;
    try {
      entrada = validarAlternarStatusIgreja(request.data);
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
      const resultado = await alternarStatusIgrejaRepo(
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
        igrejaId: resultado.id,
        ativo: resultado.ativo,
      };
    } catch (falha) {
      if (falha instanceof HttpsError) throw falha;
      if (falha instanceof SemAutoridadeError) throw erro('permission-denied');
      if (falha instanceof ComandoDivergenteError) throw erro('aborted', 'Operação já registrada com dados divergentes.');
      if (falha instanceof EntidadeInexistenteError) throw erro('not-found', 'Igreja não encontrada no catálogo.');
      throw falha;
    }
  },
);

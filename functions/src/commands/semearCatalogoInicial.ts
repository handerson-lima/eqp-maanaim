import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  SemAutoridadeError,
  validarCommandId,
} from '../domain/catalogo.js';
import { ORIGEM_SEED_INICIAL } from '../domain/importacaoPastores.js';
import { semearCatalogo } from '../repositories/catalogo.js';

type Entrada = {
  commandId?: unknown;
  correlationId?: unknown;
};

const indisponivel = (code: 'permission-denied' | 'invalid-argument' | 'aborted') =>
  new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Única fronteira de mutação do catálogo: exige App Check, Auth e autoridade
 * administrativa canônica vigente, validada na transação.
 */
export const semearCatalogoInicial = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw indisponivel('permission-denied');
    const input = (request.data ?? {}) as Entrada;
    if (typeof input.commandId !== 'string' || !validarCommandId(input.commandId)) {
      throw indisponivel('invalid-argument');
    }
    if (
      input.correlationId !== undefined &&
      (typeof input.correlationId !== 'string' ||
        !validarCommandId(input.correlationId))
    ) {
      throw indisponivel('invalid-argument');
    }
    const correlationId =
      typeof input.correlationId === 'string' ? input.correlationId : input.commandId;
    try {
      return await semearCatalogo(getFirestore(), {
        commandId: input.commandId,
        correlacaoId: correlationId,
        atorUid: request.auth.uid,
        origem: ORIGEM_SEED_INICIAL,
        agora: new Date(),
      });
    } catch (erro) {
      if (erro instanceof SemAutoridadeError) {
        throw indisponivel('permission-denied');
      }
      if (erro instanceof ComandoDivergenteError) {
        throw indisponivel('aborted');
      }
      throw erro;
    }
  },
);

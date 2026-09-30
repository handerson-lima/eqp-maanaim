import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import { lerPessoas } from '../repositories/pessoas.js';

type Entrada = { termo?: unknown };

const indisponivel = (code: 'permission-denied' | 'invalid-argument') =>
  new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Consulta read-only de pessoas e papéis efetivos, exclusiva de administrador
 * autorizado. Nunca devolve CPF nem o conteúdo do registro restrito.
 */
export const consultarPessoas = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw indisponivel('permission-denied');
    const input = (request.data ?? {}) as Entrada;
    if (
      input.termo !== undefined &&
      (typeof input.termo !== 'string' || input.termo.length > 120)
    ) {
      throw indisponivel('invalid-argument');
    }
    const db = getFirestore();
    const ator = await db
      .collection('autoridadesAdministrativas')
      .doc(request.auth.uid)
      .get();
    if (!podeAdministrar(ator.data())) throw indisponivel('permission-denied');
    return lerPessoas(
      db,
      typeof input.termo === 'string' ? input.termo : '',
      request.auth.uid,
    );
  },
);

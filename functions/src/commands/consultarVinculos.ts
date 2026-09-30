import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import { lerVinculos } from '../repositories/vinculos.js';

type Entrada = { termo?: unknown };

const indisponivel = (code: 'permission-denied' | 'invalid-argument') =>
  new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Consulta read-only de vínculos e responsáveis vigentes, exclusiva de
 * administrador autorizado. Nunca devolve e-mail, CPF nem conteúdo restrito.
 */
export const consultarVinculos = onCall(
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
    return lerVinculos(db, typeof input.termo === 'string' ? input.termo : '');
  },
);

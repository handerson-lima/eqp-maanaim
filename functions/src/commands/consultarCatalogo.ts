import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import { lerCatalogo } from '../repositories/catalogo.js';
import { lerCatalogoAdmin } from '../repositories/catalogoAdmin.js';

type Entrada = { termo?: unknown; modo?: unknown };

const indisponivel = (code: 'permission-denied' | 'invalid-argument') =>
  new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Consulta autorizada do catálogo, exclusiva de administrador autorizado.
 * Retorna dados completos com igrejas, equipes, dados mínimos de responsáveis vigentes
 * e versões para controle de concorrência.
 */
export const consultarCatalogo = onCall(
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

    const termo = typeof input.termo === 'string' ? input.termo : '';
    if (input.modo === 'simples') {
      return lerCatalogo(db, termo);
    }
    return lerCatalogoAdmin(db, termo);
  },
);

import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  SemAutoridadeError,
  TermoInvalidoError,
  validarPublicarTermo,
} from '../domain/termos.js';
import {
  ORIGEM_TERMOS,
  publicarTermo as publicarTermoRepo,
} from '../repositories/termos.js';

const erro = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted',
) => new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Publicação de versão imutável do termo com App Check, Auth e RBAC.
 */
export const publicarTermo = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');

    let entrada;
    try {
      entrada = validarPublicarTermo(request.data);
    } catch {
      throw erro('invalid-argument');
    }

    const db = getFirestore();
    const atorPrevio = await db
      .collection('autoridadesAdministrativas')
      .doc(request.auth.uid)
      .get();

    if (!podeAdministrar(atorPrevio.data())) {
      throw erro('permission-denied');
    }

    try {
      const resultado = await publicarTermoRepo(
        db,
        {
          commandId: entrada.commandId,
          correlacaoId: entrada.correlationId ?? entrada.commandId,
          atorUid: request.auth.uid,
          origem: ORIGEM_TERMOS,
        },
        entrada,
      );

      return {
        concluido: true,
        repetido: resultado.repetido,
        termoId: resultado.termoId,
        versaoId: resultado.versaoId,
        numeroVersao: resultado.numeroVersao,
        hashSha256: resultado.hashSha256,
        totalVoluntariosImpactados: resultado.totalVoluntariosImpactados,
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
      if (falha instanceof TermoInvalidoError) {
        throw erro('invalid-argument');
      }
      throw falha;
    }
  },
);

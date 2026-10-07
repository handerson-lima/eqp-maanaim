import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  AcessoConsultaNegadoError,
  type FiltrosRelatorioOperacional,
} from '../domain/consultaAuditoria.js';
import { consultarRelatorioOperacionalRepo } from '../repositories/consultaAuditoria.js';

/**
 * Callable autenticada para consulta de relatórios operacionais consolidados (AD-8, AD-9, AD-12).
 *
 * Restrições de autorização:
 * - Pastor Local: estritamente restrito à sua igreja vigente.
 * - Responsável de Equipe: estritamente restrito às suas equipes vigentes.
 * - Coordenador Geral e Administrador: visão consolidada global (com auditoria probatória).
 * - CPF de voluntários sempre mascarado (`123.***.***-00` ou `***.***.***-**`).
 */
export const consultarRelatorioOperacional = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const payload = (request.data ?? {}) as Record<string, unknown>;
    const filtros: FiltrosRelatorioOperacional = {};

    if (payload.igrejaId !== undefined) {
      if (typeof payload.igrejaId !== 'string') {
        throw new HttpsError('invalid-argument', 'igrejaId deve ser string.');
      }
      filtros.igrejaId = payload.igrejaId.trim();
    }

    if (payload.equipeId !== undefined) {
      if (typeof payload.equipeId !== 'string') {
        throw new HttpsError('invalid-argument', 'equipeId deve ser string.');
      }
      filtros.equipeId = payload.equipeId.trim();
    }

    if (payload.estado !== undefined) {
      if (typeof payload.estado !== 'string') {
        throw new HttpsError('invalid-argument', 'estado deve ser string.');
      }
      filtros.estado = payload.estado.trim().toUpperCase();
    }

    if (payload.ano !== undefined) {
      const parsedAno = Number(payload.ano);
      if (isNaN(parsedAno) || !Number.isInteger(parsedAno) || parsedAno < 2000 || parsedAno > 2100) {
        throw new HttpsError('invalid-argument', 'ano deve ser número inteiro válido.');
      }
      filtros.ano = parsedAno;
    }

    const db = getFirestore();
    const correlationId = typeof payload.correlationId === 'string'
      ? payload.correlationId
      : undefined;

    try {
      const resultado = await consultarRelatorioOperacionalRepo(
        db,
        request.auth.uid,
        filtros,
        correlationId,
      );

      return resultado;
    } catch (err) {
      if (err instanceof AcessoConsultaNegadoError) {
        throw new HttpsError('permission-denied', err.message);
      }
      if (err instanceof HttpsError) {
        throw err;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível gerar o relatório operacional. Tente novamente mais tarde.',
      );
    }
  },
);

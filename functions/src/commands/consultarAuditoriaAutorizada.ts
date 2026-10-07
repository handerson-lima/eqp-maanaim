import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  AcessoConsultaNegadoError,
  ConsultaAuditoriaInvalidaError,
  validarFiltrosConsultaAuditoria,
} from '../domain/consultaAuditoria.js';
import { consultarAuditoriaAutorizadaRepo } from '../repositories/consultaAuditoria.js';

/**
 * Callable autenticada para consulta de auditoria imutável autorizada (AD-8, AD-9, AD-12).
 *
 * Restrições de autorização:
 * - Pastor Local: estritamente restrito à sua igreja vigente.
 * - Responsável de Equipe: estritamente restrito às suas equipes vigentes.
 * - Coordenador Geral e Administrador: visão global (registrando evento probatório de auditoria).
 * - Outros papéis sem permissão: acesso negado.
 */
export const consultarAuditoriaAutorizada = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    let validacao;
    try {
      validacao = validarFiltrosConsultaAuditoria(request.data);
    } catch (err) {
      if (err instanceof ConsultaAuditoriaInvalidaError) {
        throw new HttpsError('invalid-argument', err.message);
      }
      throw new HttpsError('invalid-argument', 'Parâmetros de consulta inválidos.');
    }

    const { filtros, limite, cursorDecodificado } = validacao;
    const db = getFirestore();
    const correlationId = typeof request.data?.correlationId === 'string'
      ? request.data.correlationId
      : undefined;

    try {
      const resultado = await consultarAuditoriaAutorizadaRepo(
        db,
        request.auth.uid,
        filtros,
        limite,
        cursorDecodificado,
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
        'Não foi possível consultar os registros de auditoria. Tente novamente mais tarde.',
      );
    }
  },
);

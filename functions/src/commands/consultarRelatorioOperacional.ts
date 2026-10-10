import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  AcessoConsultaNegadoError,
  ConsultaAuditoriaInvalidaError,
  validarFiltrosRelatorioOperacional,
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

    let validacao;
    try {
      validacao = validarFiltrosRelatorioOperacional(request.data);
    } catch (err) {
      if (err instanceof ConsultaAuditoriaInvalidaError) {
        throw new HttpsError('invalid-argument', err.message);
      }
      throw new HttpsError('invalid-argument', 'Parâmetros de relatório inválidos.');
    }

    const { filtros, limite, cursorDecodificado } = validacao;
    const db = getFirestore();
    const correlationId = typeof request.data?.correlationId === 'string'
      ? request.data.correlationId
      : undefined;

    try {
      const resultado = await consultarRelatorioOperacionalRepo(
        db,
        request.auth.uid,
        filtros,
        correlationId,
        limite,
        cursorDecodificado,
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

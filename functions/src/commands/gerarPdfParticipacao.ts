import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  gerarPdfParticipacaoRepo,
  type ContextoPdf,
  type ResultadoGeracaoPdf,
} from '../repositories/pdfTermo.js';
import { AcessoNaoAutorizadoError } from '../domain/consultaHistorico.js';
import {
  DadosPdfIncompletosError,
  ParticipacaoNaoAprovadaParaPdfError,
} from '../domain/pdfTermo.js';

export interface EntradaGerarPdfPayload {
  commandId?: string;
  correlationId?: string;
  fichaId: string;
  participacaoId: string;
}

/**
 * Endpoint autenticado para geração do Termo em PDF privado individual por equipe (AD-6, AD-12, AD-13).
 * Revalida rigorosamente identidade, vínculos vigentes e escopo no servidor.
 * Rejeita qualquer tentativa de injeção client-side de dados jurídicos ou assinaturas.
 */
export const gerarPdfParticipacao = onCall(
  { enforceAppCheck: true },
  async (request): Promise<ResultadoGeracaoPdf> => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const payload = (request.data ?? {}) as Record<string, unknown>;

    // Proibição expressa de injeção client-side de dados de domínio (AD-6, AD-13)
    const camposProibidos = [
      'nomeCompleto',
      'cpf',
      'profissao',
      'textoAssinatura',
      'assinatura',
      'estado',
      'status',
      'nomeCoordenador',
      'cpfCoordenador',
      'nomePastor',
      'termo',
    ];
    for (const campo of camposProibidos) {
      if (campo in payload) {
        throw new HttpsError(
          'invalid-argument',
          `Injeção não permitida: campo ${campo} deve ser obtido exclusivamente do servidor.`,
        );
      }
    }

    const fichaId = String(payload.fichaId ?? '').trim();
    const participacaoId = String(payload.participacaoId ?? '').trim();
    const commandId = payload.commandId ? String(payload.commandId).trim() : undefined;
    const correlationId = payload.correlationId ? String(payload.correlationId).trim() : undefined;

    if (!fichaId || !participacaoId) {
      throw new HttpsError(
        'invalid-argument',
        'Parâmetros obrigatórios fichaId e participacaoId não informados.',
      );
    }

    const db = getFirestore();
    const contexto: ContextoPdf = {
      commandId,
      correlationId,
      atorUid: request.auth.uid,
    };

    try {
      return await gerarPdfParticipacaoRepo(db, contexto, fichaId, participacaoId);
    } catch (error) {
      if (error instanceof AcessoNaoAutorizadoError) {
        throw new HttpsError(
          'permission-denied',
          'Acesso não autorizado para o termo solicitado ou vínculo não vigente.',
        );
      }
      if (error instanceof ParticipacaoNaoAprovadaParaPdfError) {
        throw new HttpsError(
          'failed-precondition',
          error.message,
        );
      }
      if (error instanceof DadosPdfIncompletosError) {
        throw new HttpsError(
          'failed-precondition',
          error.message,
        );
      }
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', 'Falha ao processar e gerar o PDF do termo.');
    }
  },
);

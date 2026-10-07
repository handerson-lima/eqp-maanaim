/**
 * Domínio de Notificações Seguras Pós-Compromisso (AD-10 e AD-12).
 *
 * Invariantes rigorosos:
 * 1. Estritamente SEM PII (sem CPF, nome civil, telefone, e-mail).
 * 2. Estritamente SEM justificativas internas, motivos de indeferimento ou UIDs de avaliadores desfavoráveis.
 * 3. Estritamente SEM decisões acionáveis no payload da notificação (apenas estado, próxima ação e link autorizável).
 * 4. Para qualquer decisão desfavorável, a mensagem para o voluntário é SEMPRE:
 *    "Procure o Pastor da igreja local para mais informações" (sem a palavra "rejeitado").
 */

export const MENSAGEM_NEUTRA_CANONICA =
  'Procure o Pastor da igreja local para mais informações';

export type TipoNotificacao =
  | 'FICHA_ENVIADA'
  | 'DECISAO_PASTOR_LOCAL'
  | 'DECISAO_RESPONSAVEL_EQUIPE'
  | 'DECISAO_COORDENADOR';

export interface NotificacaoSegura {
  id: string;
  destinatarioUid: string;
  tipo: TipoNotificacao;
  estado: string;
  proximaAcao: string;
  deepLink: string;
  criadoEm: string;
}

export interface EventoAuditoriaOutbox {
  commandId: string;
  correlationId?: string;
  actorUid: string;
  action: string;
  fichaId?: string;
  decisao?: string;
  novoEstadoFicha?: string;
  participacoesAtivadas?: string[];
  participacoesRejeitadas?: string[];
  equipeId?: string;
  criadoEm?: unknown;
}

/**
 * Constrói uma notificação segura para o voluntário a partir de um evento de auditoria persistido.
 * Sanitiza rigorosamente contra qualquer vazamento de PII ou justificativas.
 */
export function construirNotificacaoVoluntario(
  id: string,
  destinatarioUid: string,
  tipo: TipoNotificacao,
  estado: string,
  deepLink = '/minha-ficha',
  dataCriacaoIso = new Date().toISOString(),
): NotificacaoSegura {
  const ehNegativa = estado === 'REJEITADA' || estado === 'DESFAVORAVEL';
  const proximaAcao = ehNegativa
    ? MENSAGEM_NEUTRA_CANONICA
    : estado === 'ATIVA'
      ? 'Voluntariado ativo no Maanaim'
      : 'Acompanhe o andamento da sua solicitação';

  return {
    id,
    destinatarioUid,
    tipo,
    // Para o voluntário, se foi negativa, não expor "REJEITADA" no campo de estado exibível
    estado: ehNegativa ? 'DECISAO_CONCLUIDA' : estado,
    proximaAcao,
    deepLink,
    criadoEm: dataCriacaoIso,
  };
}

/**
 * Valida se um payload de notificação contém dados proibidos (PII ou justificativas internas).
 * Retorna true se estiver totalmente seguro e sanitizado.
 */
export function validarAusenciaPIIEJustificativas(payload: Record<string, unknown>): {
  seguro: boolean;
  motivoViolacao?: string;
} {
  const textoSerializado = JSON.stringify(payload).toLowerCase();

  // 1. Proibição de CPF
  if (/\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/.test(textoSerializado)) {
    return { seguro: false, motivoViolacao: 'Contém padrão de CPF' };
  }

  // 2. Proibição de termos de justificativa interna
  const termosProibidos = [
    'justificativainterna',
    'justificativa',
    'motivo',
    'rejeitado',
    'rejeitada',
    'indeferido',
  ];

  for (const termo of termosProibidos) {
    if (textoSerializado.includes(termo)) {
      return { seguro: false, motivoViolacao: `Contém termo restrito: "${termo}"` };
    }
  }

  // 3. Proibição de campos típicos de PII
  const camposPiiProibidos = ['cpf', 'rg', 'telefone', 'endereco', 'nomecompleto'];
  for (const campo of camposPiiProibidos) {
    if (campo in payload) {
      return { seguro: false, motivoViolacao: `Contém campo restrito de PII: "${campo}"` };
    }
  }

  return { seguro: true };
}

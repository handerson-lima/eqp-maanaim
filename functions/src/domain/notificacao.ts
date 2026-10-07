/**
 * Domínio de Notificações Seguras Pós-Compromisso (AD-10 e AD-12).
 *
 * Invariantes rigorosos:
 * 1. Estritamente SEM PII (sem CPF, nome civil, telefone, e-mail).
 * 2. Estritamente SEM justificativas internas, motivos de indeferimento ou UIDs de avaliadores desfavoráveis.
 * 3. Estritamente SEM decisões acionáveis no payload da notificação (apenas estado, próxima ação e link autorizável).
 * 4. Para qualquer decisão desfavorável, a mensagem para o voluntário é SEMPRE a canônica
 *    (sem a palavra "rejeitado").
 */
import { MENSAGEM_NEUTRA_CANONICA } from './mensagens.js';

export { MENSAGEM_NEUTRA_CANONICA };

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

/**
 * Evento append-only persistido em `auditOutbox`. Os repositórios de decisão
 * gravam variações desse formato; o mapeador abaixo normaliza os campos.
 */
export interface EventoAuditoriaOutbox {
  commandId?: string;
  correlationId?: string;
  atorUid?: string;
  actorUid?: string;
  acao?: string;
  action?: string;
  fichaId?: string;
  participacaoId?: string;
  equipeId?: string;
  decisao?: string;
  estado?: string;
  novoEstado?: string;
  novoEstadoFicha?: string;
  antes?: { estado?: string };
  depois?: { estado?: string };
  metadados?: { decisao?: string; igrejaId?: string };
  entidades?: Array<{ tipo?: string; id?: string }>;
  criadoEm?: unknown;
}

/**
 * Mapeamento imutável entre a ação auditada e o tipo de notificação do voluntário.
 * Eventos fora deste mapa não geram notificação.
 */
const MAPA_ACOES_NOTIFICAVEIS: Record<string, TipoNotificacao> = {
  FICHA_ENVIADA_APROVACAO: 'FICHA_ENVIADA',
  DECISAO_PASTORAL_REGISTRADA: 'DECISAO_PASTOR_LOCAL',
  DECISAO_RESPONSAVEL_EQUIPE: 'DECISAO_RESPONSAVEL_EQUIPE',
  DECISAO_COORDENADOR: 'DECISAO_COORDENADOR',
};

export interface NotificacaoMapeada {
  destinatarioUid: string;
  tipo: TipoNotificacao;
  estado: string;
}

/**
 * Normaliza um evento de `auditOutbox` em parâmetros de notificação segura.
 * Retorna `null` quando o evento não corresponde a um marco decisório
 * notificável ou quando faltam dados essenciais (nunca inventa destinatário).
 */
export function mapearEventoAuditoriaParaNotificacao(
  evento: EventoAuditoriaOutbox,
): NotificacaoMapeada | null {
  const acao = String(evento.action ?? evento.acao ?? '').trim();
  const tipo = MAPA_ACOES_NOTIFICAVEIS[acao];
  if (!tipo) {
    return null;
  }

  const entidadeFicha = (evento.entidades ?? []).find(
    (e) => String(e?.tipo ?? '').toUpperCase() === 'FICHA',
  );
  const destinatarioUid = String(evento.fichaId ?? entidadeFicha?.id ?? '').trim();
  if (!destinatarioUid) {
    return null;
  }

  const estado = String(
    evento.depois?.estado ??
      evento.novoEstadoFicha ??
      evento.novoEstado ??
      evento.estado ??
      '',
  ).trim();
  if (!estado) {
    return null;
  }

  return { destinatarioUid, tipo, estado };
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

  // 3. Proibição de campos típicos de PII (comparação normalizada, case-insensitive)
  const camposPiiProibidos = ['cpf', 'rg', 'telefone', 'endereco', 'nomecompleto'];
  const chavesNormalizadas = Object.keys(payload).map((chave) =>
    chave.toLowerCase().replace(/[_\s-]/g, ''),
  );
  for (const campo of camposPiiProibidos) {
    if (chavesNormalizadas.includes(campo)) {
      return { seguro: false, motivoViolacao: `Contém campo restrito de PII: "${campo}"` };
    }
  }

  return { seguro: true };
}

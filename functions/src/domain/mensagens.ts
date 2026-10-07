/**
 * Mensagens canônicas compartilhadas entre projeções, notificações e auditoria.
 *
 * Fonte única de verdade da mensagem neutra obrigatória para decisões
 * desfavoráveis/cancelamentos (AD-12, FR28). Nunca expor a palavra
 * "rejeitado", justificativas internas ou identidade de avaliadores.
 */
export const MENSAGEM_CANONICA_DECISAO_NEGATIVA =
  'Procure o Pastor da igreja local para mais informações';

export const MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA =
  MENSAGEM_CANONICA_DECISAO_NEGATIVA;

export const MENSAGEM_NEUTRA_CANONICA = MENSAGEM_CANONICA_DECISAO_NEGATIVA;

import { MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA } from './participacao.js';

export { MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA };

export class AcessoNaoAutorizadoError extends Error {
  constructor(message = 'Acesso não autorizado para a ficha ou histórico solicitado.') {
    super(message);
    this.name = 'AcessoNaoAutorizadoError';
  }
}

export class FichaNaoEncontradaConsultaError extends Error {
  constructor(message = 'Ficha não encontrada.') {
    super(message);
    this.name = 'FichaNaoEncontradaConsultaError';
  }
}

export const ESTADOS_NEGATIVOS = ['REJEITADA', 'CANCELADA', 'EXPIRADA'] as const;

export function ehEstadoNegativo(estado: string): boolean {
  return (ESTADOS_NEGATIVOS as readonly string[]).includes(
    String(estado ?? '').trim().toUpperCase(),
  );
}

/**
 * Estado público exibível ao voluntário: nunca revela o termo de indeferimento.
 * Decisões negativas são projetadas como orientação neutra.
 */
export function estadoPublicoVoluntario(estado: string): string {
  return ehEstadoNegativo(estado) ? 'ORIENTACAO' : estado;
}

export type PapelConsulta =
  | 'VOLUNTARIO'
  | 'PASTOR_LOCAL'
  | 'RESPONSAVEL_EQUIPE'
  | 'COORDENADOR_GERAL'
  | 'ADMINISTRADOR';

export interface EscopoAtorConsulta {
  atorUid: string;
  papel: PapelConsulta;
  igrejaId?: string | null;
  equipeIdsAutorizadas?: string[];
  ehProprioVoluntario: boolean;
}

export interface FichaConsultaAutorizada {
  id: string;
  ownerUid: string;
  nomeCompleto: string;
  profissao: string;
  cpfMascarado?: string;
  cpfCompleto?: string;
  igrejaId: string;
  nomeIgreja?: string;
  estado: string;
  versao: number;
  proximaAcao: string | null;
  mensagemVoluntario: string | null;
  atualizadoEm: string | null;
  criadoEm: string | null;
}

export interface ParticipacaoConsultaAutorizada {
  id: string;
  fichaId: string;
  equipeId: string;
  nomeEquipe: string;
  estado: string;
  ciclo: string;
  proximaAcao: string;
  vigenciaInicio: string | null;
  vigenciaFim: string | null;
  situacaoVigencia?: string | null;
  diasParaVencimento?: number | null;
  alertaVigencia?: string | null;
  emAlertaRenovacao?: boolean;
  cicloAtualId: string | null;
  atualizadoEm: string | null;
}

export interface EventoLinhaDoTempo {
  id: string;
  tipo:
    | 'CRIACAO_FICHA'
    | 'ENVIO_APROVACAO'
    | 'DECISAO_PASTORAL'
    | 'DECISAO_RESPONSAVEL_EQUIPE'
    | 'HOMOLOGACAO_COORDENACAO'
    | 'CANCELAMENTO'
    | 'EXPIRACAO_CICLO_ANUAL'
    | 'REATIVACAO'
    | 'OUTRO';
  etapa: 'CADASTRO' | 'PASTOR_LOCAL' | 'RESPONSAVEL_EQUIPE' | 'COORDENADOR_GERAL' | 'SISTEMA';
  titulo: string;
  descricao: string;
  estadoVisual: 'CONCLUIDO' | 'EM_ANDAMENTO' | 'ORIENTACAO_PASTORAL';
  timestamp: string; // ISO UTC
  ator?: {
    nome: string;
    papel: string;
    vinculoId?: string | null;
  } | null;
  equipeId?: string | null;
  nomeEquipe?: string | null;
  justificativaInterna?: string | null;
}

export interface ResultadoConsultaFichaAutorizada {
  existe: boolean;
  ficha?: FichaConsultaAutorizada;
  participacoes: ParticipacaoConsultaAutorizada[];
  escopo: {
    papel: PapelConsulta;
    equipesFiltradas: boolean;
  };
}

export interface ResultadoConsultaLinhaDoTempo {
  fichaId: string;
  eventos: EventoLinhaDoTempo[];
  totalEventos: number;
}

/**
 * Mascara o CPF para exibições onde o papel não exige CPF desmascarado (AD-12).
 * Exemplo: 12345678901 -> ***.456.789-**
 */
export function mascararCpf(cpf: string): string {
  const limpo = cpf.replace(/\D/g, '');
  if (limpo.length !== 11) return '***.***.***-**';
  return `***.${limpo.substring(3, 6)}.${limpo.substring(6, 9)}-**`;
}

/**
 * Sanitiza um evento da linha do tempo para a perspectiva do voluntário (FR28, AD-12).
 * - Oculta justificativa interna.
 * - Oculta a identidade de avaliadores desfavoráveis.
 * - Substitui mensagem de decisão desfavorável pela orientação canônica:
 *   "Procure o Pastor da igreja local para mais informações"
 * - NUNCA utiliza a palavra "rejeitado".
 */
export function sanitizarEventoParaVoluntario(evento: EventoLinhaDoTempo): EventoLinhaDoTempo {
  const ehDesfavoravel =
    evento.estadoVisual === 'ORIENTACAO_PASTORAL' ||
    evento.descricao.toLowerCase().includes('desfavor') ||
    evento.descricao.toLowerCase().includes('rejeit');

  if (ehDesfavoravel) {
    return {
      ...evento,
      titulo: evento.etapa === 'PASTOR_LOCAL'
        ? 'Avaliação pastoral concluída'
        : evento.etapa === 'RESPONSAVEL_EQUIPE'
          ? `Avaliação da equipe ${evento.nomeEquipe ?? ''}`.trim()
          : 'Avaliação concluída',
      descricao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
      estadoVisual: 'ORIENTACAO_PASTORAL',
      ator: null, // Oculta avaliador desfavorável
      justificativaInterna: null, // Oculta justificativa interna
    };
  }

  return {
    ...evento,
    justificativaInterna: null, // Voluntário nunca vê justificativa interna técnica
  };
}

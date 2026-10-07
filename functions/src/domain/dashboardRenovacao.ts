import { SituacaoVigencia } from './vigencia.js';

export type PapelDashboard =
  | 'VOLUNTARIO'
  | 'PASTOR_LOCAL'
  | 'RESPONSAVEL_EQUIPE'
  | 'COORDENADOR'
  | 'ADMINISTRADOR';

export class PermissaoNegadaDashboardError extends Error {
  constructor(mensagem = 'Acesso não autorizado ao dashboard solicitado.') {
    super(mensagem);
    this.name = 'PermissaoNegadaDashboardError';
  }
}

export class ParametroInvalidoDashboardError extends Error {
  constructor(mensagem = 'Parâmetro de consulta inválido.') {
    super(mensagem);
    this.name = 'ParametroInvalidoDashboardError';
  }
}

export interface EntradaConsultarDashboardRenovacao {
  papelDesejado?: PapelDashboard;
  igrejaId?: string;
  equipeId?: string;
  estadoRenovacao?: string;
  anoVigencia?: number;
  limite?: number;
  pagina?: number;
}

// -------------------------------------------------------------
// Modelos por Papel
// -------------------------------------------------------------

export interface MetricasRenovacaoVoluntario {
  totalParticipacoesAtivas: number;
  emJanelaRenovacao: number;
  pendentesManifestacao: number;
  emTramitacao: number;
  expiradas: number;
}

export interface ItemRenovacaoVoluntario {
  participacaoId: string;
  equipeId: string;
  equipeNome: string;
  estadoParticipacao: string;
  vigenciaInicio: string | null;
  vigenciaFim: string | null;
  anoVigencia: number | null;
  situacaoVigencia: SituacaoVigencia;
  diasRestantes: number | null;
  emJanelaRenovacao: boolean;
  podeManifestar: boolean;
  cicloId: string | null;
  anoCiclo: number | null;
  estadoCiclo: string | null;
}

export interface MetricasRenovacaoPastor {
  pendentesParecer: number;
  semManifestacao: number;
  proximasVencimento: number;
  expiradas: number;
  totalSobEscopo: number;
}

export type EstadoRenovacaoPastor =
  | 'PENDENTE_PASTOR'
  | 'SEM_MANIFESTACAO'
  | 'PROXIMO_VENCIMENTO'
  | 'EXPIRADA'
  | 'OUTRO';

export interface ItemRenovacaoPastor {
  participacaoId: string;
  fichaId: string;
  voluntarioNome: string;
  igrejaId: string;
  igrejaNome: string;
  equipeId: string;
  equipeNome: string;
  vigenciaFim: string | null;
  diasRestantes: number | null;
  situacaoVigencia: SituacaoVigencia;
  cicloId: string | null;
  estadoCiclo: string | null;
  estadoRenovacao: EstadoRenovacaoPastor;
}

export interface MetricasRenovacaoResponsavel {
  pendentesEquipe: number;
  emTramitacao: number;
  semManifestacao: number;
  expiradas: number;
  totalEquipe: number;
}

export type EstadoRenovacaoResponsavel =
  | 'PENDENTE_EQUIPE'
  | 'EM_TRAMITACAO'
  | 'SEM_MANIFESTACAO'
  | 'EXPIRADA'
  | 'OUTRO';

export interface ItemRenovacaoResponsavel {
  participacaoId: string;
  fichaId: string;
  voluntarioNome: string;
  igrejaId: string;
  igrejaNome: string;
  equipeId: string;
  equipeNome: string;
  vigenciaFim: string | null;
  diasRestantes: number | null;
  situacaoVigencia: SituacaoVigencia;
  cicloId: string | null;
  estadoCiclo: string | null;
  estadoRenovacao: EstadoRenovacaoResponsavel;
}

export interface MetricasRenovacaoCoordenador {
  totalAtivos: number;
  emJanelaRenovacao: number;
  pendentesPastorLocal: number;
  pendentesResponsaveis: number;
  aguardandoCoordenador: number;
  renovadosConcluidos: number;
  expirados: number;
}

export interface ItemRenovacaoCoordenador {
  participacaoId: string;
  fichaId: string;
  voluntarioNome: string;
  igrejaId: string;
  igrejaNome: string;
  equipeId: string;
  equipeNome: string;
  vigenciaFim: string | null;
  diasRestantes: number | null;
  situacaoVigencia: SituacaoVigencia;
  cicloId: string | null;
  estadoCiclo: string | null;
  anoVigencia: number | null;
  estadoRenovacao: string;
}

export interface EscopoOpcaoFiltro {
  id: string;
  nome: string;
  codigo?: string;
}

export interface ResultadoDashboardRenovacao<TMetricas = unknown, TItem = unknown> {
  papelResolvido: PapelDashboard;
  metricas: TMetricas;
  itens: TItem[];
  totalItens: number;
  pagina: number;
  totalPaginas: number;
  igrejasEscopo?: EscopoOpcaoFiltro[];
  equipesEscopo?: EscopoOpcaoFiltro[];
}

export function validarEntradaDashboard(raw: unknown): EntradaConsultarDashboardRenovacao {
  if (!raw || typeof raw !== 'object') {
    return { limite: 20, pagina: 1 };
  }

  const dados = raw as Record<string, unknown>;

  let papelDesejado: PapelDashboard | undefined;
  if (dados.papelDesejado !== undefined && dados.papelDesejado !== null) {
    const papelStr = String(dados.papelDesejado).trim().toUpperCase();
    const papeisValidos: PapelDashboard[] = [
      'VOLUNTARIO',
      'PASTOR_LOCAL',
      'RESPONSAVEL_EQUIPE',
      'COORDENADOR',
      'ADMINISTRADOR',
    ];
    if (!papeisValidos.includes(papelStr as PapelDashboard)) {
      throw new ParametroInvalidoDashboardError(`Papel inválido: ${dados.papelDesejado}`);
    }
    papelDesejado = papelStr as PapelDashboard;
  }

  let igrejaId: string | undefined;
  if (typeof dados.igrejaId === 'string' && dados.igrejaId.trim().length > 0) {
    igrejaId = dados.igrejaId.trim();
  }

  let equipeId: string | undefined;
  if (typeof dados.equipeId === 'string' && dados.equipeId.trim().length > 0) {
    equipeId = dados.equipeId.trim();
  }

  let estadoRenovacao: string | undefined;
  if (typeof dados.estadoRenovacao === 'string' && dados.estadoRenovacao.trim().length > 0) {
    estadoRenovacao = dados.estadoRenovacao.trim().toUpperCase();
  }

  let anoVigencia: number | undefined;
  if (dados.anoVigencia !== undefined && dados.anoVigencia !== null) {
    const ano = Number(dados.anoVigencia);
    if (!Number.isInteger(ano) || ano < 2000 || ano > 2100) {
      throw new ParametroInvalidoDashboardError('anoVigencia inválido.');
    }
    anoVigencia = ano;
  }

  let limite = 20;
  if (dados.limite !== undefined && dados.limite !== null) {
    const l = Number(dados.limite);
    if (Number.isInteger(l) && l > 0 && l <= 100) {
      limite = l;
    }
  }

  let pagina = 1;
  if (dados.pagina !== undefined && dados.pagina !== null) {
    const p = Number(dados.pagina);
    if (Number.isInteger(p) && p > 0) {
      pagina = p;
    }
  }

  return {
    papelDesejado,
    igrejaId,
    equipeId,
    estadoRenovacao,
    anoVigencia,
    limite,
    pagina,
  };
}

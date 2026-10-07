/**
 * Reautorização em tempo de consulta para acesso a uma solicitação
 * (AD-2). O acesso a qualquer detalhe/deep link é reavaliado no momento
 * da abertura contra identidade, papel atual e vínculo vigente.
 */

export class SemVinculoVigenteError extends Error {
  constructor(message = 'Usuário não possui vínculo vigente.') {
    super(message);
    this.name = 'SemVinculoVigenteError';
  }
}

export class SolicitacaoNaoEncontradaError extends Error {
  constructor(message = 'Solicitação não encontrada.') {
    super(message);
    this.name = 'SolicitacaoNaoEncontradaError';
  }
}

export type PapelAcessoDetalhe =
  | 'VOLUNTARIO'
  | 'PASTOR_LOCAL'
  | 'RESPONSAVEL_EQUIPE'
  | 'COORDENADOR';

export interface ParticipacaoDetalhe {
  id: string;
  equipeId: string;
  nomeEquipe: string;
  estado: string;
  ciclo: string;
  proximaAcao: string;
  decisao?: string | null;
}

export interface DetalheSolicitacao {
  fichaId: string;
  voluntarioUid: string;
  voluntarioNome: string;
  igrejaId: string;
  estadoFicha: string;
  versao: number;
  papelSolicitante: PapelAcessoDetalhe;
  vinculoId: string;
  reautorizadoEm: string;
  participacoes: ParticipacaoDetalhe[];
}

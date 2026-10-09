export type CapacidadeAcesso =
  | 'voluntario'
  | 'pastor_local'
  | 'responsavel_equipe'
  | 'coordenador'
  | 'administrador';

export interface EscopoIgrejaDTO {
  id: string;
  nome: string;
  codigo?: string;
}

export interface EscopoEquipeDTO {
  id: string;
  nome: string;
}

export interface ContextoAcessoDTO {
  uid: string;
  email?: string;
  capacidades: CapacidadeAcesso[];
  ehAdministrador: boolean;
  ehCoordenador: boolean;
  ehPastorLocal: boolean;
  ehResponsavelEquipe: boolean;
  ehVoluntario: boolean;
  igrejas: EscopoIgrejaDTO[];
  equipes: EscopoEquipeDTO[];
  estadoFicha?: string | null;
}

export interface ParametrosDerivacaoCapacidades {
  ehAdmin: boolean;
  ehCoord: boolean;
  temIgrejas: boolean;
  temEquipes: boolean;
  temFichaOuUsuario?: boolean;
}

/**
 * Deriva a lista determinística de capacidades ativas do usuário a partir dos
 * privilégios e vínculos vigentes no servidor (AD-02, AD-03, AD-04, AD-09).
 */
export function derivarCapacidades(params: ParametrosDerivacaoCapacidades): CapacidadeAcesso[] {
  const capacidades: CapacidadeAcesso[] = [];

  // Todo usuário autenticado tem acesso ao fluxo voluntário (criar/consultar ficha)
  capacidades.push('voluntario');

  if (params.temIgrejas) {
    capacidades.push('pastor_local');
  }

  if (params.temEquipes) {
    capacidades.push('responsavel_equipe');
  }

  if (params.ehCoord) {
    capacidades.push('coordenador');
  }

  if (params.ehAdmin) {
    capacidades.push('administrador');
  }

  return capacidades;
}

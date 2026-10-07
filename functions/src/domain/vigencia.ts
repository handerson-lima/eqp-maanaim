/**
 * Domínio de cálculo de vigência anual e alertas de renovação (Story 5.1).
 * Regido pelas decisões vinculantes AD-7, AD-10, AD-11 e AD-12.
 */

export const DIAS_AVISO_PREVIO_PADRAO = 60;
export const DIAS_RENOVACAO_IMINENTE_PADRAO = 30;

export type SituacaoVigencia =
  | 'VIGENTE'
  | 'ALERTA_PREVIO_60D'
  | 'RENOVACAO_IMINENTE_30D'
  | 'EXPIRADA'
  | 'NAO_APLICAVEL';

export interface AlertaVigenciaCalculado {
  situacao: SituacaoVigencia;
  diasRestantes: number | null;
  alerta: string | null;
  emAlertaRenovacao: boolean;
  janelaRenovacaoAberta: boolean;
}

export interface ConfiguracaoJanelaVigencia {
  diasAvisoPrevio?: number;
  diasRenovacaoIminente?: number;
}

/**
 * Adiciona exatamente um ano à data especificada preservando UTC.
 * Lida de forma segura com anos bissextos (29 de fevereiro vira 28 de fevereiro no ano seguinte).
 */
export function adicionarUmAnoUtc(dataInicio: Date): Date {
  const d = new Date(dataInicio.getTime());
  const ano = d.getUTCFullYear() + 1;
  const mes = d.getUTCMonth();
  const dia = d.getUTCDate();

  // Caso especial: 29 de fevereiro em ano bissexto
  if (mes === 1 && dia === 29) {
    const bissexto = (ano % 4 === 0 && ano % 100 !== 0) || ano % 400 === 0;
    if (!bissexto) {
      d.setUTCFullYear(ano, 1, 28);
      return d;
    }
  }

  d.setUTCFullYear(ano);
  return d;
}

/**
 * Calcula os timestamps canônicos de vigência de um ano (AD-7).
 */
export function calcularVigenciaAnual(dataAprovacaoUtc: Date): {
  vigenciaInicio: Date;
  vigenciaFim: Date;
  anoVigencia: number;
} {
  const vigenciaInicio = new Date(dataAprovacaoUtc.getTime());
  const vigenciaFim = adicionarUmAnoUtc(vigenciaInicio);
  return {
    vigenciaInicio,
    vigenciaFim,
    anoVigencia: vigenciaInicio.getUTCFullYear(),
  };
}

/**
 * Converte diferentes representações de data/timestamp para milissegundos UTC.
 */
function obterMillis(valor: Date | number | string | null | undefined): number | null {
  if (valor === null || valor === undefined) return null;
  if (typeof valor === 'number') {
    return Number.isFinite(valor) ? valor : null;
  }
  if (valor instanceof Date) {
    return valor.getTime();
  }
  if (typeof valor === 'string') {
    const parsed = Date.parse(valor);
    return Number.isNaN(parsed) ? null : parsed;
  }
  if (typeof (valor as { toMillis?: () => number }).toMillis === 'function') {
    return (valor as { toMillis: () => number }).toMillis();
  }
  if (typeof (valor as { toDate?: () => Date }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().getTime();
  }
  return null;
}

/**
 * Classifica o estado temporal de uma participação com base no relógio de referência.
 * Não expõe nenhuma PII no alerta gerado (AD-12).
 */
export function classificarVigencia(
  agora: Date | number | string,
  vigenciaFim: Date | number | string | null | undefined,
  config?: ConfiguracaoJanelaVigencia,
): AlertaVigenciaCalculado {
  const agoraMs = obterMillis(agora);
  const fimMs = obterMillis(vigenciaFim);

  if (agoraMs === null || fimMs === null) {
    return {
      situacao: 'NAO_APLICAVEL',
      diasRestantes: null,
      alerta: null,
      emAlertaRenovacao: false,
      janelaRenovacaoAberta: false,
    };
  }

  const diasAvisoPrevio = config?.diasAvisoPrevio ?? DIAS_AVISO_PREVIO_PADRAO;
  const diasRenovacaoIminente = config?.diasRenovacaoIminente ?? DIAS_RENOVACAO_IMINENTE_PADRAO;

  const diferencaMs = fimMs - agoraMs;
  // Arredonda para cima para expressar quantos dias restam até o final do período
  const diasRestantes = Math.ceil(diferencaMs / (1000 * 60 * 60 * 24));

  if (diferencaMs <= 0 || diasRestantes <= 0) {
    return {
      situacao: 'EXPIRADA',
      diasRestantes: diasRestantes <= 0 ? diasRestantes : 0,
      alerta: 'Vigência anual expirada',
      emAlertaRenovacao: true,
      janelaRenovacaoAberta: true,
    };
  }

  if (diasRestantes <= diasRenovacaoIminente) {
    return {
      situacao: 'RENOVACAO_IMINENTE_30D',
      diasRestantes,
      alerta: `Renovação necessária: vence em ${diasRestantes} dia${diasRestantes === 1 ? '' : 's'}`,
      emAlertaRenovacao: true,
      janelaRenovacaoAberta: true,
    };
  }

  if (diasRestantes <= diasAvisoPrevio) {
    return {
      situacao: 'ALERTA_PREVIO_60D',
      diasRestantes,
      alerta: `Aviso de renovação: vence em ${diasRestantes} dias`,
      emAlertaRenovacao: true,
      janelaRenovacaoAberta: true,
    };
  }

  return {
    situacao: 'VIGENTE',
    diasRestantes,
    alerta: null,
    emAlertaRenovacao: false,
    janelaRenovacaoAberta: false,
  };
}

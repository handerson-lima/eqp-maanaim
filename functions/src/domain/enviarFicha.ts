import { createHash } from 'node:crypto';

export class ComandoDivergenteError extends Error {
  constructor(message = 'Operação já registrada com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export class FichaNaoEncontradaError extends Error {
  constructor(message = 'Ficha permanente não encontrada.') {
    super(message);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class FichaNaoRascunhoError extends Error {
  constructor(message = 'A ficha não está em estado de rascunho para envio.') {
    super(message);
    this.name = 'FichaNaoRascunhoError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(message = 'Conflito de concorrência: a versão da ficha foi alterada.') {
    super(message);
    this.name = 'ConflitoVersaoError';
  }
}

export class DadosIncompletosError extends Error {
  constructor(message = 'Dados cadastrais obrigatórios incompletos.') {
    super(message);
    this.name = 'DadosIncompletosError';
  }
}

export class SemParticipacoesError extends Error {
  constructor(message = 'É necessário ter ao menos uma equipe selecionada antes do envio.') {
    super(message);
    this.name = 'SemParticipacoesError';
  }
}

export class EquipeInativaError extends Error {
  constructor(message = 'Uma ou mais equipes selecionadas estão inativas no catálogo.') {
    super(message);
    this.name = 'EquipeInativaError';
  }
}

export class TermoNaoAceitoError extends Error {
  constructor(message = 'O termo de voluntariado vigente deve ser aceito antes do envio da ficha.') {
    super(message);
    this.name = 'TermoNaoAceitoError';
  }
}

export class IgrejaInativaError extends Error {
  constructor(message = 'A igreja informada está inativa ou inválida.') {
    super(message);
    this.name = 'IgrejaInativaError';
  }
}

export class PermissaoNegadaError extends Error {
  constructor(message = 'Não é permitido enviar a ficha de outro voluntário.') {
    super(message);
    this.name = 'PermissaoNegadaError';
  }
}

export class EnvioInvalidoError extends Error {
  constructor(message = 'Dados inválidos para envio da ficha.') {
    super(message);
    this.name = 'EnvioInvalidoError';
  }
}

export interface EntradaEnviarFichaAprovacao {
  commandId: string;
  correlationId?: string;
  expectedVersion?: number;
  payloadHash: string;
}

export interface ResultadoEnviarFichaAprovacao {
  sucesso: boolean;
  repetido: boolean;
  estado: string;
  versao: number;
  proximaAcao: string;
  igrejaId: string;
  enviadoEm: string;
}

export function calcularPayloadHashEnviarFicha(dados: {
  expectedVersion?: number;
}): string {
  const normalizado = {
    expectedVersion: dados.expectedVersion ?? null,
  };
  return createHash('sha256').update(JSON.stringify(normalizado)).digest('hex');
}

export function validarEnviarFicha(dados: unknown): EntradaEnviarFichaAprovacao {
  if (!dados || typeof dados !== 'object') {
    throw new EnvioInvalidoError('Corpo da requisição inválido.');
  }

  const payload = dados as Record<string, unknown>;

  const commandId =
    typeof payload.commandId === 'string' ? payload.commandId.trim() : '';
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(commandId)) {
    throw new EnvioInvalidoError('Identificador de comando (commandId) inválido.');
  }

  let correlationId: string | undefined;
  if (payload.correlationId !== undefined && payload.correlationId !== null) {
    if (typeof payload.correlationId !== 'string' || payload.correlationId.trim().length === 0) {
      throw new EnvioInvalidoError('correlationId inválido.');
    }
    correlationId = payload.correlationId.trim();
  }

  let expectedVersion: number | undefined;
  if (payload.expectedVersion !== undefined && payload.expectedVersion !== null) {
    if (typeof payload.expectedVersion !== 'number' || payload.expectedVersion < 0) {
      throw new EnvioInvalidoError('Versão esperada inválida.');
    }
    expectedVersion = payload.expectedVersion;
  }

  const payloadHash = calcularPayloadHashEnviarFicha({ expectedVersion });

  return {
    commandId,
    correlationId,
    expectedVersion,
    payloadHash,
  };
}

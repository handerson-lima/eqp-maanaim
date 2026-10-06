import { createHash } from 'node:crypto';

export const TERMO_ID_PADRAO = 'termo-adesao-voluntariado';
export const TIPO_TERMO_PADRAO = 'ADESAO_VOLUNTARIADO' as const;

export type TipoTermo = typeof TIPO_TERMO_PADRAO;

export class TermoInvalidoError extends Error {
  constructor(mensagem = 'Dados do termo inválidos.') {
    super(mensagem);
    this.name = 'TermoInvalidoError';
  }
}

export class SemAutoridadeError extends Error {
  constructor(mensagem = 'Apenas administradores podem publicar termos.') {
    super(mensagem);
    this.name = 'SemAutoridadeError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(mensagem = 'Comando divergente já registrado.') {
    super(mensagem);
    this.name = 'ComandoDivergenteError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(mensagem = 'Conflito de versão na publicação do termo.') {
    super(mensagem);
    this.name = 'ConflitoVersaoError';
  }
}

export class EdicaoImutavelError extends Error {
  constructor(mensagem = 'Versão de termo publicada é estritamente imutável.') {
    super(mensagem);
    this.name = 'EdicaoImutavelError';
  }
}

export class TermoNaoVigenteError extends Error {
  constructor(
    mensagem = 'A versão do termo informada não corresponde à versão vigente.',
  ) {
    super(mensagem);
    this.name = 'TermoNaoVigenteError';
  }
}

export class EquipesNaoSelecionadasError extends Error {
  constructor(
    mensagem = 'É necessário selecionar ao menos uma equipe antes de aceitar o termo.',
  ) {
    super(mensagem);
    this.name = 'EquipesNaoSelecionadasError';
  }
}

export class DeclaracaoNaoInformadaError extends Error {
  constructor(
    mensagem = 'A declaração explícita de leitura e concordância é obrigatória.',
  ) {
    super(mensagem);
    this.name = 'DeclaracaoNaoInformadaError';
  }
}

export class FichaNaoEncontradaError extends Error {
  constructor(mensagem = 'Ficha permanente não encontrada.') {
    super(mensagem);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class FichaNaoEditavelError extends Error {
  constructor(
    mensagem = 'Apenas fichas em rascunho podem ter o termo aceito.',
  ) {
    super(mensagem);
    this.name = 'FichaNaoEditavelError';
  }
}

export class PermissaoNegadaError extends Error {
  constructor(
    mensagem = 'Operação não autorizada para o usuário informado.',
  ) {
    super(mensagem);
    this.name = 'PermissaoNegadaError';
  }
}

export interface EntradaPublicarTermo {
  commandId: string;
  correlationId?: string;
  termoId: string;
  tipoTermo: TipoTermo;
  titulo: string;
  conteudo: string;
  hashConteudo: string;
  expectedVersion: number;
  payloadHash: string;
}

export interface VersaoTermoResumo {
  id: string;
  termoId: string;
  numeroVersao: number;
  titulo: string;
  conteudo: string;
  hashSha256: string;
  publicadoEm: string;
  publicadoPorUid: string;
  versaoAnteriorId: string | null;
  imutavel: boolean;
}

export interface TermoResumo {
  id: string;
  tipoTermo: TipoTermo;
  titulo: string;
  versaoVigenteId: string;
  versaoVigenteNumero: number;
  hashSha256: string;
  totalVersoes: number;
  publicadoEm: string;
  atualizadoEm: string;
  ativo: boolean;
  versoes?: VersaoTermoResumo[];
}

/**
 * Calcula o hash SHA-256 canônico sobre o conteúdo normalizado do termo.
 */
export function calcularHashConteudo(titulo: string, conteudo: string): string {
  const normalizado = `${titulo.trim()}\n\n${conteudo.trim()}`;
  return createHash('sha256').update(normalizado, 'utf8').digest('hex');
}

/**
 * Calcula o hash determinístico do payload do comando sem persistir PII.
 */
export function calcularPayloadHash(
  dados: Omit<EntradaPublicarTermo, 'payloadHash'>,
): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        commandId: dados.commandId,
        correlationId: dados.correlationId ?? '',
        termoId: dados.termoId,
        tipoTermo: dados.tipoTermo,
        titulo: dados.titulo,
        hashConteudo: dados.hashConteudo,
        expectedVersion: dados.expectedVersion,
      }),
      'utf8',
    )
    .digest('hex');
}

/**
 * Valida a entrada do comando de publicação do termo.
 */
export function validarPublicarTermo(raw: unknown): EntradaPublicarTermo {
  if (!raw || typeof raw !== 'object') {
    throw new TermoInvalidoError('Entrada do termo deve ser um objeto.');
  }

  const obj = raw as Record<string, unknown>;

  const commandId = typeof obj.commandId === 'string' ? obj.commandId.trim() : '';
  if (!commandId || commandId.length < 16) {
    throw new TermoInvalidoError('commandId ausente ou inválido (mínimo 16 caracteres).');
  }

  const correlationId =
    typeof obj.correlationId === 'string' && obj.correlationId.trim()
      ? obj.correlationId.trim()
      : undefined;

  const termoId =
    typeof obj.termoId === 'string' && obj.termoId.trim()
      ? obj.termoId.trim()
      : TERMO_ID_PADRAO;

  const tipoTermo =
    obj.tipoTermo === TIPO_TERMO_PADRAO ? TIPO_TERMO_PADRAO : TIPO_TERMO_PADRAO;

  const titulo = typeof obj.titulo === 'string' ? obj.titulo.trim() : '';
  if (titulo.length < 3 || titulo.length > 150) {
    throw new TermoInvalidoError('Título deve ter entre 3 e 150 caracteres.');
  }

  const conteudo = typeof obj.conteudo === 'string' ? obj.conteudo.trim() : '';
  if (conteudo.length < 20) {
    throw new TermoInvalidoError('Conteúdo do termo deve ter no mínimo 20 caracteres.');
  }

  const expectedVersion =
    typeof obj.expectedVersion === 'number' && Number.isInteger(obj.expectedVersion) && obj.expectedVersion >= 0
      ? obj.expectedVersion
      : 0;

  const hashConteudo = calcularHashConteudo(titulo, conteudo);

  const entradaParcial: Omit<EntradaPublicarTermo, 'payloadHash'> = {
    commandId,
    correlationId,
    termoId,
    tipoTermo,
    titulo,
    conteudo,
    hashConteudo,
    expectedVersion,
  };

  return {
    ...entradaParcial,
    payloadHash: calcularPayloadHash(entradaParcial),
  };
}

export interface EntradaAceitarTermoVigente {
  commandId: string;
  correlationId?: string;
  termoId: string;
  versaoId: string;
  hashSha256: string;
  declaracaoLidoEConcordo: boolean;
  payloadHash: string;
}

export interface ComprovanteAceiteTermo {
  id: string;
  uid: string;
  fichaId: string;
  termoId: string;
  versaoId: string;
  numeroVersao: number;
  hashSha256: string;
  titulo: string;
  declaracaoLidoEConcordo: boolean;
  aceitoEm: string;
  commandId: string;
  repetido?: boolean;
}

/**
 * Calcula o hash determinístico do payload de aceite do termo.
 */
export function calcularPayloadHashAceite(dados: {
  commandId: string;
  correlationId?: string;
  termoId?: string;
  versaoId: string;
  hashSha256: string;
  declaracaoLidoEConcordo: boolean;
}): string {
  const termoId =
    typeof dados.termoId === 'string' && dados.termoId.trim()
      ? dados.termoId.trim()
      : TERMO_ID_PADRAO;

  return createHash('sha256')
    .update(
      JSON.stringify({
        commandId: dados.commandId.trim(),
        correlationId: dados.correlationId?.trim() ?? '',
        termoId,
        versaoId: dados.versaoId.trim(),
        hashSha256: dados.hashSha256.trim(),
        declaracaoLidoEConcordo: dados.declaracaoLidoEConcordo,
      }),
      'utf8',
    )
    .digest('hex');
}

/**
 * Valida a entrada da requisição de aceite do termo vigente.
 */
export function validarAceitarTermoVigente(raw: unknown): EntradaAceitarTermoVigente {
  if (!raw || typeof raw !== 'object') {
    throw new TermoInvalidoError('Entrada do comando deve ser um objeto.');
  }

  const obj = raw as Record<string, unknown>;

  const commandId = typeof obj.commandId === 'string' ? obj.commandId.trim() : '';
  if (!commandId || commandId.length < 16) {
    throw new TermoInvalidoError('commandId ausente ou inválido (mínimo 16 caracteres).');
  }

  const correlationId =
    typeof obj.correlationId === 'string' && obj.correlationId.trim()
      ? obj.correlationId.trim()
      : undefined;

  const termoId =
    typeof obj.termoId === 'string' && obj.termoId.trim()
      ? obj.termoId.trim()
      : TERMO_ID_PADRAO;

  const versaoId = typeof obj.versaoId === 'string' ? obj.versaoId.trim() : '';
  if (!versaoId) {
    throw new TermoInvalidoError('Identificador da versão do termo ausente.');
  }

  const hashSha256 = typeof obj.hashSha256 === 'string' ? obj.hashSha256.trim() : '';
  if (!hashSha256 || hashSha256.length < 32) {
    throw new TermoInvalidoError('Hash do termo inválido ou ausente.');
  }

  if (obj.declaracaoLidoEConcordo !== true) {
    throw new DeclaracaoNaoInformadaError();
  }

  const parcial: Omit<EntradaAceitarTermoVigente, 'payloadHash'> = {
    commandId,
    correlationId,
    termoId,
    versaoId,
    hashSha256,
    declaracaoLidoEConcordo: true,
  };

  return {
    ...parcial,
    payloadHash: calcularPayloadHashAceite(parcial),
  };
}


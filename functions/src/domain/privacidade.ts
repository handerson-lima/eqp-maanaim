/**
 * Sanitizador canônico de dados pessoais e política de retenção (AD-12, LGPD).
 *
 * Fonte única para:
 * 1. Remover/mascarar PII de payloads de auditoria, outbox, alertas, erros e logs.
 * 2. Calcular o prazo de retenção de 5 anos em UTC.
 *
 * O schema permitido para eventos é: IDs opacos, ação, estado, timestamps,
 * papel/vínculo em snapshot e motivo categorizado.
 */

export const POLITICA_RETENCAO_ID = 'AD-12_V1';
export const ANOS_RETENCAO = 5;
export const CPF_MASCARADO = '***.***.***-**';
export const NOME_ANONIMIZADO = 'Nome Anonimizado';
export const TAMANHO_MAXIMO_MENSAGEM_ERRO = 300;
const PROFUNDIDADE_MAXIMA = 12;

/** Chaves que, normalizadas, são iguais a um destes valores, são sempre removidas. */
const CHAVES_PII_EXATAS = new Set([
  'nomecompleto',
  'nomevoluntario',
  'nomecivil',
  'nomecoordenador',
  'coordenadornome',
  'voluntarionome',
  'profissaovoluntario',
  'nacionalidadevoluntario',
  'cpf',
  'rg',
  'profissao',
  'nacionalidade',
  'endereco',
  'enderecoresidencial',
  'logradouro',
  'cep',
  'telefone',
  'celular',
  'whatsapp',
  'email',
  'contato',
  'datanascimento',
  'documento',
  'documentos',
  'fcm',
  'fcmtoken',
  'devicetoken',
]);

/** Chaves que contenham qualquer um destes trechos (normalizados) são removidas. */
const CHAVES_PII_PARCIAIS = [
  'senha',
  'password',
  'token',
  'secret',
  'authorization',
  'privatekey',
  'segredo',
  'assinatura',
  'cpf',
  'profissao',
  'nacionalidade',
  'nascimento',
  'endereco',
  'telefone',
  'celular',
  'whatsapp',
  'email',
  'documento',
  'rg',
];

/**
 * Trechos que, combinados com `nome`, denotam nome de pessoa. Permite remover
 * chaves compostas (`voluntarioNome`, `nomeCoordenador`) sem afetar chaves
 * institucionais como `nomeEquipe` e `nomeIgreja`.
 */
const TRECHOS_NOME_PESSOAL = [
  'voluntario',
  'civil',
  'completo',
  'coordenador',
  'pastor',
  'responsavel',
  'pessoa',
  'usuario',
  'beneficiario',
];

const REGEX_CPF = /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/g;
const REGEX_EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const REGEX_TELEFONE = /\(\d{2}\)\s?9?\d{4}-?\d{4}|\b9?\d{4}-\d{4}\b/g;

function normalizarChave(chave: string): string {
  return chave
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[_\s-]/g, '');
}

export function chaveContemPii(chave: string): boolean {
  const normalizada = normalizarChave(chave);
  if (CHAVES_PII_EXATAS.has(normalizada)) return true;
  // Nome de pessoa em chave composta; preserva `nomeEquipe`/`nomeIgreja`.
  if (
    normalizada.includes('nome') &&
    TRECHOS_NOME_PESSOAL.some((trecho) => normalizada.includes(trecho))
  ) {
    return true;
  }
  return CHAVES_PII_PARCIAIS.some((trecho) =>
    trecho.length < 3
      ? normalizada.startsWith(trecho) || normalizada.endsWith(trecho)
      : normalizada.includes(trecho),
  );
}

/** Mascara CPF, e-mail e telefone presentes em texto livre. */
export function mascararTexto(texto: string): string {
  return texto
    .replace(REGEX_EMAIL, '[email-removido]')
    .replace(REGEX_CPF, CPF_MASCARADO)
    .replace(REGEX_TELEFONE, '[telefone-removido]');
}

function ehObjetoSimples(valor: object): boolean {
  const proto = Object.getPrototypeOf(valor);
  return proto === Object.prototype || proto === null;
}

/**
 * Remove recursivamente chaves de PII/segredos e mascara padrões de PII em strings.
 * Objetos não simples (Timestamp, FieldValue, Date) são preservados intactos.
 */
export function sanitizarPii(valor: unknown, profundidade = 0): unknown {
  if (valor === null || valor === undefined) return valor;
  if (profundidade > PROFUNDIDADE_MAXIMA) return '[profundidade-excedida]';

  if (typeof valor === 'string') return mascararTexto(valor);
  if (typeof valor !== 'object') return valor;

  if (Array.isArray(valor)) {
    return valor.map((item) => sanitizarPii(item, profundidade + 1));
  }

  if (!ehObjetoSimples(valor)) return valor;

  const resultado: Record<string, unknown> = {};
  for (const [chave, val] of Object.entries(valor as Record<string, unknown>)) {
    if (chaveContemPii(chave)) continue;
    resultado[chave] = sanitizarPii(val, profundidade + 1);
  }
  return resultado;
}

/** Indica se o valor contém chave de PII ou padrão de PII em alguma string. */
export function contemPii(valor: unknown, profundidade = 0): boolean {
  if (valor === null || valor === undefined) return false;
  if (profundidade > PROFUNDIDADE_MAXIMA) return false;
  if (typeof valor === 'string') {
    return mascararTexto(valor) !== valor;
  }
  if (typeof valor !== 'object') return false;
  if (Array.isArray(valor)) return valor.some((v) => contemPii(v, profundidade + 1));
  if (!ehObjetoSimples(valor)) return false;
  return Object.entries(valor as Record<string, unknown>).some(
    ([chave, val]) => chaveContemPii(chave) || contemPii(val, profundidade + 1),
  );
}

export interface ErroSanitizado {
  nome: string;
  codigo?: string;
  mensagem: string;
}

/** Converte qualquer erro em estrutura mínima, sem PII, segura para logs e Firestore. */
export function sanitizarErro(erro: unknown): ErroSanitizado {
  if (erro instanceof Error) {
    const codigo = (erro as { code?: unknown }).code;
    return {
      nome: erro.name || 'Error',
      ...(typeof codigo === 'string' ? { codigo } : {}),
      mensagem: mascararTexto(erro.message).slice(0, TAMANHO_MAXIMO_MENSAGEM_ERRO),
    };
  }
  return {
    nome: 'ErroDesconhecido',
    mensagem: mascararTexto(String(erro ?? '')).slice(0, TAMANHO_MAXIMO_MENSAGEM_ERRO),
  };
}

/** Texto seguro para campo de erro/log: somente mensagem sanitizada e truncada. */
export function mensagemErroSegura(erro: unknown): string {
  return sanitizarErro(erro).mensagem;
}

/**
 * Retenção probatória: criação + `anos` em UTC (padrão 5, salvo obrigação legal superior).
 * Retorna ISO-8601 em UTC.
 */
export function calcularRetencaoAte(base: Date | string | number, anos = ANOS_RETENCAO): string {
  const data = new Date(base);
  if (Number.isNaN(data.getTime())) {
    throw new Error('Data base de retenção inválida.');
  }
  const resultado = new Date(data.getTime());
  resultado.setUTCFullYear(resultado.getUTCFullYear() + anos);
  return resultado.toISOString();
}

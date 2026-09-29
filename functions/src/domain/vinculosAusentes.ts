import { extrairCodigoIgreja, type EntradaBruta } from './importacaoPastores.js';

export type VinculoAusente = {
  /** Código canônico da igreja que não aparece na planilha local. */
  codigo: string;
  /** Código de outra igreja já vinculada à mesma identidade pastoral. */
  referenciaCodigo: string;
  /** Nome canônico da igreja, não-PII, somente para leitura operacional. */
  igreja: string;
};

/**
 * Vínculos ausentes na planilha fornecida, decididos na aprovação do contrato:
 * Macau (240005) pertence à identidade pastoral já vinculada a Mossoró (240006)
 * e Ponta Negra (240029) à identidade já vinculada a Monte Alegre (240022).
 * A referência por código evita gravar nomes ou e-mails no repositório.
 */
export const VINCULOS_AUSENTES: readonly VinculoAusente[] = [
  { codigo: '240005', referenciaCodigo: '240006', igreja: 'Macau' },
  { codigo: '240029', referenciaCodigo: '240022', igreja: 'Ponta Negra' },
];

/**
 * Acrescenta as linhas ausentes herdando a identidade (nome/e-mail) de uma
 * linha de referência existente. Se a planilha já contempla o código, nada é
 * duplicado. Não grava PII: os valores permanecem apenas em memória.
 */
export function aplicarVinculosAusentes(
  entradas: EntradaBruta[],
  ausentes: readonly VinculoAusente[] = VINCULOS_AUSENTES,
): EntradaBruta[] {
  const resultado = [...entradas];
  const codigosExistentes = new Set<string>();
  const porCodigo = new Map<string, EntradaBruta>();
  for (const entrada of resultado) {
    const codigo = extrairCodigoIgreja(entrada.codigoIgreja);
    if (!codigo) continue;
    codigosExistentes.add(codigo);
    if (!porCodigo.has(codigo)) porCodigo.set(codigo, entrada);
  }
  for (const ausente of ausentes) {
    if (codigosExistentes.has(ausente.codigo)) continue;
    const referencia = porCodigo.get(ausente.referenciaCodigo);
    if (!referencia) throw new Error(`REFERENCIA_AUSENTE:${ausente.codigo}`);
    resultado.push({
      codigoIgreja: ausente.codigo,
      nomePastor: referencia.nomePastor,
      email: referencia.email,
    });
    codigosExistentes.add(ausente.codigo);
  }
  return resultado;
}

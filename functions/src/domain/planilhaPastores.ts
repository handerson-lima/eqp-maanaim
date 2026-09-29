import type { EntradaBruta } from './importacaoPastores.js';

const CABECALHO_ESPERADO = ['igreja', 'pastor', 'email'];

function dividirLinha(linha: string): string[] {
  const campos: string[] = [];
  let atual = '';
  let dentroAspas = false;
  for (let i = 0; i < linha.length; i += 1) {
    const caractere = linha[i];
    if (dentroAspas) {
      if (caractere === '"') {
        if (linha[i + 1] === '"') {
          atual += '"';
          i += 1;
        } else {
          dentroAspas = false;
        }
      } else {
        atual += caractere;
      }
    } else if (caractere === '"') {
      dentroAspas = true;
    } else if (caractere === ',') {
      campos.push(atual);
      atual = '';
    } else {
      atual += caractere;
    }
  }
  campos.push(atual);
  return campos;
}

/**
 * Lê a planilha local de igreja/pastor/e-mail. Não valida conteúdo nem
 * interpreta PII; apenas separa as colunas na ordem canônica.
 */
export function parsearPlanilhaPastores(texto: string): EntradaBruta[] {
  const linhas = texto
    .replace(/^\uFEFF/, '')
    .split(/\r\n|\n|\r/)
    .filter((linha) => linha.trim().length > 0);
  if (linhas.length === 0) throw new Error('PLANILHA_VAZIA');

  const cabecalho = dividirLinha(linhas[0]).map((campo) =>
    campo.trim().toLowerCase(),
  );
  const cabecalhoValido = CABECALHO_ESPERADO.every(
    (nome, indice) => cabecalho[indice] === nome,
  );
  if (!cabecalhoValido) throw new Error('CABECALHO_INVALIDO');

  return linhas.slice(1).map((linha) => {
    const campos = dividirLinha(linha);
    return {
      codigoIgreja: campos[0] ?? '',
      nomePastor: campos[1] ?? '',
      email: campos[2] ?? '',
    };
  });
}

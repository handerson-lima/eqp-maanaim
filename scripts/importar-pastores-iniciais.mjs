#!/usr/bin/env node
// Execução administrativa local da carga inicial de pastores e vínculos.
// A planilha de PII permanece no disco local; o relatório nunca ecoa nomes,
// e-mails, CPF ou qualquer campo pessoal.
//
// Uso:
//   node scripts/importar-pastores-iniciais.mjs --dry-run <planilha.csv>
//   node scripts/importar-pastores-iniciais.mjs --executar <planilha.csv> \
//     [--command-id <id>] [--origem <texto>]
//
// Requer build prévio: npm run build --prefix functions

import { randomBytes } from 'node:crypto';
import { argv, exit, stdout, stderr } from 'node:process';

const USO = `Uso:
  node scripts/importar-pastores-iniciais.mjs --dry-run <planilha.csv>
  node scripts/importar-pastores-iniciais.mjs --executar <planilha.csv> [opções]

Opções:
  --dry-run      valida a planilha e a base, sem gravar nada (modo simulação)
  --executar     aplica a carga (requer credenciais administrativas/emulador)
  --command-id   identificador opaco idempotente (16-128 caracteres)
  --origem       origem auditável (padrão: seed-inicial-do-sistema)

Os vínculos ausentes da planilha (Macau 240005 e Ponta Negra 240029) são
acrescentados automaticamente a partir das identidades já presentes.
`;

function lerArgumentos(args) {
  const opcoes = { modo: null, caminho: null, commandId: null, origem: null };
  const restantes = [];
  for (let i = 0; i < args.length; i += 1) {
    const argumento = args[i];
    if (argumento === '--dry-run' || argumento === '--executar') {
      const modo = argumento === '--dry-run' ? 'SIMULACAO' : 'EXECUCAO';
      if (opcoes.modo !== null && opcoes.modo !== modo) {
        throw new Error('MODO_CONFLITANTE');
      }
      opcoes.modo = modo;
    } else if (argumento === '--command-id' || argumento === '--origem') {
      const valor = args[i + 1];
      if (valor === undefined || valor.startsWith('--')) {
        throw new Error('VALOR_OBRIGATORIO');
      }
      i += 1;
      if (argumento === '--command-id') opcoes.commandId = valor;
      else opcoes.origem = valor;
    } else if (argumento.startsWith('--')) {
      throw new Error('OPCAO_DESCONHECIDA');
    } else {
      restantes.push(argumento);
    }
  }
  opcoes.caminho = restantes[0] ?? null;
  if (opcoes.modo === null) throw new Error('MODO_OBRIGATORIO');
  if (!opcoes.caminho) throw new Error('ARQUIVO_OBRIGATORIO');
  return opcoes;
}

function mensagemSegura(erro) {
  const codigo = erro && typeof erro === 'object' ? erro.code : null;
  if (typeof codigo === 'string' && /^[a-z0-9/_-]+$/i.test(codigo)) {
    return `Falha controlada (${codigo}).`;
  }
  if (erro instanceof Error && /^[A-Z_]+(:\d{6})?$/.test(erro.message)) {
    return `Falha controlada (${erro.message}).`;
  }
  return 'Falha controlada na importação.';
}

async function principal() {
  const opcoes = lerArgumentos(argv.slice(2));
  const commandId =
    opcoes.commandId ?? randomBytes(16).toString('hex');
  // Importa o build versionado; evita interpretar TypeScript em runtime.
  const { importarDeArquivo } = await import(
    '../functions/lib/commands/importarPastoresIniciais.js'
  );
  const resultado = await importarDeArquivo({
    caminho: opcoes.caminho,
    modo: opcoes.modo,
    commandId,
    origem: opcoes.origem ?? undefined,
  });
  stdout.write(`${JSON.stringify(resultado, null, 2)}\n`);
  exit(resultado.recusados > 0 ? 1 : 0);
}

principal().catch((erro) => {
  stderr.write(`${mensagemSegura(erro)}\n`);
  stderr.write(USO);
  exit(2);
});

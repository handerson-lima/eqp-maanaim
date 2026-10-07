#!/usr/bin/env node
/**
 * Aplica os controles operacionais de retenção e segurança (AD-12).
 *
 * Por padrão apenas IMPRIME os comandos `gcloud` que seriam executados.
 * Nada é alterado no ambiente sem a flag explícita `--executar`.
 *
 * Uso:
 *   node scripts/aplicar-controles-operacionais.mjs [--projeto <id>] [--bucket <nome>] [--executar]
 */

import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const RAIZ_PROJETO = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export function lerJson(caminhoAbsoluto) {
  return JSON.parse(readFileSync(caminhoAbsoluto, 'utf8'));
}

/** Descobre o projectId a partir do `.firebaserc` quando disponível. */
export function descobrirProjeto(rootDir = RAIZ_PROJETO) {
  const caminho = join(rootDir, '.firebaserc');
  if (!existsSync(caminho)) return '';
  try {
    const dados = lerJson(caminho);
    return String(dados?.projects?.default ?? '').trim();
  } catch {
    return '';
  }
}

/**
 * Constrói a lista de comandos `gcloud` (sem executá-los).
 * @returns {Array<{descricao: string, comando: string, args: string[]}>}
 */
export function construirComandos(opcoes = {}) {
  const rootDir = opcoes.rootDir ?? RAIZ_PROJETO;
  const projeto = (opcoes.projeto ?? descobrirProjeto(rootDir) ?? '').trim();
  const bucket = (opcoes.bucket ?? (projeto ? `${projeto}.appspot.com` : '')).trim();

  const prefixoProjeto = projeto ? ['--project', projeto] : [];
  const caminhoLifecycle = join(rootDir, 'infra', 'storage-lifecycle.json');
  const caminhoAlertas = join(rootDir, 'infra', 'alertas-monitoramento.json');

  const comandos = [];

  if (bucket) {
    comandos.push({
      descricao: `Aplicar lifecycle de retenção (5 anos) no bucket ${bucket}`,
      comando: 'gcloud',
      args: [
        'storage',
        'buckets',
        'update',
        `gs://${bucket}`,
        `--lifecycle-file=${caminhoLifecycle}`,
        ...prefixoProjeto,
      ],
    });
  }

  const alertas = lerJson(caminhoAlertas);
  const dirTemp = mkdtempSync(join(tmpdir(), 'maanaim-alertas-'));
  for (const policy of alertas.policies ?? []) {
    const nome = `policy_${String(policy.categoria ?? policy.displayName ?? 'alerta')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')}.json`;
    const caminhoPolicy = join(dirTemp, nome);
    // O campo `categoria` é metadado de governança do repositório, não parte do
    // schema da política do Cloud Monitoring: é removido antes de aplicar.
    const { categoria: _categoria, ...policyCloud } = policy;
    writeFileSync(caminhoPolicy, JSON.stringify(policyCloud, null, 2), 'utf8');
    comandos.push({
      descricao: `Criar alerta de monitoramento (${policy.categoria ?? policy.displayName})`,
      comando: 'gcloud',
      args: [
        'monitoring',
        'policies',
        'create',
        `--policy-from-file=${caminhoPolicy}`,
        ...prefixoProjeto,
      ],
    });
  }

  return comandos;
}

function imprimir(comandos) {
  if (comandos.length === 0) {
    console.log('Nenhum comando aplicável (informe --projeto e/ou --bucket).');
    return;
  }
  console.log('Comandos gcloud que seriam executados (modo simulação):');
  for (const item of comandos) {
    console.log(`\n# ${item.descricao}`);
    console.log(`${item.comando} ${item.args.join(' ')}`);
  }
  console.log('\nNada foi alterado. Reexecute com --executar para aplicar.');
}

function executar(comandos) {
  for (const item of comandos) {
    console.log(`\n$ ${item.comando} ${item.args.join(' ')}`);
    const resultado = spawnSync(item.comando, item.args, { stdio: 'inherit' });
    if (resultado.status !== 0) {
      console.error(`Falha ao executar: ${item.descricao}`);
      process.exit(resultado.status ?? 1);
    }
  }
}

export function main(argv = process.argv.slice(2)) {
  const executarDeFato = argv.includes('--executar');
  const projeto = valorOpcao(argv, '--projeto');
  const bucket = valorOpcao(argv, '--bucket');

  if (argv.includes('--help') || argv.includes('-h')) {
    console.log(
      'Uso: node scripts/aplicar-controles-operacionais.mjs [--projeto <id>] [--bucket <nome>] [--executar]',
    );
    return 0;
  }

  const comandos = construirComandos({ projeto, bucket });
  if (executarDeFato) {
    executar(comandos);
  } else {
    imprimir(comandos);
  }
  return 0;
}

function valorOpcao(argv, nome) {
  const indice = argv.indexOf(nome);
  if (indice === -1) return undefined;
  return argv[indice + 1];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main());
}

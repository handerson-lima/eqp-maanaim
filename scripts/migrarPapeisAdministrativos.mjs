#!/usr/bin/env node
// Processo operacional IAM/ADC idempotente que conclui a migração decidida em Q1:
// normaliza `papel` singular para `papeis: string[]` no agregado canônico
// autoridadesAdministrativas/{uid} e reconcilia a projeção de claims. Não
// imprime nem persiste UID, PII ou conteúdo sensível na saída.
//
// Uso:
//   node scripts/migrarPapeisAdministrativos.mjs --dry-run
//   node scripts/migrarPapeisAdministrativos.mjs --executar
//
// Requer build prévio: npm run build --prefix functions

import { argv, env, exit, stdout, stderr } from 'node:process';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const USO = `Uso:
  node scripts/migrarPapeisAdministrativos.mjs --dry-run
  node scripts/migrarPapeisAdministrativos.mjs --executar

--dry-run   conta os documentos a normalizar sem gravar
--executar  normaliza os documentos e reconcilia as claims por papel

As dependências são resolvidas a partir de functions/node_modules.
`;

function lerModo(args) {
  let modo = null;
  for (const argumento of args) {
    if (argumento === '--dry-run' || argumento === '--executar') {
      const proposto = argumento === '--dry-run' ? 'SIMULACAO' : 'EXECUCAO';
      if (modo !== null && modo !== proposto) throw new Error('MODO_CONFLITANTE');
      modo = proposto;
    } else {
      throw new Error('OPCAO_DESCONHECIDA');
    }
  }
  if (modo === null) throw new Error('MODO_OBRIGATORIO');
  return modo;
}

/** Plano idempotente: só normaliza documentos ainda no formato de `papel` singular. */
export function planejarMigracao(docs, papeisSistema) {
  const permitidos = new Set(papeisSistema);
  const planos = [];
  let jaNormalizados = 0;
  for (const doc of docs) {
    const dados = doc.data() ?? {};
    // Um documento já plural e sem campo legado está normalizado; se ambos
    // existem, o legado ainda precisa ser mesclado e removido.
    if (Array.isArray(dados.papeis) && dados.papel === undefined) {
      jaNormalizados += 1;
      continue;
    }
    const legado =
      typeof dados.papel === 'string'
        ? [dados.papel]
        : Array.isArray(dados.papel)
          ? dados.papel
          : [];
    const base = Array.isArray(dados.papeis) ? dados.papeis : [];
    const bruto = [...base, ...legado];
    const papeis = [...new Set(bruto.filter((papel) => permitidos.has(papel)))];
    // Preserva a revogação: um documento inativo não volta a vigorar só porque
    // ainda carrega o papel no formato antigo.
    planos.push({ id: doc.id, papeis, ativa: dados.ativa === true && papeis.length > 0 });
  }
  return { planos, jaNormalizados };
}

function mensagemSegura(erro) {
  const codigo = erro && typeof erro === 'object' ? erro.code : null;
  if (typeof codigo === 'string' && /^[a-z0-9/_-]+$/i.test(codigo)) {
    return `Falha controlada (${codigo}).`;
  }
  return 'Falha controlada na migração de papéis.';
}

async function principal() {
  const modo = lerModo(argv.slice(2));
  const requireFromFunctions = createRequire(
    new URL('../functions/package.json', import.meta.url),
  );
  const { getApps, getApp, initializeApp } = requireFromFunctions('firebase-admin/app');
  const { getFirestore, FieldValue } = requireFromFunctions('firebase-admin/firestore');
  const { PAPEIS_SISTEMA } = await import(
    '../functions/lib/domain/autoridadeAdministrativa.js'
  );
  const { reconciliarClaimAdministrativa } = await import(
    '../functions/lib/repositories/autoridadeAdministrativa.js'
  );

  // Com ADC de usuário o Auth não infere o projeto; use GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.
  const projeto = env.GOOGLE_CLOUD_PROJECT ?? env.GCLOUD_PROJECT ?? null;
  const app = getApps().length ? getApp() : initializeApp(projeto ? { projectId: projeto } : undefined);
  const db = getFirestore(app);

  const snapshot = await db.collection('autoridadesAdministrativas').get();
  const { planos, jaNormalizados } = planejarMigracao(snapshot.docs, PAPEIS_SISTEMA);

  if (modo === 'SIMULACAO') {
    stdout.write(
      `${JSON.stringify(
        { modo, status: 'SIMULADO', total: snapshot.size, aNormalizar: planos.length, jaNormalizados },
        null,
        2,
      )}\n`,
    );
    exit(0);
  }

  let reconciliados = 0;
  for (const plano of planos) {
    await db.collection('autoridadesAdministrativas').doc(plano.id).update({
      papeis: plano.papeis,
      ativa: plano.ativa,
      papel: FieldValue.delete(),
      atualizadoEm: FieldValue.serverTimestamp(),
    });
    if (await reconciliarClaimAdministrativa(db, plano.id)) reconciliados += 1;
  }

  const pendentes = planos.length - reconciliados;
  stdout.write(
    `${JSON.stringify(
      {
        modo,
        status: pendentes > 0 ? 'CONCLUIDO_COM_PENDENCIAS' : 'CONCLUIDO',
        total: snapshot.size,
        normalizados: planos.length,
        jaNormalizados,
        reconciliados,
        pendentes,
      },
      null,
      2,
    )}\n`,
  );
  exit(0);
}

// Só executa quando invocado diretamente; importar o módulo (ex.: nos testes)
// expõe `planejarMigracao` sem disparar o IAM/ADC.
const invocadoDiretamente =
  argv[1] !== undefined && import.meta.url === pathToFileURL(argv[1]).href;
if (invocadoDiretamente) {
  principal().catch((erro) => {
    stderr.write(`${mensagemSegura(erro)}\n`);
    stderr.write(USO);
    exit(2);
  });
}

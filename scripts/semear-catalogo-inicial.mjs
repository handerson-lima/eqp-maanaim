#!/usr/bin/env node
// Seed operacional local do catálogo inicial (25 igrejas + 14 equipes do PRD).
// Usa ADC/emulador, valida a autoridade administrativa canônica na transação e
// nunca imprime nem persiste o UID do operador fora da chave da autoridade.
//
// Uso:
//   UID_ADMINISTRADOR=<uid> node scripts/semear-catalogo-inicial.mjs --dry-run
//   UID_ADMINISTRADOR=<uid> node scripts/semear-catalogo-inicial.mjs --executar \
//     [--command-id <id>] [--origem <texto>]
//
// Requer build prévio: npm run build --prefix functions

import { randomBytes } from 'node:crypto';
import { argv, env, exit, stdout, stderr } from 'node:process';
import { createRequire } from 'node:module';

const USO = `Uso:
  UID_ADMINISTRADOR=<uid> node scripts/semear-catalogo-inicial.mjs --dry-run
  UID_ADMINISTRADOR=<uid> node scripts/semear-catalogo-inicial.mjs --executar [opções]

Opções:
  --dry-run      valida a autoridade e conta o que seria criado, sem gravar
  --executar     aplica o seed (requer credenciais administrativas/emulador)
  --command-id   identificador opaco idempotente (16-128 caracteres)
  --origem       origem auditável (padrão: seed-inicial-do-sistema)

O UID_ADMINISTRADOR é usado somente como chave da autoridade canônica e nunca
aparece na saída. As dependências são resolvidas a partir de functions/node_modules.
`;

function lerArgumentos(args) {
  const opcoes = { modo: null, commandId: null, origem: null };
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
    } else {
      throw new Error('OPCAO_DESCONHECIDA');
    }
  }
  if (opcoes.modo === null) throw new Error('MODO_OBRIGATORIO');
  return opcoes;
}

function mensagemSegura(erro) {
  const codigo = erro && typeof erro === 'object' ? erro.code : null;
  if (typeof codigo === 'string' && /^[a-z0-9/_-]+$/i.test(codigo)) {
    return `Falha controlada (${codigo}).`;
  }
  return 'Falha controlada no seed do catálogo.';
}

function mapearExistente(doc) {
  const dados = doc.data() ?? {};
  return {
    id: doc.id,
    codigo: String(dados.codigo ?? ''),
    nome: String(dados.nome ?? ''),
    ativo: dados.ativo === true,
  };
}

async function principal() {
  const uid = env.UID_ADMINISTRADOR;
  if (!uid) {
    stderr.write(
      'Uso: UID_ADMINISTRADOR=<uid> node scripts/semear-catalogo-inicial.mjs --dry-run|--executar\n',
    );
    exit(2);
  }
  const opcoes = lerArgumentos(argv.slice(2));
  const commandId = opcoes.commandId ?? randomBytes(16).toString('hex');

  const requireFromFunctions = createRequire(
    new URL('../functions/package.json', import.meta.url),
  );
  const { getApps, getApp, initializeApp } = requireFromFunctions('firebase-admin/app');
  const { getFirestore } = requireFromFunctions('firebase-admin/firestore');
  const { podeAdministrar } = await import(
    '../functions/lib/domain/autoridadeAdministrativa.js'
  );
  const { semearCatalogo } = await import('../functions/lib/repositories/catalogo.js');
  const { igrejasAusentes, equipesAusentes } = await import(
    '../functions/lib/domain/catalogo.js'
  );
  const { DATASET_CATALOGO } = await import('../functions/lib/domain/seedCatalogo.js');
  const { ORIGEM_SEED_INICIAL } = await import(
    '../functions/lib/domain/importacaoPastores.js'
  );

  // Com ADC de usuário o Auth não infere o projeto; use GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.
  const projeto = env.GOOGLE_CLOUD_PROJECT ?? env.GCLOUD_PROJECT ?? null;
  const app = getApps().length ? getApp() : initializeApp(projeto ? { projectId: projeto } : undefined);
  const db = getFirestore(app);

  const ator = await db.collection('autoridadesAdministrativas').doc(uid).get();
  if (!podeAdministrar(ator.data())) {
    stdout.write(`${JSON.stringify({ status: 'SEM_AUTORIDADE' })}\n`);
    exit(1);
  }

  if (opcoes.modo === 'SIMULACAO') {
    const [igrejasSnap, equipesSnap] = await Promise.all([
      db.collection('igrejas').get(),
      db.collection('equipes').get(),
    ]);
    const igrejas = igrejasSnap.docs.map(mapearExistente);
    const equipes = equipesSnap.docs.map(mapearExistente);
    stdout.write(
      `${JSON.stringify(
        {
          modo: 'SIMULACAO',
          status: 'SIMULADO',
          datasetVersao: DATASET_CATALOGO.versao,
          igrejasCriadas: igrejasAusentes(DATASET_CATALOGO, igrejas).length,
          equipesCriadas: equipesAusentes(DATASET_CATALOGO, equipes).length,
          totalIgrejas: DATASET_CATALOGO.igrejas.length,
          totalEquipes: DATASET_CATALOGO.equipes.length,
        },
        null,
        2,
      )}\n`,
    );
    exit(0);
  }

  const resultado = await semearCatalogo(db, {
    commandId,
    correlacaoId: commandId,
    atorUid: uid,
    origem: opcoes.origem ?? ORIGEM_SEED_INICIAL,
    agora: new Date(),
  });
  stdout.write(
    `${JSON.stringify({ modo: 'EXECUCAO', status: 'CONCLUIDO', commandId, ...resultado }, null, 2)}\n`,
  );
  exit(0);
}

principal().catch((erro) => {
  stderr.write(`${mensagemSegura(erro)}\n`);
  stderr.write(USO);
  exit(2);
});

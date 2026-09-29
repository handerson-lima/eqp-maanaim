import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { importarPastoresIniciais } from '../src/domain/importacaoPastores.js';
import { criarPortasFirestore } from '../src/repositories/firestoreImportacao.js';

// Só exercita o Emulator quando ele está ativo (firebase emulators:exec).
const habilitado =
  Boolean(process.env.FIRESTORE_EMULATOR_HOST) &&
  Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);

const COMMAND_ID = 'e'.repeat(32);
const COLECOES = ['igrejas', 'pessoas', 'vinculosPastorIgreja', 'commands', 'auditOutbox'];

describe.skipIf(!habilitado)('carga inicial no Emulator', () => {
  let app: App;

  beforeAll(async () => {
    app = initializeApp({
      projectId: process.env.GCLOUD_PROJECT ?? 'demo-maanaim',
    });
    const db = getFirestore(app);
    await db.collection('igrejas').doc('ig-240001').set({
      codigo: '240001',
      nome: 'IGAPÓ',
      ativo: true,
    });
    await db.collection('igrejas').doc('ig-240002').set({
      codigo: '240002',
      nome: 'SANTARÉM',
      ativo: true,
    });
  });

  afterAll(async () => {
    if (!app) return;
    const db = getFirestore(app);
    for (const colecao of COLECOES) {
      await db.recursiveDelete(db.collection(colecao));
    }
    await deleteApp(app);
  });

  it('cria e reaproveita pessoas e vínculos; reexecução é idempotente', async () => {
    const db = getFirestore(app);
    const portas = criarPortasFirestore(db, getAuth(app));
    const entradas = [
      { codigoIgreja: '240001 - IGAPÓ', nomePastor: 'ANA DA SILVA', email: 'ana@example.com' },
      { codigoIgreja: '240002 - SANTARÉM', nomePastor: 'ANA DA SILVA', email: 'ana@example.com' },
      { codigoIgreja: '240003 - MIRASSOL', nomePastor: 'JOÃO COSTA', email: 'joao@example.com' },
    ];
    const requisicao = {
      commandId: COMMAND_ID,
      correlacaoId: COMMAND_ID,
      origem: 'seed-inicial-do-sistema',
      modo: 'EXECUCAO' as const,
      agora: new Date('2026-09-29T12:00:00.000Z'),
      entradas,
    };

    const primeiro = await importarPastoresIniciais(requisicao, portas);
    expect(primeiro.criados).toBe(2);
    expect(primeiro.recusados).toBe(1);
    const vinculos = await db.collection('vinculosPastorIgreja').get();
    expect(vinculos.size).toBe(2);
    // A vigência é carimbada pelo servidor, não pelo relógio do operador.
    for (const vinculo of vinculos.docs) {
      expect(vinculo.data().inicioVigencia).toBeDefined();
      expect(vinculo.data().inicioVigencia).not.toBeNull();
    }
    const pessoas = await db.collection('pessoas').get();
    expect(pessoas.size).toBe(1);

    const segundo = await importarPastoresIniciais(requisicao, portas);
    expect(segundo.criados).toBe(0);
    expect(segundo.jaVigentes).toBe(2);
    expect((await db.collection('vinculosPastorIgreja').get()).size).toBe(2);
  });

  it('recusa conflito de vínculo vigente sem substituir', async () => {
    const db = getFirestore(app);
    const portas = criarPortasFirestore(db, getAuth(app));
    const resultado = await importarPastoresIniciais(
      {
        commandId: 'f'.repeat(32),
        correlacaoId: 'f'.repeat(32),
        origem: 'seed-inicial-do-sistema',
        modo: 'EXECUCAO',
        agora: new Date('2026-09-29T12:00:00.000Z'),
        entradas: [
          { codigoIgreja: '240001 - IGAPÓ', nomePastor: 'OUTRO PASTOR', email: 'outro@example.com' },
        ],
      },
      portas,
    );
    expect(resultado.linhas[0]).toMatchObject({
      status: 'RECUSADO',
      motivo: 'CONFLITO_VINCULO',
    });
    const igreja = await db.collection('igrejas').doc('ig-240001').get();
    expect(igreja.data()?.pastorLocalVigentePessoaId).toBeDefined();
  });
});

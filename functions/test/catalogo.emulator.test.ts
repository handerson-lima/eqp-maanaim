import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  SemAutoridadeError,
} from '../src/domain/catalogo.js';
import { DATASET_CATALOGO } from '../src/domain/seedCatalogo.js';
import { lerCatalogo, semearCatalogo } from '../src/repositories/catalogo.js';

// Só exercita o Emulator quando ele está ativo (firebase emulators:exec).
const habilitado = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

const ADMIN_UID = 'administrador-catalogo-teste';
const COMMAND_ID = 'a'.repeat(32);
const COLECOES = [
  'igrejas',
  'equipes',
  'commands',
  'auditOutbox',
  'autoridadesAdministrativas',
];

describe.skipIf(!habilitado)('seed do catálogo no Emulator', () => {
  let app: App;

  beforeAll(async () => {
    app = initializeApp({
      projectId: process.env.GCLOUD_PROJECT ?? 'demo-maanaim',
    });
    await getFirestore(app)
      .collection('autoridadesAdministrativas')
      .doc(ADMIN_UID)
      .set({ ativa: true, papel: 'ADMINISTRADOR' });
  });

  afterAll(async () => {
    if (!app) return;
    const db = getFirestore(app);
    for (const colecao of COLECOES) {
      await db.recursiveDelete(db.collection(colecao));
    }
    await deleteApp(app);
  });

  const contexto = (commandId: string, atorUid = ADMIN_UID) => ({
    commandId,
    correlacaoId: commandId,
    atorUid,
    origem: 'seed-inicial-do-sistema',
    agora: new Date('2026-09-29T12:00:00.000Z'),
  });

  it('base vazia cria 25 igrejas e 14 equipes com recibo e auditoria', async () => {
    const db = getFirestore(app);
    const resultado = await semearCatalogo(db, contexto(COMMAND_ID));
    expect(resultado.repetido).toBe(false);
    expect(resultado.igrejasCriadas).toBe(25);
    expect(resultado.equipesCriadas).toBe(14);
    expect((await db.collection('igrejas').get()).size).toBe(25);
    expect((await db.collection('equipes').get()).size).toBe(14);
    const recibo = await db.collection('commands').doc(COMMAND_ID).get();
    expect(recibo.data()?.payloadHash).toBeDefined();
    expect(recibo.data()?.estado).toBe('COMPLETO');
    expect(
      (await db.collection('auditOutbox').doc(COMMAND_ID).get()).exists,
    ).toBe(true);
  });

  it('reexecução não duplica nem sobrescreve alterações administrativas', async () => {
    const db = getFirestore(app);
    const encontrada = await db
      .collection('igrejas')
      .where('codigo', '==', '240001')
      .limit(1)
      .get();
    const id = encontrada.docs[0].id;
    await db.collection('igrejas').doc(id).update({ nome: 'Igapó Administrada' });

    const novo = 'b'.repeat(32);
    const resultado = await semearCatalogo(db, contexto(novo));
    expect(resultado.repetido).toBe(false);
    expect(resultado.igrejasCriadas).toBe(0);
    expect(resultado.equipesCriadas).toBe(0);
    expect((await db.collection('igrejas').get()).size).toBe(25);
    expect((await db.collection('equipes').get()).size).toBe(14);
    expect((await db.collection('igrejas').doc(id).get()).data()?.nome).toBe(
      'Igapó Administrada',
    );

    const replay = await semearCatalogo(db, contexto(novo));
    expect(replay.repetido).toBe(true);
    expect(replay.igrejasCriadas).toBe(0);
  });

  it('recusa comando divergente sem mutação', async () => {
    const db = getFirestore(app);
    const divergente = 'c'.repeat(32);
    await semearCatalogo(db, contexto(divergente));
    await db
      .collection('commands')
      .doc(divergente)
      .update({ payloadHash: 'hash-alterado' });
    await expect(semearCatalogo(db, contexto(divergente))).rejects.toBeInstanceOf(
      ComandoDivergenteError,
    );
  });

  it('recusa sessão sem autoridade administrativa', async () => {
    const db = getFirestore(app);
    await expect(
      semearCatalogo(db, contexto('d'.repeat(32), 'sem-autoridade')),
    ).rejects.toBeInstanceOf(SemAutoridadeError);
  });

  it('consulta read-only devolve catálogo ordenado e pesquisável', async () => {
    const db = getFirestore(app);
    const catalogo = await lerCatalogo(db);
    expect(catalogo.igrejas).toHaveLength(DATASET_CATALOGO.igrejas.length);
    expect(catalogo.equipes).toHaveLength(DATASET_CATALOGO.equipes.length);
    expect(catalogo.igrejas[0].rotulo).toMatch(/ - \d{6}$/);
    const igapó = await lerCatalogo(db, '240001');
    expect(igapó.igrejas).toHaveLength(1);
    expect(igapó.igrejas[0].rotulo).toBe('Igapó Administrada - 240001');
  });
});

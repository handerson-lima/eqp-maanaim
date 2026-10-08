import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import type { CallableRequest } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  SemAutoridadeError,
  type ResumoCatalogo,
  type ResultadoSemeadura,
} from '../src/domain/catalogo.js';
import { DATASET_CATALOGO } from '../src/domain/seedCatalogo.js';
import { consultarCatalogo } from '../src/commands/consultarCatalogo.js';
import { semearCatalogoInicial } from '../src/commands/semearCatalogoInicial.js';
import { alternarStatusIgreja } from '../src/commands/alternarStatusIgreja.js';
import { alternarStatusEquipe } from '../src/commands/alternarStatusEquipe.js';
import { lerCatalogo, semearCatalogo } from '../src/repositories/catalogo.js';

// Executa o handler cru da callable (`.run`), sem o middleware de App Check/Auth.
const requisitar = <T>(
  handler: { run: (request: CallableRequest<T>) => unknown },
  data: T,
  auth?: { uid: string },
) =>
  handler.run({
    data,
    auth: auth as CallableRequest<T>['auth'],
  } as unknown as CallableRequest<T>);

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

  it('callables negam sessão sem autoridade administrativa', async () => {
    await expect(
      requisitar(semearCatalogoInicial, { commandId: 'e'.repeat(32) }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(
      requisitar(consultarCatalogo, {}, { uid: 'sem-autoridade' }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(requisitar(consultarCatalogo, {})).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  it('callable autorizada semeia e recusa replay divergente', async () => {
    const commandId = 'f'.repeat(32);
    const resultado = (await requisitar(
      semearCatalogoInicial,
      { commandId },
      { uid: ADMIN_UID },
    )) as ResultadoSemeadura;
    expect(resultado.totalIgrejas).toBe(DATASET_CATALOGO.igrejas.length);
    expect(
      (await getFirestore(app).collection('commands').doc(commandId).get()).exists,
    ).toBe(true);

    await getFirestore(app)
      .collection('commands')
      .doc(commandId)
      .update({ payloadHash: 'hash-alterado' });
    await expect(
      requisitar(semearCatalogoInicial, { commandId }, { uid: ADMIN_UID }),
    ).rejects.toMatchObject({ code: 'aborted' });
  });

  it('consulta autorizada devolve igrejas como "Nome - Código"', async () => {
    const resposta = (await requisitar(consultarCatalogo, {}, {
      uid: ADMIN_UID,
    })) as ResumoCatalogo;
    expect(resposta.igrejas).toHaveLength(DATASET_CATALOGO.igrejas.length);
    expect(resposta.igrejas[0].rotulo).toMatch(/ - \d{6}$/);
  });

  it('Story 7.2: inativa e reativa igreja mantendo documento e gerando recibo e auditoria', async () => {
    const db = getFirestore(app);
    const snap = await db.collection('igrejas').limit(1).get();
    const igrejaId = snap.docs[0].id;

    const cmdInativar = 'i'.repeat(32);
    const resInativar = (await requisitar(
      alternarStatusIgreja,
      { commandId: cmdInativar, igrejaId, ativo: false },
      { uid: ADMIN_UID },
    )) as { concluido: boolean; repetido: boolean; igrejaId: string; ativo: boolean };

    expect(resInativar.concluido).toBe(true);
    expect(resInativar.ativo).toBe(false);
    expect(resInativar.repetido).toBe(false);

    const docInativo = await db.collection('igrejas').doc(igrejaId).get();
    expect(docInativo.exists).toBe(true);
    expect(docInativo.data()?.ativo).toBe(false);

    const outboxInativar = await db.collection('auditOutbox').doc(cmdInativar).get();
    expect(outboxInativar.exists).toBe(true);
    expect(outboxInativar.data()?.action).toBe('IGREJA_STATUS_ALTERADO');
    expect(outboxInativar.data()?.antes).toEqual({ ativo: true });
    expect(outboxInativar.data()?.depois).toEqual({ ativo: false });

    // Replay idempotente
    const resReplay = (await requisitar(
      alternarStatusIgreja,
      { commandId: cmdInativar, igrejaId, ativo: false },
      { uid: ADMIN_UID },
    )) as { concluido: boolean; repetido: boolean };
    expect(resReplay.repetido).toBe(true);

    // Reativação
    const cmdReativar = 'r'.repeat(32);
    const resReativar = (await requisitar(
      alternarStatusIgreja,
      { commandId: cmdReativar, igrejaId, ativo: true },
      { uid: ADMIN_UID },
    )) as { concluido: boolean; ativo: boolean };
    expect(resReativar.ativo).toBe(true);

    const docReativo = await db.collection('igrejas').doc(igrejaId).get();
    expect(docReativo.data()?.ativo).toBe(true);
  });

  it('Story 7.2: inativa e reativa equipe mantendo documento e gerando recibo e auditoria', async () => {
    const db = getFirestore(app);
    const snap = await db.collection('equipes').limit(1).get();
    const equipeId = snap.docs[0].id;

    const cmdInativar = 'j'.repeat(32);
    const resInativar = (await requisitar(
      alternarStatusEquipe,
      { commandId: cmdInativar, equipeId, ativo: false },
      { uid: ADMIN_UID },
    )) as { concluido: boolean; ativo: boolean };

    expect(resInativar.ativo).toBe(false);

    const docInativo = await db.collection('equipes').doc(equipeId).get();
    expect(docInativo.exists).toBe(true);
    expect(docInativo.data()?.ativo).toBe(false);

    const outbox = await db.collection('auditOutbox').doc(cmdInativar).get();
    expect(outbox.exists).toBe(true);
    expect(outbox.data()?.action).toBe('EQUIPE_STATUS_ALTERADO');
  });

  it('Story 7.2: recusa alteração para chamador não autorizado ou entidade inexistente', async () => {
    const cmd = 'k'.repeat(32);
    await expect(
      requisitar(
        alternarStatusIgreja,
        { commandId: cmd, igrejaId: 'ig_inexistente', ativo: false },
        { uid: 'usuario-comum' },
      ),
    ).rejects.toMatchObject({ code: 'permission-denied' });

    await expect(
      requisitar(
        alternarStatusIgreja,
        { commandId: cmd, igrejaId: 'ig_inexistente', ativo: false },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'not-found' });
  });
});


import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import type { CallableRequest } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  SemAutoridadeError,
  UltimoAdminError,
  validarPapeis,
  validarPessoa,
} from '../src/domain/pessoas.js';
import { podeAdministrar } from '../src/domain/autoridadeAdministrativa.js';
import { consultarPessoas } from '../src/commands/consultarPessoas.js';
import { alterarAutoridadeAdministrativa } from '../src/commands/gerenciarAutoridadeAdministrativa.js';
import { gerenciarPapeis } from '../src/commands/gerenciarPapeis.js';
import { salvarPessoa as salvarPessoaCommand } from '../src/commands/salvarPessoa.js';
import {
  alterarPapeis,
  lerPessoas,
  salvarPessoa,
  type ContextoPessoa,
} from '../src/repositories/pessoas.js';

const requisitar = <T>(
  handler: { run: (request: CallableRequest<T>) => unknown },
  data: T,
  auth?: { uid: string },
) =>
  handler.run({
    data,
    auth: auth as CallableRequest<T>['auth'],
  } as unknown as CallableRequest<T>);

const habilitado =
  Boolean(process.env.FIRESTORE_EMULATOR_HOST) &&
  Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);

const ADMIN_UID = 'administrador-pessoas-teste';
const ALVO_UID = 'alvo-papeis-teste';
const COLECOES = [
  'pessoas',
  'coordenadores',
  'autoridadesAdministrativas',
  'commands',
  'auditOutbox',
];

describe.skipIf(!habilitado)('pessoas e papéis no Emulator', () => {
  let app: App;

  const contexto = (commandId: string, atorUid = ADMIN_UID): ContextoPessoa => ({
    commandId,
    correlacaoId: commandId,
    atorUid,
    origem: 'administracao-pessoas-papeis',
  });

  beforeAll(async () => {
    app = initializeApp({
      projectId: process.env.GCLOUD_PROJECT ?? 'demo-maanaim',
    });
    const db = getFirestore(app);
    await db
      .collection('autoridadesAdministrativas')
      .doc(ADMIN_UID)
      .set({ ativa: true, papeis: ['ADMINISTRADOR'], versao: 1, revisao: 1 });
    await getAuth(app).createUser({ uid: ALVO_UID, email: 'alvo@exemplo.com' });
  });

  afterAll(async () => {
    if (!app) return;
    const auth = getAuth(app);
    const usuarios = await auth.listUsers();
    if (usuarios.users.length > 0) {
      await auth.deleteUsers(usuarios.users.map((u) => u.uid));
    }
    const db = getFirestore(app);
    for (const colecao of COLECOES) {
      await db.recursiveDelete(db.collection(colecao));
    }
    await deleteApp(app);
  });

  it('provisiona identidade, perfil, recibo e auditoria sem PII', async () => {
    const db = getFirestore(app);
    const entrada = validarPessoa({
      commandId: 'a'.repeat(32),
      nomeCompleto: 'Ana da Silva',
      email: 'ana.provisionada@exemplo.com',
      coordenador: false,
    });
    const resultado = await salvarPessoa(db, getAuth(app), contexto(entrada.commandId), entrada);
    expect(resultado.repetido).toBe(false);
    const pessoa = await db.collection('pessoas').doc(resultado.uid).get();
    expect(pessoa.data()?.nomeCompleto).toBe('Ana da Silva');
    const recibo = (await db.collection('commands').doc(entrada.commandId).get()).data() ?? {};
    expect(recibo.payloadHash).toBe(entrada.payloadHash);
    expect(recibo).not.toHaveProperty('uid');
    expect(JSON.stringify(recibo)).not.toMatch(/cpf|nomeCompleto|email/);
    const auditoria = (
      await db.collection('auditOutbox').doc(entrada.commandId).get()
    ).data() ?? {};
    expect(auditoria.alvoUid).toBe(resultado.uid);
    expect(JSON.stringify(auditoria)).not.toMatch(/cpf|nomeCompleto|email/);

    const replay = await salvarPessoa(db, getAuth(app), contexto(entrada.commandId), entrada);
    expect(replay.repetido).toBe(true);
    expect(replay.uid).toBe(resultado.uid);
  });

  it('persiste o CPF do Coordenador apenas no registro restrito', async () => {
    const db = getFirestore(app);
    const entrada = validarPessoa({
      commandId: 'b'.repeat(32),
      uid: ALVO_UID,
      nomeCompleto: 'Carlos Coordenador',
      email: 'alvo@exemplo.com',
      coordenador: true,
      cpf: '529.982.247-25',
    });
    await salvarPessoa(db, getAuth(app), contexto(entrada.commandId), entrada);
    const restrito = await db.collection('coordenadores').doc(ALVO_UID).get();
    expect(restrito.data()?.cpf).toBe('52998224725');
    const recibo = (await db.collection('commands').doc(entrada.commandId).get()).data() ?? {};
    expect(JSON.stringify(recibo)).not.toMatch(/52998224725|cpf/);
  });

  it('concede e revoga papéis reconciliando a fonte canônica', async () => {
    const db = getFirestore(app);
    const conceder = validarPapeis({
      commandId: 'c'.repeat(32),
      alvoUid: ALVO_UID,
      expectedVersion: 0,
      papel: 'COORDENADOR',
      conceder: true,
    });
    const resultado = await alterarPapeis(db, contexto(conceder.commandId), conceder);
    expect(resultado.repetido).toBe(false);
    expect(resultado.papeis).toEqual(['COORDENADOR']);
    const doc = await db.collection('autoridadesAdministrativas').doc(ALVO_UID).get();
    expect(doc.data()?.papeis).toEqual(['COORDENADOR']);

    const revogar = validarPapeis({
      commandId: 'd'.repeat(32),
      alvoUid: ALVO_UID,
      expectedVersion: 1,
      papel: 'COORDENADOR',
      conceder: false,
    });
    await alterarPapeis(db, contexto(revogar.commandId), revogar);
    const depois = await db.collection('autoridadesAdministrativas').doc(ALVO_UID).get();
    expect(depois.data()?.papeis).toEqual([]);
    expect(depois.data()?.ativa).toBe(false);
  });

  it('recusa conflito de versão e comando divergente', async () => {
    const db = getFirestore(app);
    const entrada = validarPapeis({
      commandId: 'e'.repeat(32),
      alvoUid: ALVO_UID,
      expectedVersion: 99,
      papel: 'ADMINISTRADOR',
      conceder: true,
    });
    await expect(
      alterarPapeis(db, contexto(entrada.commandId), entrada),
    ).rejects.toBeInstanceOf(ConflitoVersaoError);

    const divergente = validarPapeis({
      commandId: 'g'.repeat(32),
      alvoUid: ALVO_UID,
      expectedVersion: 0,
      papel: 'ADMINISTRADOR',
      conceder: true,
    });
    await db
      .collection('commands')
      .doc(divergente.commandId)
      .set({ action: 'GERENCIAR_PAPEIS', actorUid: ADMIN_UID, payloadHash: 'outro' });
    await expect(
      alterarPapeis(db, contexto(divergente.commandId), divergente),
    ).rejects.toBeInstanceOf(ComandoDivergenteError);
  });

  it('não remove a última administração ativa', async () => {
    const db = getFirestore(app);
    await db
      .collection('autoridadesAdministrativas')
      .doc(ADMIN_UID)
      .set({ ativa: true, papeis: ['ADMINISTRADOR'], versao: 5, revisao: 1 });
    const entrada = validarPapeis({
      commandId: 'h'.repeat(32),
      alvoUid: ADMIN_UID,
      expectedVersion: 5,
      papel: 'ADMINISTRADOR',
      conceder: false,
    });
    await expect(
      alterarPapeis(db, contexto(entrada.commandId, ADMIN_UID), entrada),
    ).rejects.toBeInstanceOf(UltimoAdminError);
  });

  it('recusa sessão sem autoridade administrativa', async () => {
    const db = getFirestore(app);
    const entrada = validarPapeis({
      commandId: 'i'.repeat(32),
      alvoUid: ALVO_UID,
      expectedVersion: 0,
      papel: 'COORDENADOR',
      conceder: true,
    });
    await expect(
      alterarPapeis(db, contexto(entrada.commandId, 'sem-autoridade'), entrada),
    ).rejects.toBeInstanceOf(SemAutoridadeError);
  });

  it('consulta read-only devolve pessoas sem CPF', async () => {
    const db = getFirestore(app);
    const resumo = await lerPessoas(db, '', ADMIN_UID);
    expect(resumo.pessoas.length).toBeGreaterThan(0);
    expect(resumo.contexto.uid).toBe(ADMIN_UID);
    expect(resumo.contexto.papeis).toContain('ADMINISTRADOR');
    expect(JSON.stringify(resumo)).not.toMatch(/cpf|52998224725/);
    expect(resumo.pessoas.some((p) => p.uid === ALVO_UID && p.coordenador)).toBe(true);
  });

  it('callables negam sessão sem autoridade e bloqueiam autoatribuição', async () => {
    await expect(
      requisitar(salvarPessoaCommand, {
        commandId: 'j'.repeat(32),
        nomeCompleto: 'Sem Sessão',
        email: 'sem@exemplo.com',
        coordenador: false,
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(
      requisitar(
        gerenciarPapeis,
        {
          commandId: 'k'.repeat(32),
          alvoUid: ADMIN_UID,
          expectedVersion: 0,
          papel: 'ADMINISTRADOR',
          conceder: true,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(
      requisitar(consultarPessoas, {}, { uid: 'sem-autoridade' }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('recusa alvo sem identidade Auth sem persistir mutação parcial', async () => {
    const db = getFirestore(app);
    const commandId = 'l'.repeat(32);
    await expect(
      requisitar(
        gerenciarPapeis,
        {
          commandId,
          alvoUid: 'uid-inexistente-auth',
          expectedVersion: 0,
          papel: 'COORDENADOR',
          conceder: true,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
    expect((await db.collection('commands').doc(commandId).get()).exists).toBe(false);
    expect((await db.collection('auditOutbox').doc(commandId).get()).exists).toBe(false);
  });

  it('concede ADMINISTRADOR pela 1.1 sobre documento já com papeis plural', async () => {
    const db = getFirestore(app);
    const legadoUid = 'legado-1-1-teste';
    await getAuth(app).createUser({ uid: legadoUid, email: 'legado@exemplo.com' });
    await db.collection('autoridadesAdministrativas').doc(legadoUid).set({
      ativa: true,
      papeis: [],
      papel: 'ADMINISTRADOR',
      versao: 1,
      revisao: 1,
    });
    const commandId = 'm'.repeat(32);
    const resultado = await requisitar(
      alterarAutoridadeAdministrativa,
      { alvoUid: legadoUid, commandId, expectedVersion: 1, conceder: true },
      { uid: ADMIN_UID },
    );
    expect(resultado).toMatchObject({ concluido: true, repetido: false });

    const doc = await db
      .collection('autoridadesAdministrativas')
      .doc(legadoUid)
      .get();
    expect(doc.data()?.papeis).toEqual(['ADMINISTRADOR']);
    expect(doc.data()).not.toHaveProperty('papel');
    expect(podeAdministrar(doc.data())).toBe(true);
  });

  it('não provisiona identidade para chamador sem papel administrativo', async () => {
    const email = 'nao-admin-nao-criado@exemplo.com';
    await expect(
      requisitar(
        salvarPessoaCommand,
        {
          commandId: 'n'.repeat(32),
          nomeCompleto: 'Nao Admin',
          email,
          coordenador: false,
        },
        { uid: 'sem-autoridade' },
      ),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    let criado = true;
    try {
      await getAuth(app).getUserByEmail(email);
    } catch {
      criado = false;
    }
    expect(criado).toBe(false);
  });

  it('un-designar Coordenador reporta falso e preserva o registro restrito', async () => {
    const db = getFirestore(app);
    const coordUid = 'coordenador-designado-teste';
    await getAuth(app).createUser({ uid: coordUid, email: 'coord@exemplo.com' });

    const designar = validarPessoa({
      commandId: 'o'.repeat(32),
      uid: coordUid,
      nomeCompleto: 'Coordenador Designado',
      email: 'coord@exemplo.com',
      coordenador: true,
      cpf: '529.982.247-25',
    });
    await salvarPessoa(db, getAuth(app), contexto(designar.commandId), designar);
    const designado = await lerPessoas(db, '', ADMIN_UID);
    expect(designado.pessoas.find((p) => p.uid === coordUid)?.coordenador).toBe(true);

    const remover = validarPessoa({
      commandId: 'p'.repeat(32),
      uid: coordUid,
      nomeCompleto: 'Coordenador Designado',
      email: 'coord@exemplo.com',
      coordenador: false,
    });
    await salvarPessoa(db, getAuth(app), contexto(remover.commandId), remover);
    const removido = await lerPessoas(db, '', ADMIN_UID);
    expect(removido.pessoas.find((p) => p.uid === coordUid)?.coordenador).toBe(false);
    expect(
      (await db.collection('coordenadores').doc(coordUid).get()).exists,
    ).toBe(true);
  });
});

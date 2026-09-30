import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import type { CallableRequest } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  EntidadeInexistenteError,
  PessoaInexistenteError,
  SemAutoridadeError,
  SobreposicaoError,
  VigenteExistenteError,
  VinculoInexistenteError,
  dataEfetivaEmMs,
  validarVinculo,
  type EntradaVinculo,
} from '../src/domain/vinculos.js';
import { consultarVinculos } from '../src/commands/consultarVinculos.js';
import { gerenciarVinculo as gerenciarVinculoCommand } from '../src/commands/gerenciarVinculo.js';
import {
  gerenciarVinculo,
  lerVinculos,
  type ContextoVinculo,
} from '../src/repositories/vinculos.js';

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

const ADMIN_UID = 'administrador-vinculos-teste';
const IGREJA_ID = 'ig-vinculos-teste';
const EQUIPE_ID = 'eq-vinculos-teste';
const PESSOA_A = 'pessoa-vinculos-a';
const PESSOA_B = 'pessoa-vinculos-b';
const PESSOA_LEGADA = 'pessoa-vinculos-legada';
const COLECOES = [
  'igrejas',
  'equipes',
  'pessoas',
  'vinculosPastorIgreja',
  'vinculosPastorEquipe',
  'commands',
  'auditOutbox',
  'autoridadesAdministrativas',
];

const DIA = 86_400_000;

function dataStr(offsetDias: number): string {
  const agora = new Date();
  const base = Date.UTC(
    agora.getUTCFullYear(),
    agora.getUTCMonth(),
    agora.getUTCDate(),
  );
  return new Date(base + offsetDias * DIA).toISOString().slice(0, 10);
}

const PASSADO_10 = dataStr(-10);
const PASSADO_5 = dataStr(-5);
const HOJE = dataStr(0);
const PASSADO_10_MS = dataEfetivaEmMs(PASSADO_10) as number;

describe.skipIf(!habilitado)('vínculos de responsabilidade no Emulator', () => {
  let app: App;

  const contexto = (
    commandId: string,
    atorUid = ADMIN_UID,
    agoraMs = Date.now(),
  ): ContextoVinculo => ({
    commandId,
    correlacaoId: commandId,
    atorUid,
    origem: 'administracao-vinculos-responsaveis',
    agoraMs,
  });

  const igreja = (
    commandId: string,
    extra: Record<string, unknown>,
  ): EntradaVinculo =>
    validarVinculo({
      commandId,
      tipoEntidade: 'IGREJA',
      entidadeId: IGREJA_ID,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_A,
      dataEfetiva: PASSADO_10,
      expectedVersion: 0,
      ...extra,
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
    await db.collection('igrejas').doc(IGREJA_ID).set({
      codigo: '240001',
      nome: 'Igreja Teste',
      ativo: true,
    });
    await db.collection('equipes').doc(EQUIPE_ID).set({
      nome: 'Equipe Teste',
      ativo: true,
    });
    await db.collection('pessoas').doc(ADMIN_UID).set({
      uid: ADMIN_UID,
      nomeCompleto: 'Administrador Vinculos',
      email: 'admin@exemplo.com',
    });
    for (const [id, email] of [
      [PESSOA_A, 'a@exemplo.com'],
      [PESSOA_B, 'b@exemplo.com'],
      [PESSOA_LEGADA, 'legada@exemplo.com'],
    ] as const) {
      await db.collection('pessoas').doc(id).set({
        uid: id,
        nomeCompleto: `Pessoa ${id}`,
        email,
      });
    }
  });

  afterAll(async () => {
    if (!app) return;
    const db = getFirestore(app);
    for (const colecao of COLECOES) {
      await db.recursiveDelete(db.collection(colecao));
    }
    await deleteApp(app);
  });

  it('atribui Pastor Local gravando vínculo, par, versão, recibo e auditoria sem PII', async () => {
    const db = getFirestore(app);
    const entrada = igreja('a'.repeat(32), {});
    const resultado = await gerenciarVinculo(db, contexto(entrada.commandId), entrada);
    expect(resultado.repetido).toBe(false);
    expect(resultado.pessoaId).toBe(PESSOA_A);
    expect(resultado.versaoVinculo).toBe(1);

    const entidade = await db.collection('igrejas').doc(IGREJA_ID).get();
    expect(entidade.data()?.pastorLocalVigentePessoaId).toBe(PESSOA_A);
    expect(entidade.data()?.pastorLocalVigenteVinculoId).toBe(resultado.vinculoId);
    expect(entidade.data()?.versaoVinculo).toBe(1);

    const vinculo = await db
      .collection('vinculosPastorIgreja')
      .doc(resultado.vinculoId as string)
      .get();
    expect(vinculo.data()?.estado).toBe('VIGENTE');
    expect(vinculo.data()?.papel).toBe('PASTOR_LOCAL');
    expect(vinculo.data()?.fimVigencia).toBeNull();

    const recibo = (await db.collection('commands').doc(entrada.commandId).get()).data() ?? {};
    expect(recibo.payloadHash).toBe(entrada.payloadHash);
    expect(recibo.estado).toBe('COMPLETO');
    const auditoria = (await db.collection('auditOutbox').doc(entrada.commandId).get()).data() ?? {};
    expect(auditoria.action).toBe('VINCULO_ATRIBUIDO');
    expect(JSON.stringify(recibo)).not.toMatch(/nomeCompleto|email|cpf/);
    expect(JSON.stringify(auditoria)).not.toMatch(/nomeCompleto|email|cpf/);

    const replay = await gerenciarVinculo(db, contexto(entrada.commandId), entrada);
    expect(replay.repetido).toBe(true);
    expect(replay.vinculoId).toBe(resultado.vinculoId);
    expect(
      (await db.collection('vinculosPastorIgreja').get()).size,
    ).toBe(1);
  });

  it('recusa uma segunda atribuição quando já há vigente', async () => {
    const db = getFirestore(app);
    const entrada = igreja('b'.repeat(32), { pessoaId: PESSOA_B, expectedVersion: 1 });
    await expect(
      gerenciarVinculo(db, contexto(entrada.commandId), entrada),
    ).rejects.toBeInstanceOf(VigenteExistenteError);
  });

  it('substitui encerrando o anterior e abrindo o novo sem sobreposição', async () => {
    const db = getFirestore(app);
    const entrada = igreja('c'.repeat(32), {
      acao: 'SUBSTITUIR',
      pessoaId: PESSOA_B,
      dataEfetiva: PASSADO_5,
      expectedVersion: 1,
    });
    const resultado = await gerenciarVinculo(db, contexto(entrada.commandId), entrada);
    expect(resultado.repetido).toBe(false);
    expect(resultado.versaoVinculo).toBe(2);

    const entidade = await db.collection('igrejas').doc(IGREJA_ID).get();
    expect(entidade.data()?.pastorLocalVigentePessoaId).toBe(PESSOA_B);
    expect(entidade.data()?.versaoVinculo).toBe(2);

    const vigentes = await db
      .collection('vinculosPastorIgreja')
      .where('entidadeId', '==', IGREJA_ID)
      .where('estado', '==', 'VIGENTE')
      .get();
    expect(vigentes.size).toBe(1);
    expect(vigentes.docs[0].data().pessoaId).toBe(PESSOA_B);

    const encerrados = await db
      .collection('vinculosPastorIgreja')
      .where('estado', '==', 'ENCERRADO')
      .get();
    expect(encerrados.size).toBe(1);
    expect(encerrados.docs[0].data().pessoaId).toBe(PESSOA_A);
    expect(encerrados.docs[0].data().fimVigencia.toMillis()).toBe(
      Date.UTC(
        new Date(PASSADO_5).getUTCFullYear(),
        new Date(PASSADO_5).getUTCMonth(),
        new Date(PASSADO_5).getUTCDate(),
      ),
    );
  });

  it('encerra o vínculo deixando a entidade sem responsável e preservando histórico', async () => {
    const db = getFirestore(app);
    const entrada = igreja('d'.repeat(32), {
      acao: 'ENCERRAR',
      pessoaId: undefined,
      dataEfetiva: HOJE,
      expectedVersion: 2,
    });
    const resultado = await gerenciarVinculo(db, contexto(entrada.commandId), entrada);
    expect(resultado.pessoaId).toBeNull();

    const entidade = await db.collection('igrejas').doc(IGREJA_ID).get();
    expect(entidade.data()?.pastorLocalVigentePessoaId).toBeUndefined();
    expect(entidade.data()?.pastorLocalVigenteVinculoId).toBeUndefined();
    expect(entidade.data()?.versaoVinculo).toBe(3);

    const encerrados = await db
      .collection('vinculosPastorIgreja')
      .where('estado', '==', 'ENCERRADO')
      .get();
    expect(encerrados.size).toBe(2);
  });

  it('recusa encerrar quando não há vínculo vigente', async () => {
    const db = getFirestore(app);
    const entrada = igreja('e'.repeat(32), {
      acao: 'ENCERRAR',
      pessoaId: undefined,
      dataEfetiva: HOJE,
      expectedVersion: 3,
    });
    await expect(
      gerenciarVinculo(db, contexto(entrada.commandId), entrada),
    ).rejects.toBeInstanceOf(VinculoInexistenteError);
  });

  it('recusa data futura e retroatividade que encerre antes do início', async () => {
    const db = getFirestore(app);
    const futuro = igreja('f'.repeat(32), {
      dataEfetiva: dataStr(5),
      expectedVersion: 3,
    });
    await expect(
      gerenciarVinculo(db, contexto(futuro.commandId), futuro),
    ).rejects.toMatchObject({ name: 'DataInvalidaError' });

    const dbRef = db.collection('equipes').doc(EQUIPE_ID);
    await dbRef.set(
      { responsavelVigentePessoaId: PESSOA_A, versaoVinculo: 1 },
      { merge: true },
    );
    const vigente = await db.collection('vinculosPastorEquipe').add({
      entidadeId: EQUIPE_ID,
      tipoEntidade: 'EQUIPE',
      pessoaId: PESSOA_A,
      papel: 'PASTOR_EQUIPE',
      estado: 'VIGENTE',
      inicioVigencia: Timestamp.fromMillis(dataEfetivaEmMs(HOJE) as number),
      fimVigencia: null,
      atorUid: ADMIN_UID,
    });
    await dbRef.update({ responsavelVigenteVinculoId: vigente.id });
    const retroativo = validarVinculo({
      commandId: 'g'.repeat(32),
      tipoEntidade: 'EQUIPE',
      entidadeId: EQUIPE_ID,
      acao: 'ENCERRAR',
      pessoaId: undefined,
      dataEfetiva: PASSADO_10,
      expectedVersion: 1,
    });
    await expect(
      gerenciarVinculo(db, contexto(retroativo.commandId), retroativo),
    ).rejects.toBeInstanceOf(SobreposicaoError);
  });

  it('concede responsável à equipe e mantém exatamente um vigente', async () => {
    const db = getFirestore(app);
    const encerrar = validarVinculo({
      commandId: 'h'.repeat(32),
      tipoEntidade: 'EQUIPE',
      entidadeId: EQUIPE_ID,
      acao: 'ENCERRAR',
      pessoaId: undefined,
      dataEfetiva: HOJE,
      expectedVersion: 1,
    });
    await gerenciarVinculo(db, contexto(encerrar.commandId), encerrar);
    const atribuir = validarVinculo({
      commandId: 'i'.repeat(32),
      tipoEntidade: 'EQUIPE',
      entidadeId: EQUIPE_ID,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_B,
      dataEfetiva: PASSADO_5,
      expectedVersion: 2,
    });
    const resultado = await gerenciarVinculo(db, contexto(atribuir.commandId), atribuir);
    expect(resultado.versaoVinculo).toBe(3);
    const equipe = await db.collection('equipes').doc(EQUIPE_ID).get();
    expect(equipe.data()?.responsavelVigentePessoaId).toBe(PESSOA_B);
    const vigentes = await db
      .collection('vinculosPastorEquipe')
      .where('entidadeId', '==', EQUIPE_ID)
      .where('estado', '==', 'VIGENTE')
      .get();
    expect(vigentes.size).toBe(1);
  });

  it('lê vínculo legado da importação como vigente e permite substituição', async () => {
    const db = getFirestore(app);
    const legadoRef = db.collection('vinculosPastorIgreja').doc('v-legado-importacao');
    // Schema real da carga inicial: `igrejaId` (sem `entidadeId`/`tipoEntidade`).
    await legadoRef.set({
      pessoaId: PESSOA_LEGADA,
      igrejaId: IGREJA_ID,
      codigoIgreja: '240001',
      papel: 'PASTOR_LOCAL',
      estado: 'VIGENTE',
      inicioVigencia: Timestamp.fromMillis(PASSADO_10_MS),
      fimVigencia: null,
      origem: 'seed-inicial-do-sistema',
      commandId: 'seed-legado'.padEnd(32, '0'),
      correlationId: 'seed-legado'.padEnd(32, '0'),
      criadoEm: FieldValue.serverTimestamp(),
    });
    await db.collection('igrejas').doc(IGREJA_ID).set(
      {
        pastorLocalVigentePessoaId: PESSOA_LEGADA,
        pastorLocalVigenteVinculoId: 'v-legado-importacao',
        versaoVinculo: 0,
      },
      { merge: true },
    );
    const resumo = await lerVinculos(db);
    const igrejaResumo = resumo.igrejas.find((i) => i.id === IGREJA_ID);
    expect(igrejaResumo?.responsavel?.pessoaId).toBe(PESSOA_LEGADA);
    const legadoNoHistorico = igrejaResumo?.historico.find(
      (evento) =>
        evento.atorUid === '' &&
        evento.inicioVigencia === new Date(PASSADO_10_MS).toISOString(),
    );
    expect(legadoNoHistorico?.estado).toBe('VIGENTE');
    expect(legadoNoHistorico?.acao).toBe('ATRIBUIR');

    const substituir = validarVinculo({
      commandId: 'j'.repeat(32),
      tipoEntidade: 'IGREJA',
      entidadeId: IGREJA_ID,
      acao: 'SUBSTITUIR',
      pessoaId: PESSOA_A,
      dataEfetiva: PASSADO_5,
      expectedVersion: 0,
    });
    await gerenciarVinculo(db, contexto(substituir.commandId), substituir);
    const legado = await legadoRef.get();
    expect(legado.data()?.estado).toBe('ENCERRADO');
    const vigentes = await db
      .collection('vinculosPastorIgreja')
      .where('entidadeId', '==', IGREJA_ID)
      .where('estado', '==', 'VIGENTE')
      .get();
    expect(vigentes.size).toBe(1);
    expect(vigentes.docs[0].data().pessoaId).toBe(PESSOA_A);
  });

  it('recusa conflito de versão, comando divergente, entidade e pessoa inexistentes', async () => {
    const db = getFirestore(app);
    const base = validarVinculo({
      commandId: 'k'.repeat(32),
      tipoEntidade: 'IGREJA',
      entidadeId: IGREJA_ID,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_B,
      dataEfetiva: PASSADO_5,
      expectedVersion: 0,
    });
    await expect(
      gerenciarVinculo(db, contexto(base.commandId), base),
    ).rejects.toBeInstanceOf(ConflitoVersaoError);

    const divergente = validarVinculo({
      commandId: 'l'.repeat(32),
      tipoEntidade: 'IGREJA',
      entidadeId: IGREJA_ID,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_B,
      dataEfetiva: PASSADO_5,
      expectedVersion: 1,
    });
    await db.collection('commands').doc(divergente.commandId).set({
      action: 'GERENCIAR_VINCULO',
      actorUid: ADMIN_UID,
      payloadHash: 'outro',
    });
    await expect(
      gerenciarVinculo(db, contexto(divergente.commandId), divergente),
    ).rejects.toBeInstanceOf(ComandoDivergenteError);

    const inativa = validarVinculo({
      commandId: 'm'.repeat(32),
      tipoEntidade: 'IGREJA',
      entidadeId: 'ig-inexistente',
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_B,
      dataEfetiva: PASSADO_5,
      expectedVersion: 0,
    });
    await expect(
      gerenciarVinculo(db, contexto(inativa.commandId), inativa),
    ).rejects.toBeInstanceOf(EntidadeInexistenteError);

    const semPessoa = validarVinculo({
      commandId: 'n'.repeat(32),
      tipoEntidade: 'IGREJA',
      entidadeId: IGREJA_ID,
      acao: 'ATRIBUIR',
      pessoaId: 'pessoa-inexistente',
      dataEfetiva: PASSADO_5,
      expectedVersion: 1,
    });
    await expect(
      gerenciarVinculo(db, contexto(semPessoa.commandId), semPessoa),
    ).rejects.toBeInstanceOf(PessoaInexistenteError);

    const semAutoridade = validarVinculo({
      commandId: 'o'.repeat(32),
      tipoEntidade: 'IGREJA',
      entidadeId: IGREJA_ID,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_B,
      dataEfetiva: PASSADO_5,
      expectedVersion: 1,
    });
    await expect(
      gerenciarVinculo(db, contexto(semAutoridade.commandId, 'sem-autoridade'), semAutoridade),
    ).rejects.toBeInstanceOf(SemAutoridadeError);
  });

  it('consulta read-only devolve responsável e linha do tempo sem PII', async () => {
    const db = getFirestore(app);
    const resumo = await lerVinculos(db);
    expect(resumo.igrejas.length).toBeGreaterThan(0);
    const igrejaResumo = resumo.igrejas.find((i) => i.id === IGREJA_ID);
    expect(igrejaResumo?.responsavel?.pessoaId).toBe(PESSOA_A);
    expect(igrejaResumo?.historico.length).toBeGreaterThan(1);
    const primeiro = igrejaResumo?.historico[0];
    expect(primeiro?.acao).toBe('SUBSTITUIR');
    expect(primeiro?.papel).toBe('PASTOR_LOCAL');
    expect(primeiro?.atorNome).toContain('Administrador');
    expect(primeiro?.inicioVigencia).toMatch(
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/,
    );
    expect(JSON.stringify(resumo)).not.toMatch(/exemplo\.com|cpf/i);
    expect(resumo.equipes.find((e) => e.id === EQUIPE_ID)?.responsavel?.pessoaId).toBe(
      PESSOA_B,
    );
  });

  it('callables negam sessão sem autoridade sem persistir mutação', async () => {
    await expect(
      requisitar(consultarVinculos, {}, { uid: 'sem-autoridade' }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(
      requisitar(consultarVinculos, {}),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(
      requisitar(gerenciarVinculoCommand, {
        commandId: 'p2'.repeat(16),
        tipoEntidade: 'IGREJA',
        entidadeId: IGREJA_ID,
        acao: 'ATRIBUIR',
        pessoaId: PESSOA_B,
        dataEfetiva: PASSADO_5,
        expectedVersion: 1,
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });

    const commandId = 'p'.repeat(32);
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId,
          tipoEntidade: 'IGREJA',
          entidadeId: IGREJA_ID,
          acao: 'ATRIBUIR',
          pessoaId: PESSOA_B,
          dataEfetiva: PASSADO_5,
          expectedVersion: 1,
        },
        { uid: 'sem-autoridade' },
      ),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    const db = getFirestore(app);
    expect((await db.collection('commands').doc(commandId).get()).exists).toBe(false);
  });

  it('callable autorizada recusa comando inválido e grava vínculo válido', async () => {
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        { commandId: 'curto' },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'invalid-argument' });

    const commandId = 'q'.repeat(32);
    const resultado = await requisitar(
      gerenciarVinculoCommand,
      {
        commandId,
        tipoEntidade: 'IGREJA',
        entidadeId: IGREJA_ID,
        acao: 'SUBSTITUIR',
        pessoaId: PESSOA_B,
        dataEfetiva: HOJE,
        expectedVersion: 1,
        justificativa: 'troca de pastor',
      },
      { uid: ADMIN_UID },
    );
    expect(resultado).toMatchObject({ concluido: true, repetido: false });
    const db = getFirestore(app);
    const auditoria = await db.collection('auditOutbox').doc(commandId).get();
    expect(auditoria.data()?.justificativa).toBe('troca de pastor');
    const resumo = await lerVinculos(db);
    const igrejaResumo = resumo.igrejas.find((i) => i.id === IGREJA_ID);
    const comJustificativa = igrejaResumo?.historico.find(
      (evento) => evento.justificativa === 'troca de pastor',
    );
    expect(comJustificativa?.acao).toBe('SUBSTITUIR');
  });

  it('mapeia os códigos de erro do callable conforme a matriz de I/O', async () => {
    const db = getFirestore(app);
    const entidadeErros = 'ig-callable-erros';
    const equipeErros = 'eq-callable-erros';
    await db
      .collection('igrejas')
      .doc(entidadeErros)
      .set({ codigo: '240099', nome: 'Igreja Erros', ativo: true });
    await db
      .collection('equipes')
      .doc(equipeErros)
      .set({ nome: 'Equipe Erros', ativo: true });
    const base = {
      tipoEntidade: 'IGREJA',
      entidadeId: entidadeErros,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_A,
      dataEfetiva: PASSADO_5,
    };

    // Conflito de versão → aborted.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        { commandId: 'r'.repeat(32), ...base, expectedVersion: 99 },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'aborted' });

    // Atribuição válida estabelece o vigente para os próximos cenários.
    await requisitar(
      gerenciarVinculoCommand,
      { commandId: 's'.repeat(32), ...base, expectedVersion: 0 },
      { uid: ADMIN_UID },
    );

    // Vigente existente → failed-precondition.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: 't'.repeat(32),
          ...base,
          pessoaId: PESSOA_B,
          expectedVersion: 1,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });

    // Sobreposição (fim antes do início) → failed-precondition.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: 'u'.repeat(32),
          tipoEntidade: 'IGREJA',
          entidadeId: entidadeErros,
          acao: 'ENCERRAR',
          dataEfetiva: PASSADO_10,
          expectedVersion: 1,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });

    // Vínculo inexistente → failed-precondition.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: 'v'.repeat(32),
          tipoEntidade: 'EQUIPE',
          entidadeId: equipeErros,
          acao: 'ENCERRAR',
          dataEfetiva: HOJE,
          expectedVersion: 0,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });

    // Comando divergente → aborted.
    const divergente = 'w'.repeat(32);
    await db.collection('commands').doc(divergente).set({
      action: 'GERENCIAR_VINCULO',
      actorUid: ADMIN_UID,
      payloadHash: 'outro',
    });
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        { commandId: divergente, ...base, expectedVersion: 1 },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'aborted' });
  });

  it('recusa vínculo para entidade inativa sem persistir mutação', async () => {
    const db = getFirestore(app);
    const inativaId = 'ig-vinculos-inativa';
    await db.collection('igrejas').doc(inativaId).set({
      codigo: '240098',
      nome: 'Igreja Inativa',
      ativo: false,
    });

    const comandoRepo = 'x'.repeat(32);
    const entrada = validarVinculo({
      commandId: comandoRepo,
      tipoEntidade: 'IGREJA',
      entidadeId: inativaId,
      acao: 'ATRIBUIR',
      pessoaId: PESSOA_A,
      dataEfetiva: PASSADO_5,
      expectedVersion: 0,
    });
    await expect(
      gerenciarVinculo(db, contexto(entrada.commandId), entrada),
    ).rejects.toBeInstanceOf(EntidadeInexistenteError);

    const comandoCallable = 'y'.repeat(32);
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: comandoCallable,
          tipoEntidade: 'IGREJA',
          entidadeId: inativaId,
          acao: 'ATRIBUIR',
          pessoaId: PESSOA_A,
          dataEfetiva: PASSADO_5,
          expectedVersion: 0,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'invalid-argument' });

    expect((await db.collection('commands').doc(comandoRepo).get()).exists).toBe(false);
    expect((await db.collection('commands').doc(comandoCallable).get()).exists).toBe(false);
    expect((await db.collection('auditOutbox').doc(comandoRepo).get()).exists).toBe(false);
    expect((await db.collection('auditOutbox').doc(comandoCallable).get()).exists).toBe(false);
    const vinculos = await db
      .collection('vinculosPastorIgreja')
      .where('entidadeId', '==', inativaId)
      .get();
    expect(vinculos.empty).toBe(true);
  });

  it('mapeia entidade/pessoa inexistente e data futura pelos códigos da matriz', async () => {
    const db = getFirestore(app);

    // Entidade inexistente → invalid-argument.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: 'z'.repeat(32),
          tipoEntidade: 'IGREJA',
          entidadeId: 'ig-callable-inexistente',
          acao: 'ATRIBUIR',
          pessoaId: PESSOA_A,
          dataEfetiva: PASSADO_5,
          expectedVersion: 0,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'invalid-argument' });

    const entidade = 'ig-callable-erros-2';
    await db
      .collection('igrejas')
      .doc(entidade)
      .set({ codigo: '240097', nome: 'Igreja Erros 2', ativo: true });

    // Pessoa inexistente → invalid-argument.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: 'z1'.repeat(16),
          tipoEntidade: 'IGREJA',
          entidadeId: entidade,
          acao: 'ATRIBUIR',
          pessoaId: 'pessoa-inexistente',
          dataEfetiva: PASSADO_5,
          expectedVersion: 0,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'invalid-argument' });

    // Data futura → failed-precondition.
    await expect(
      requisitar(
        gerenciarVinculoCommand,
        {
          commandId: 'z2'.repeat(16),
          tipoEntidade: 'IGREJA',
          entidadeId: entidade,
          acao: 'ATRIBUIR',
          pessoaId: PESSOA_A,
          dataEfetiva: dataStr(1),
          expectedVersion: 0,
        },
        { uid: ADMIN_UID },
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});

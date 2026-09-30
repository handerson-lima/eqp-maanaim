import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import type { CallableRequest } from 'firebase-functions/v2/https';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  SemAutoridadeError,
  TERMO_ID_PADRAO,
  validarPublicarTermo,
} from '../src/domain/termos.js';
import { publicarTermo as publicarTermoCommand } from '../src/commands/publicarTermo.js';
import { consultarTermos as consultarTermosCommand } from '../src/commands/consultarTermos.js';
import { obterTermoVigente as obterTermoVigenteCommand } from '../src/commands/obterTermoVigente.js';
import {
  consultarTermosRepo,
  obterTermoVigenteRepo,
  publicarTermo,
  type ContextoTermo,
} from '../src/repositories/termos.js';

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

const ADMIN_UID = 'admin-termos-teste';
const USUARIO_COMUM_UID = 'usuario-comum-teste';
const COLECOES = ['termos', 'commands', 'auditOutbox', 'autoridadesAdministrativas', 'fichas'];

describe.runIf(habilitado)('integração de termos com emulador Firestore', () => {
  let app: App;

  beforeAll(async () => {
    app = initializeApp({ projectId: 'demo-maanaim' }, 'termos-emulator-test');
    const db = getFirestore(app);

    // Limpa coleções
    for (const c of COLECOES) {
      const snap = await db.collection(c).get();
      for (const doc of snap.docs) {
        await doc.ref.delete();
      }
    }

    // Configura autoridade administrativa
    await db.collection('autoridadesAdministrativas').doc(ADMIN_UID).set({
      ativa: true,
      papel: 'ADMINISTRADOR',
      criadoEm: FieldValue.serverTimestamp(),
    });

    await db.collection('autoridadesAdministrativas').doc(USUARIO_COMUM_UID).set({
      ativa: false,
    });
  });

  afterAll(async () => {
    if (app) await deleteApp(app);
  });

  it('publica a primeira versão do termo como vigente e imutável', async () => {
    const db = getFirestore(app);
    const entrada = validarPublicarTermo({
      commandId: 'cmd-termo-0001-aaaa',
      correlationId: 'corr-0001',
      titulo: 'Termo de Adesão ao Serviço Voluntário',
      conteudo: 'Cláusula 1: O voluntário concorda em servir com dedicação no Maanaim.',
      expectedVersion: 0,
    });

    const contexto: ContextoTermo = {
      commandId: entrada.commandId,
      correlacaoId: entrada.correlationId ?? entrada.commandId,
      atorUid: ADMIN_UID,
      origem: 'teste-emulador',
    };

    const resultado = await publicarTermo(db, contexto, entrada);
    expect(resultado.repetido).toBe(false);
    expect(resultado.numeroVersao).toBe(1);
    expect(resultado.hashSha256).toBe(entrada.hashConteudo);

    // Valida termo pai no banco
    const termoSnap = await db.collection('termos').doc(entrada.termoId).get();
    expect(termoSnap.exists).toBe(true);
    const termoData = termoSnap.data()!;
    expect(termoData.versaoVigenteNumero).toBe(1);
    expect(termoData.versaoVigenteId).toBe(resultado.versaoId);
    expect(termoData.hashSha256).toBe(resultado.hashSha256);

    // Valida versão imutável criada
    const versaoSnap = await db
      .collection('termos')
      .doc(entrada.termoId)
      .collection('versoes')
      .doc(resultado.versaoId)
      .get();
    expect(versaoSnap.exists).toBe(true);
    const versaoData = versaoSnap.data()!;
    expect(versaoData.numeroVersao).toBe(1);
    expect(versaoData.imutavel).toBe(true);
    expect(versaoData.versaoAnteriorId).toBeNull();

    // Valida recibo em commands
    const reciboSnap = await db.collection('commands').doc(entrada.commandId).get();
    expect(reciboSnap.exists).toBe(true);
    expect(reciboSnap.data()!.estado).toBe('COMPLETO');

    // Valida outbox de auditoria
    const auditSnap = await db.collection('auditOutbox').doc(entrada.commandId).get();
    expect(auditSnap.exists).toBe(true);
    expect(auditSnap.data()!.action).toBe('PUBLICAR_TERMO');
  });

  it('repete o mesmo comando com idempotência sem duplicar versões', async () => {
    const db = getFirestore(app);
    const entrada = validarPublicarTermo({
      commandId: 'cmd-termo-0001-aaaa',
      correlationId: 'corr-0001',
      titulo: 'Termo de Adesão ao Serviço Voluntário',
      conteudo: 'Cláusula 1: O voluntário concorda em servir com dedicação no Maanaim.',
      expectedVersion: 0,
    });

    const contexto: ContextoTermo = {
      commandId: entrada.commandId,
      correlacaoId: entrada.correlationId ?? entrada.commandId,
      atorUid: ADMIN_UID,
      origem: 'teste-emulador',
    };

    const resultado = await publicarTermo(db, contexto, entrada);
    expect(resultado.repetido).toBe(true);
    expect(resultado.numeroVersao).toBe(1);
  });

  it('rejeita mesmo commandId com payload divergente', async () => {
    const db = getFirestore(app);
    const entradaDivergente = validarPublicarTermo({
      commandId: 'cmd-termo-0001-aaaa',
      correlationId: 'corr-0001',
      titulo: 'Título Divergente Modificado',
      conteudo: 'Conteúdo totalmente divergente da primeira requisição.',
      expectedVersion: 0,
    });

    const contexto: ContextoTermo = {
      commandId: entradaDivergente.commandId,
      correlacaoId: entradaDivergente.correlationId ?? entradaDivergente.commandId,
      atorUid: ADMIN_UID,
      origem: 'teste-emulador',
    };

    await expect(publicarTermo(db, contexto, entradaDivergente)).rejects.toThrow(
      ComandoDivergenteError,
    );
  });

  it('publica nova versão mantendo a versão 1 consultável e intacta', async () => {
    const db = getFirestore(app);
    const entradaV2 = validarPublicarTermo({
      commandId: 'cmd-termo-0002-bbbb',
      correlationId: 'corr-0002',
      titulo: 'Termo de Adesão Atualizado (v2)',
      conteudo: 'Cláusula 1 atualizada: O voluntário reafirma o compromisso com o Maanaim.',
      expectedVersion: 1,
    });

    const contexto: ContextoTermo = {
      commandId: entradaV2.commandId,
      correlacaoId: entradaV2.correlationId ?? entradaV2.commandId,
      atorUid: ADMIN_UID,
      origem: 'teste-emulador',
    };

    const resultado = await publicarTermo(db, contexto, entradaV2);
    expect(resultado.repetido).toBe(false);
    expect(resultado.numeroVersao).toBe(2);

    // Valida que termo pai agora aponta para v2
    const termoSnap = await db.collection('termos').doc(entradaV2.termoId).get();
    expect(termoSnap.data()!.versaoVigenteNumero).toBe(2);
    expect(termoSnap.data()!.versaoVigenteId).toBe(resultado.versaoId);

    // Consulta histórico completo
    const resumo = await consultarTermosRepo(db, ADMIN_UID, entradaV2.termoId);
    expect(resumo).not.toBeNull();
    expect(resumo!.totalVersoes).toBe(2);
    expect(resumo!.versoes).toHaveLength(2);
    expect(resumo!.versoes![0].numeroVersao).toBe(2);
    expect(resumo!.versoes![1].numeroVersao).toBe(1);

    // Obter termo vigente retorna v2
    const vigente = await obterTermoVigenteRepo(db, entradaV2.termoId);
    expect(vigente).not.toBeNull();
    expect(vigente!.numeroVersao).toBe(2);
    expect(vigente!.titulo).toBe('Termo de Adesão Atualizado (v2)');
  });

  it('rejeita publicação se expectedVersion estiver defasado (conflito de versão)', async () => {
    const db = getFirestore(app);
    const entradaConflitante = validarPublicarTermo({
      commandId: 'cmd-termo-0003-cccc',
      titulo: 'Tentativa Conflitante',
      conteudo: 'Este envio assume que ainda estamos na versão 1 quando já estamos na 2.',
      expectedVersion: 1, // Já estamos na 2!
    });

    const contexto: ContextoTermo = {
      commandId: entradaConflitante.commandId,
      correlacaoId: entradaConflitante.commandId,
      atorUid: ADMIN_UID,
      origem: 'teste-emulador',
    };

    await expect(publicarTermo(db, contexto, entradaConflitante)).rejects.toThrow(
      ConflitoVersaoError,
    );
  });

  it('rejeita publicação executada por usuário sem autoridade administrativa', async () => {
    const db = getFirestore(app);
    const entrada = validarPublicarTermo({
      commandId: 'cmd-termo-0004-dddd',
      titulo: 'Tentativa Não Autorizada',
      conteudo: 'Tentativa de publicação por usuário sem papel de administrador.',
      expectedVersion: 2,
    });

    const contexto: ContextoTermo = {
      commandId: entrada.commandId,
      correlacaoId: entrada.commandId,
      atorUid: USUARIO_COMUM_UID,
      origem: 'teste-emulador',
    };

    await expect(publicarTermo(db, contexto, entrada)).rejects.toThrow(SemAutoridadeError);
  });
});

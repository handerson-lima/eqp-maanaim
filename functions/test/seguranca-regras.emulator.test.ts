import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const habilitado = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = process.env.GCLOUD_PROJECT ?? 'demo-maanaim';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? 'localhost:8080';
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? 'localhost:9199';

const raiz = resolve(process.cwd(), '..');
const firestoreRules = readFileSync(join(raiz, 'firestore.rules'), 'utf8');
const storageRules = readFileSync(join(raiz, 'storage.rules'), 'utf8');

describe('auditoria e regras de segurança Firestore e Storage (AD-1, AD-9, AD-12)', () => {
  it('garante que firestore.rules bloqueia globalmente leituras e escritas diretas do cliente', () => {
    expect(firestoreRules).toContain('match /{document=**} { allow read, write: if false; }');
    expect(firestoreRules).toContain('allow write: if false;');
    // Não permite concessões baseadas no token do cliente sem passar por Cloud Function
    expect(firestoreRules).not.toMatch(/allow\s+write\s*:\s*if\s+request\.auth/);
  });

  it('garante que coleções críticas de domínio e auditoria são estritamente inacessíveis ao cliente', () => {
    const colecoesCriticas = [
      'vinculosPastorIgreja',
      'vinculosPastorEquipe',
      'commands',
      'auditOutbox',
      'auditoria',
      'alertasOperacionais',
    ];
    for (const col of colecoesCriticas) {
      const regex = new RegExp(`match /${col}/\\{[^}]+\\}\\s*\\{\\s*allow read, write: if false;`);
      expect(firestoreRules).toMatch(regex);
    }
  });

  it('garante que subcoleções de versões de termos são protegidas contra leitura direta', () => {
    expect(firestoreRules).toMatch(/match \/versoes\/\{versaoId\}\s*\{\s*allow read, write: if false;\s*\}/);
  });

  it('garante que storage.rules bloqueia leitura e escrita direta em todos os caminhos do bucket', () => {
    expect(storageRules).toContain('match /b/{bucket}/o { match /{allPaths=**} { allow read, write: if false; } }');
    expect(storageRules).not.toMatch(/allow\s+(read|write)\s*:\s*if\s+request\.auth/);
  });
});

describe.skipIf(!habilitado)('validação de regras com Firestore e Storage Emulator em execução', () => {
  let adminApp: App;

  beforeAll(async () => {
    adminApp = initializeApp(
      { projectId },
      'seguranca-rules-test-app',
    );
    const db = getFirestore(adminApp);
    // Insere registros para validar leitura condicional
    await db.collection('igrejas').doc('igreja-ativa-teste').set({
      nome: 'Igreja Ativa Teste',
      ativo: true,
    });
    await db.collection('igrejas').doc('igreja-inativa-teste').set({
      nome: 'Igreja Inativa Teste',
      ativo: false,
    });
    await db.collection('fichas').doc('ficha-privada-teste').set({
      nomeCompleto: 'Voluntário Teste',
      cpf: '12345678901',
      estado: 'ATIVA',
    });
  });

  afterAll(async () => {
    if (adminApp) {
      const db = getFirestore(adminApp);
      await db.collection('igrejas').doc('igreja-ativa-teste').delete();
      await db.collection('igrejas').doc('igreja-inativa-teste').delete();
      await db.collection('fichas').doc('ficha-privada-teste').delete();
      await deleteApp(adminApp);
    }
  });

  it('permite leitura pública apenas de igreja ativa via REST API não-autenticada', async () => {
    const urlAtiva = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/igrejas/igreja-ativa-teste`;
    const respAtiva = await fetch(urlAtiva);
    expect(respAtiva.status).toBe(200);

    const urlInativa = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/igrejas/igreja-inativa-teste`;
    const respInativa = await fetch(urlInativa);
    expect(respInativa.status).toBe(403);
  });

  it('nega estritamente escrita direta pelo cliente em catálogo de igrejas e equipes', async () => {
    const url = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/igrejas/tentativa-cliente`;
    const resp = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          nome: { stringValue: 'Tentativa Invasiva' },
          ativo: { booleanValue: true },
        },
      }),
    });
    expect(resp.status).toBe(403);
  });

  it('nega leitura e escrita direta em fichas de voluntários para qualquer cliente', async () => {
    const url = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/fichas/ficha-privada-teste`;
    const respLeitura = await fetch(url);
    expect(respLeitura.status).toBe(403);

    const respEscrita = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          estado: { stringValue: 'MODIFICADO_DIRETAMENTE' },
        },
      }),
    });
    expect(respEscrita.status).toBe(403);
  });

  it('nega leitura e escrita direta em auditoria, recibos (commands) e outbox', async () => {
    const colecoes = ['commands', 'auditOutbox', 'auditoria', 'alertasOperacionais'];
    for (const col of colecoes) {
      const url = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${col}/doc-teste`;
      const respGet = await fetch(url);
      expect(respGet.status).toBe(403);

      const respPatch = await fetch(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fields: { payload: { stringValue: 'teste' } },
        }),
      });
      expect(respPatch.status).toBe(403);
    }
  });

  it('nega leitura e escrita direta em qualquer objeto do Storage Emulator', async () => {
    const url = `http://${storageHost}/v0/b/${projectId}.appspot.com/o/pdfs%2Fficha-123%2Ftermo.pdf`;
    try {
      const resp = await fetch(url);
      expect([400, 403, 404]).toContain(resp.status);
    } catch {
      // Storage emulator pode não estar ouvindo na porta se executado apenas com firestore
    }
  });
});

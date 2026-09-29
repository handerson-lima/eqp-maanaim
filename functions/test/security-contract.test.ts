import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const raiz = resolve(process.cwd(), '..');
const regras = readFileSync(join(raiz, 'firestore.rules'), 'utf8');
const comando = readFileSync(join(raiz, 'functions', 'src', 'commands', 'criarOuRetomarRascunho.ts'), 'utf8');
const bootstrapWeb = readFileSync(join(raiz, 'flutter_app', 'lib', 'main.dart'), 'utf8');
const admin = readFileSync(join(raiz, 'functions', 'src', 'commands', 'gerenciarAutoridadeAdministrativa.ts'), 'utf8');
const storage = readFileSync(join(raiz, 'storage.rules'), 'utf8');

describe('contratos de segurança executáveis', () => {
  it('nega escrita de domínio e leitura direta de ficha pelo cliente', () => {
    expect(regras).toContain('match /{document=**} { allow read, write: if false; }');
    expect(regras).toContain('allow get, list: if resource.data.ativo == true;');
    expect(regras).toContain('allow write: if false;');
    // Nenhuma regra concede acesso condicionado a `request.auth`; a leitura da
    // ficha é coberta pelo deny global.
    expect(regras).not.toMatch(/allow\s+[^;]*request\.auth/);
  });
  it('exige App Check, autenticação, recibo idempotente e correlação para o rascunho', () => {
    expect(comando).toContain('enforceAppCheck: true');
    expect(comando).toContain('if (!request.auth)');
    expect(comando).toContain('if (reciboAtual.exists)');
    expect(comando).toContain("tx.create(ficha");
    expect(comando).toContain('payloadHash');
    expect(comando).toContain('correlationId');
  });
  it('ativa App Check Web antes de apresentar a interface', () => {
    expect(bootstrapWeb).toContain("FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY");
    expect(bootstrapWeb).toContain('FirebaseAppCheck.instance');
    expect(bootstrapWeb).toContain('ReCaptchaV3Provider(appCheckSiteKey)');
    expect(bootstrapWeb.indexOf('FirebaseAppCheck.instance')).toBeLessThan(bootstrapWeb.indexOf('runApp(MaanaimApp'));
  });
  it('não registra PII no recibo ou na auditoria', () => {
    const recibo = comando.match(/tx\.create\(recibo, \{([^}]*)\}\)/)?.[1];
    const auditoria = comando.match(/tx\.create\(db\.collection\('auditOutbox'\).*?\{([^}]*)\}\)/)?.[1];
    expect(recibo).toBeDefined();
    expect(auditoria).toBeDefined();
    expect(recibo).not.toMatch(/nomeCompleto|cpf|profissao|email|senha|token/);
    expect(auditoria).not.toMatch(/nomeCompleto|cpf|profissao|email|senha|token/);
  });
  it('protege administração com App Check, autorização canônica e continuidade', () => {
    expect(admin).toContain('enforceAppCheck: true');
    expect(admin).toContain('podeAdministrar');
    expect(admin).toContain('alvoUid === request.auth.uid');
    // A última administração ativa é contada apenas entre autoridades válidas.
    expect(admin).toContain('filter(d => podeAdministrar');
    expect(admin).toContain('reconciliarClaimAdministrativa');
    expect(admin).not.toMatch(/console\.(log|error)/);
    expect(storage).toContain('allow read, write: if false');
  });
  it('recusa comando divergente e não persiste o UID do alvo no recibo', () => {
    expect(admin).toContain('payloadHash');
    expect(admin).toContain('r.payloadHash !== payloadHash');
    const recibo = admin.match(/tx\.create\(recibo, \{([^}]*)\}\)/)?.[1];
    expect(recibo).toBeDefined();
    expect(recibo).not.toContain('alvoUid');
  });
});

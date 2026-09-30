import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const raiz = resolve(process.cwd(), '..');
const regras = readFileSync(join(raiz, 'firestore.rules'), 'utf8');
const comando = readFileSync(join(raiz, 'functions', 'src', 'commands', 'criarOuRetomarRascunho.ts'), 'utf8');
const bootstrapWeb = readFileSync(join(raiz, 'flutter_app', 'lib', 'main.dart'), 'utf8');
const admin = readFileSync(join(raiz, 'functions', 'src', 'commands', 'gerenciarAutoridadeAdministrativa.ts'), 'utf8');
const storage = readFileSync(join(raiz, 'storage.rules'), 'utf8');
const semear = readFileSync(join(raiz, 'functions', 'src', 'commands', 'semearCatalogoInicial.ts'), 'utf8');
const consultar = readFileSync(join(raiz, 'functions', 'src', 'commands', 'consultarCatalogo.ts'), 'utf8');
const repoCatalogo = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'catalogo.ts'), 'utf8');
const salvarPessoa = readFileSync(join(raiz, 'functions', 'src', 'commands', 'salvarPessoa.ts'), 'utf8');
const gerenciarPapeis = readFileSync(join(raiz, 'functions', 'src', 'commands', 'gerenciarPapeis.ts'), 'utf8');
const consultarPessoas = readFileSync(join(raiz, 'functions', 'src', 'commands', 'consultarPessoas.ts'), 'utf8');
const repoPessoas = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'pessoas.ts'), 'utf8');
const index = readFileSync(join(raiz, 'functions', 'src', 'index.ts'), 'utf8');
const autoridadeDomain = readFileSync(join(raiz, 'functions', 'src', 'domain', 'autoridadeAdministrativa.ts'), 'utf8');
const catalogoService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'admin', 'catalogo_service.dart'), 'utf8');
const authService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'auth', 'auth_service.dart'), 'utf8');
const pessoasService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'admin', 'pessoas_service.dart'), 'utf8');

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
    const chamadaApp = bootstrapWeb.search(/runApp\(\s*MaanaimApp/);
    expect(chamadaApp).toBeGreaterThan(-1);
    expect(bootstrapWeb.indexOf('FirebaseAppCheck.instance')).toBeLessThan(chamadaApp);
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
  it('libera leitura de equipes ativas mantendo a escrita negada', () => {
    const bloco = regras.match(/match \/equipes\/\{equipeId\} \{([\s\S]*?)\n    \}/)?.[1];
    expect(bloco).toBeDefined();
    expect(bloco).toContain('allow get, list: if resource.data.ativo == true;');
    expect(bloco).toContain('allow write: if false;');
    expect(bloco).not.toContain('if true');
  });
  it('protege o seed do catálogo com App Check, autoridade e transação idempotente', () => {
    expect(semear).toContain('enforceAppCheck: true');
    expect(semear).toContain('if (!request.auth)');
    expect(semear).toContain('semearCatalogo');
    expect(semear).not.toMatch(/console\.(log|error)/);
    expect(repoCatalogo).toContain('podeAdministrar');
    expect(repoCatalogo).toContain('runTransaction');
    expect(repoCatalogo).toContain('reciboSnap.exists');
    expect(repoCatalogo).toContain('payloadHash');
    expect(repoCatalogo).toContain("tx.create(reciboRef");
    expect(repoCatalogo).toContain("tx.create(auditoriaRef");
    // Seed só cria o ausente: nunca atualiza nem sobrescreve o catálogo.
    expect(repoCatalogo).not.toMatch(/tx\.(update|set)\(/);
  });
  it('exige autoridade na consulta do catálogo e não registra PII', () => {
    expect(consultar).toContain('enforceAppCheck: true');
    expect(consultar).toContain('podeAdministrar');
    expect(consultar).not.toMatch(/console\.(log|error)/);
    expect(repoCatalogo).not.toMatch(/cpf|email|nomeCompleto|senha|token/i);
  });
  it('protege o cadastro de pessoa com App Check, autoridade e sem PII no recibo', () => {
    expect(salvarPessoa).toContain('enforceAppCheck: true');
    expect(salvarPessoa).toContain('if (!request.auth)');
    expect(salvarPessoa).toContain('validarPessoa');
    expect(salvarPessoa).not.toMatch(/console\.(log|error)/);
    expect(repoPessoas).toContain('podeAdministrar');
    expect(repoPessoas).toContain('runTransaction');
    expect(repoPessoas).toContain('reciboSnap.exists');
    expect(repoPessoas).toContain('payloadHash');
    const recibo = repoPessoas.match(/tx\.create\(reciboRef, \{([^}]*)\}\)/)?.[1];
    const auditoria = repoPessoas.match(/tx\.create\(auditoriaRef, \{([^}]*)\}\)/)?.[1];
    expect(recibo).toBeDefined();
    expect(auditoria).toBeDefined();
    expect(recibo).not.toMatch(/cpf|nomeCompleto|email/);
    expect(auditoria).not.toMatch(/cpf|nomeCompleto|email/);
  });
  it('bloqueia autoatribuição, último ADMIN e exige autoridade em transação', () => {
    expect(gerenciarPapeis).toContain('enforceAppCheck: true');
    expect(gerenciarPapeis).toContain('alvoUid === request.auth.uid');
    expect(gerenciarPapeis).toContain('reconciliarClaimAdministrativa');
    expect(gerenciarPapeis).not.toMatch(/console\.(log|error)/);
    expect(repoPessoas).toContain('UltimoAdminError');
    expect(repoPessoas).toContain("where('ativa', '==', true)");
    expect(repoPessoas).toContain('podeAdministrar');
  });
  it('mantém a consulta de pessoas autorizada e nunca devolve CPF', () => {
    expect(consultarPessoas).toContain('enforceAppCheck: true');
    expect(consultarPessoas).toContain('podeAdministrar');
    expect(consultarPessoas).not.toMatch(/console\.(log|error)/);
    const blocoConsulta = repoPessoas.match(/export async function lerPessoas[\s\S]*?\n\}/)?.[0];
    expect(blocoConsulta).toBeDefined();
    expect(blocoConsulta).not.toMatch(/cpf/);
  });
  it('nega leitura e escrita de pessoa, papel e CPF pelos Rules', () => {
    expect(regras).toContain('match /{document=**} { allow read, write: if false; }');
    expect(regras).not.toMatch(/pessoas|coordenadores|autoridadesAdministrativas/);
  });
  it('exporta no entrypoint cada callable invocada pelo cliente', () => {
    const nomesCliente = [
      'consultarCatalogo',
      'semearCatalogoInicial',
      'consultarPessoas',
      'salvarPessoa',
      'gerenciarPapeis',
    ];
    for (const nome of nomesCliente) {
      const invocada =
        catalogoService.includes(`httpsCallable('${nome}')`) ||
        authService.includes(`httpsCallable('${nome}')`) ||
        pessoasService.includes(`httpsCallable('${nome}')`);
      expect(invocada, `${nome} não é invocada pelo cliente`).toBe(true);
      expect(
        index.includes(`export { ${nome} }`),
        `${nome} não é exportada em index.ts`,
      ).toBe(true);
    }
  });
  it('mantém o nome da claim e os papéis de sistema sincronizados entre Dart e TS', () => {
    expect(autoridadeDomain).toContain("NOME_CLAIM_ADMINISTRATIVA = 'maanaimAdmin'");
    expect(authService).toContain("claimAdministrativa = 'maanaimAdmin'");
    expect(pessoasService).toContain("'ADMINISTRADOR': 'Administrador'");
    expect(pessoasService).toContain("'COORDENADOR': 'Coordenador'");
  });
});

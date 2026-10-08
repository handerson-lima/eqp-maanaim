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
const vinculosService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'admin', 'vinculos_service.dart'), 'utf8');
const gerenciarVinculo = readFileSync(join(raiz, 'functions', 'src', 'commands', 'gerenciarVinculo.ts'), 'utf8');
const consultarVinculos = readFileSync(join(raiz, 'functions', 'src', 'commands', 'consultarVinculos.ts'), 'utf8');
const repoVinculos = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'vinculos.ts'), 'utf8');
const domainVinculos = readFileSync(join(raiz, 'functions', 'src', 'domain', 'vinculos.ts'), 'utf8');
const publicarTermo = readFileSync(join(raiz, 'functions', 'src', 'commands', 'publicarTermo.ts'), 'utf8');
const consultarTermos = readFileSync(join(raiz, 'functions', 'src', 'commands', 'consultarTermos.ts'), 'utf8');
const obterTermoVigente = readFileSync(join(raiz, 'functions', 'src', 'commands', 'obterTermoVigente.ts'), 'utf8');
const repoTermos = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'termos.ts'), 'utf8');
const domainTermos = readFileSync(join(raiz, 'functions', 'src', 'domain', 'termos.ts'), 'utf8');
const termosService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'admin', 'termos_service.dart'), 'utf8');
const aceitarTermoVigenteCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'aceitarTermoVigente.ts'), 'utf8');
const obterHistoricoAceitesCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'obterHistoricoAceites.ts'), 'utf8');
const voluntarioTermosService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'termo', 'termo_service.dart'), 'utf8');
const enviarFichaCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'enviarFichaAprovacao.ts'), 'utf8');
const repoEnviarFicha = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'enviarFicha.ts'), 'utf8');
const obterFilaPastorCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'obterFilaPastorLocal.ts'), 'utf8');
const decidirFichaPastorCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'decidirFichaPastorLocal.ts'), 'utf8');
const repoDecisaoPastor = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'decisaoPastor.ts'), 'utf8');
const obterFilaCoordenadorCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'obterFilaCoordenador.ts'), 'utf8');
const decidirAtivacaoCoordenadorCmd = readFileSync(join(raiz, 'functions', 'src', 'commands', 'decidirAtivacaoCoordenador.ts'), 'utf8');
const repoDecisaoCoordenador = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'decisaoCoordenador.ts'), 'utf8');
const domainDecisaoCoordenador = readFileSync(join(raiz, 'functions', 'src', 'domain', 'decisaoCoordenador.ts'), 'utf8');
const coordenadorService = readFileSync(join(raiz, 'flutter_app', 'lib', 'features', 'coordenador', 'coordenador_service.dart'), 'utf8');

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
      'consultarVinculos',
      'gerenciarVinculo',
      'publicarTermo',
      'consultarTermos',
      'obterTermoVigente',
      'aceitarTermoVigente',
      'obterHistoricoAceites',
    ];
    for (const nome of nomesCliente) {
      const invocada =
        catalogoService.includes(`httpsCallable('${nome}')`) ||
        authService.includes(`httpsCallable('${nome}')`) ||
        pessoasService.includes(`httpsCallable('${nome}')`) ||
        vinculosService.includes(`httpsCallable('${nome}')`) ||
        termosService.includes(`httpsCallable('${nome}')`) ||
        voluntarioTermosService.includes(`httpsCallable('${nome}')`);
      expect(invocada, `${nome} não é invocada pelo cliente`).toBe(true);
      expect(
        index.includes(`export { ${nome} }`),
        `${nome} não é exportada em index.ts`,
      ).toBe(true);
    }
  });
  it('protege os vínculos temporais com App Check, autoridade em transação e sem PII', () => {
    expect(gerenciarVinculo).toContain('enforceAppCheck: true');
    expect(gerenciarVinculo).toContain('if (!request.auth)');
    expect(gerenciarVinculo).toContain('validarVinculo');
    expect(gerenciarVinculo).not.toMatch(/console\.(log|error)/);
    expect(repoVinculos).toContain('podeAdministrar');
    expect(repoVinculos).toContain('runTransaction');
    expect(repoVinculos).toContain('reciboSnap.exists');
    expect(repoVinculos).toContain('payloadHash');
    expect(repoVinculos).toContain('tx.create(reciboRef');
    expect(repoVinculos).toContain('tx.create(auditoriaRef');
    expect(repoVinculos).toContain('planejarVinculo');
    const recibo = repoVinculos.match(/tx\.create\(reciboRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    const auditoria = repoVinculos.match(
      /tx\.create\(auditoriaRef, \{([\s\S]*?)\n    \}\);/,
    )?.[1];
    expect(recibo).toBeDefined();
    expect(auditoria).toBeDefined();
    expect(recibo).not.toMatch(/cpf|nomeCompleto|email/);
    expect(auditoria).not.toMatch(/cpf|nomeCompleto|email/);
  });

  it('mantém a consulta de vínculos autorizada e nunca devolve PII', () => {
    expect(consultarVinculos).toContain('enforceAppCheck: true');
    expect(consultarVinculos).toContain('podeAdministrar');
    expect(consultarVinculos).not.toMatch(/console\.(log|error)/);
    const blocoConsulta = repoVinculos.match(
      /export async function lerVinculos[\s\S]*?\n\}/,
    )?.[0];
    expect(blocoConsulta).toBeDefined();
    expect(blocoConsulta).not.toMatch(/cpf|email/i);
  });

  it('nega leitura e escrita dos vínculos e dos campos de responsável pelos Rules', () => {
    expect(regras).toContain('match /vinculosPastorIgreja/{vinculoId}');
    expect(regras).toContain('match /vinculosPastorEquipe/{vinculoId}');
    expect(regras).toContain('match /{document=**} { allow read, write: if false; }');
    expect(regras).not.toMatch(/allow\s+[^;]*request\.auth/);
  });

  it('impõe exatamente um vigente sem sobreposição e data não futura no domínio', () => {
    expect(domainVinculos).toContain('planejarVinculo');
    expect(domainVinculos).toContain('SobreposicaoError');
    expect(domainVinculos).toContain('DataInvalidaError');
    expect(domainVinculos).toContain('PASTOR_LOCAL');
    expect(domainVinculos).toContain('PASTOR_EQUIPE');
  });

  it('mantém o nome da claim e os papéis de sistema sincronizados entre Dart e TS', () => {
    expect(autoridadeDomain).toContain("NOME_CLAIM_ADMINISTRATIVA = 'maanaimAdmin'");
    expect(authService).toContain("claimAdministrativa = 'maanaimAdmin'");
    expect(pessoasService).toContain("'ADMINISTRADOR': 'Administrador'");
    expect(pessoasService).toContain("'COORDENADOR': 'Coordenador'");
  });

  it('protege a publicação e versionamento de termos com App Check, imutabilidade e sem PII', () => {
    expect(publicarTermo).toContain('enforceAppCheck: true');
    expect(publicarTermo).toContain('if (!request.auth)');
    expect(publicarTermo).toContain('validarPublicarTermo');
    expect(publicarTermo).not.toMatch(/console\.(log|error)/);
    expect(consultarTermos).toContain('enforceAppCheck: true');
    expect(consultarTermos).not.toMatch(/console\.(log|error)/);
    expect(obterTermoVigente).toContain('enforceAppCheck: true');
    expect(obterTermoVigente).not.toMatch(/console\.(log|error)/);
    expect(repoTermos).toContain('podeAdministrar');
    expect(repoTermos).toContain('runTransaction');
    expect(repoTermos).toContain('reciboSnap.exists');
    expect(repoTermos).toContain('payloadHash');
    expect(repoTermos).toContain('tx.create(reciboRef');
    expect(repoTermos).toContain('tx.create(auditoriaRef');
    expect(repoTermos).toContain('imutavel: true');
    expect(regras).toContain('match /termos/{termoId}');
    expect(regras).toContain('match /versoes/{versaoId}');
    expect(regras).toContain('allow write: if false;');
    const recibo = repoTermos.match(/tx\.create\(reciboRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    const auditoria = repoTermos.match(/tx\.create\(auditoriaRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    expect(recibo).toBeDefined();
    expect(auditoria).toBeDefined();
    expect(recibo).not.toMatch(/cpf|nomeCompleto|email/);
    expect(auditoria).not.toMatch(/cpf|nomeCompleto|email/);
  });

  it('protege o aceite de termos com App Check, transação, imutabilidade e sem PII em auditoria', () => {
    expect(aceitarTermoVigenteCmd).toContain('enforceAppCheck: true');
    expect(aceitarTermoVigenteCmd).toContain('if (!request.auth)');
    expect(aceitarTermoVigenteCmd).toContain('validarAceitarTermoVigente');
    expect(aceitarTermoVigenteCmd).not.toMatch(/console\.(log|error)/);
    expect(obterHistoricoAceitesCmd).toContain('enforceAppCheck: true');
    expect(obterHistoricoAceitesCmd).toContain('if (!request.auth)');
    expect(obterHistoricoAceitesCmd).not.toMatch(/console\.(log|error)/);
    expect(repoTermos).toContain('runTransaction');
    expect(repoTermos).toContain('reciboSnap.exists');
    expect(repoTermos).toContain('aceiteSnap.exists');
    expect(repoTermos).toContain('imutavel: true');
  });

  it('protege o envio de ficha com App Check, autenticação, transação e auditoria sem PII', () => {
    expect(enviarFichaCmd).toContain('enforceAppCheck: true');
    expect(enviarFichaCmd).toContain('if (!request.auth)');
    expect(enviarFichaCmd).toContain('validarEnviarFicha');
    expect(enviarFichaCmd).not.toMatch(/console\.(log|error)/);
    expect(repoEnviarFicha).toContain('runTransaction');
    expect(repoEnviarFicha).toContain('reciboSnap.exists');
    expect(repoEnviarFicha).toContain('payloadHash');
    expect(repoEnviarFicha).toContain('tx.create(reciboRef');
    expect(repoEnviarFicha).toContain('tx.create(auditoriaRef');
    const recibo = repoEnviarFicha.match(/tx\.create\(reciboRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    const auditoria = repoEnviarFicha.match(/tx\.create\(auditoriaRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    expect(recibo).toBeDefined();
    expect(auditoria).toBeDefined();
    expect(recibo).not.toMatch(/cpf|nomeCompleto|email/);
    expect(auditoria).not.toMatch(/cpf|nomeCompleto|email/);
  });

  it('protege a fila e a decisão do pastor com App Check, autenticação, transação e auditoria sem PII', () => {
    expect(obterFilaPastorCmd).toContain('enforceAppCheck: true');
    expect(obterFilaPastorCmd).toContain('if (!request.auth)');
    expect(obterFilaPastorCmd).not.toMatch(/console\.(log|error)/);

    expect(decidirFichaPastorCmd).toContain('enforceAppCheck: true');
    expect(decidirFichaPastorCmd).toContain('if (!request.auth)');
    expect(decidirFichaPastorCmd).toContain('validarDecidirFichaPastor');
    expect(decidirFichaPastorCmd).not.toMatch(/console\.(log|error)/);

    expect(repoDecisaoPastor).toContain('runTransaction');
    expect(repoDecisaoPastor).toContain('reciboSnap.exists');
    expect(repoDecisaoPastor).toContain('payloadHash');
    expect(repoDecisaoPastor).toContain('pastorLocalVigentePessoaId');
    expect(repoDecisaoPastor).toContain('SemVinculoPastoralError');

    const auditoria = repoDecisaoPastor.match(/tx\.set\(auditoriaRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    expect(auditoria).toBeDefined();
    expect(auditoria).not.toMatch(/cpf|nomeCompleto|email|justificativa/);
  });

  it('protege a fila e a decisão do coordenador com App Check, autoridade canônica e auditoria sem PII', () => {
    expect(obterFilaCoordenadorCmd).toContain('enforceAppCheck: true');
    expect(obterFilaCoordenadorCmd).toContain('if (!request.auth)');
    expect(obterFilaCoordenadorCmd).not.toMatch(/console\.(log|error)/);

    expect(decidirAtivacaoCoordenadorCmd).toContain('enforceAppCheck: true');
    expect(decidirAtivacaoCoordenadorCmd).toContain('if (!request.auth)');
    expect(decidirAtivacaoCoordenadorCmd).toContain('validarDecidirAtivacaoCoordenador');
    expect(decidirAtivacaoCoordenadorCmd).not.toMatch(/console\.(log|error)/);

    expect(repoDecisaoCoordenador).toContain('runTransaction');
    expect(repoDecisaoCoordenador).toContain('reciboSnap.exists');
    expect(repoDecisaoCoordenador).toContain('payloadHash');
    // Fonte canônica única de autoridade (AD-2/AD-9).
    expect(repoDecisaoCoordenador).toContain("collection('autoridadesAdministrativas')");
    expect(repoDecisaoCoordenador).not.toContain("collection('coordenadores')");

    const auditoria = repoDecisaoCoordenador.match(/tx\.set\(auditoriaRef, \{([\s\S]*?)\n    \}\);/)?.[1];
    expect(auditoria).toBeDefined();
    expect(auditoria).not.toMatch(/cpf|nomeCompleto|email|justificativa/);

    expect(index).toContain('export { obterFilaCoordenador }');
    expect(index).toContain('export { decidirAtivacaoCoordenador }');
    expect(coordenadorService).toContain("httpsCallable('obterFilaCoordenador')");
    expect(coordenadorService).toContain("httpsCallable('decidirAtivacaoCoordenador')");
    expect(domainDecisaoCoordenador).toContain('MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA');
  });

  it('impõe imutabilidade estrita e isolamento privilegiado para auditoria, outbox e commands (AD-8, AD-9 e AD-12)', () => {
    // Regras do Firestore proíbem leitura e escrita direta de cliente em commands, auditOutbox, auditoria e alertasOperacionais
    expect(regras).toContain('match /commands/{commandId} {\n      allow read, write: if false;\n    }');
    expect(regras).toContain('match /auditOutbox/{commandId} {\n      allow read, write: if false;\n    }');
    expect(regras).toContain('match /auditoria/{commandId} {\n      allow read, write: if false;\n    }');
    expect(regras).toContain('match /alertasOperacionais/{alertaId} {\n      allow read, write: if false;\n    }');

    // Exports das rotinas privilegiadas de auditoria e reconciliação
    expect(index).toContain('export { processarAuditOutbox, reconciliarAuditoriaScheduled } from \'./triggers/auditoria.js\';');
    expect(index).toContain('export { reconciliarAuditoria } from \'./commands/reconciliarAuditoria.js\';');

    // Validação de segurança no comando de reconciliação
    const cmdReconciliar = readFileSync(join(raiz, 'functions', 'src', 'commands', 'reconciliarAuditoria.ts'), 'utf8');
    expect(cmdReconciliar).toContain('enforceAppCheck: true');
    expect(cmdReconciliar).toContain('if (!request.auth)');
    expect(cmdReconciliar).toContain('validarAutoridadeCoordenador');
  });

  it('impõe App Check, autoridade maanaimAdmin e inativação lógica sem exclusão física (Story 7.2)', () => {
    const cmdIgreja = readFileSync(join(raiz, 'functions', 'src', 'commands', 'alternarStatusIgreja.ts'), 'utf8');
    const cmdEquipe = readFileSync(join(raiz, 'functions', 'src', 'commands', 'alternarStatusEquipe.ts'), 'utf8');
    const repoStatusCatalogo = readFileSync(join(raiz, 'functions', 'src', 'repositories', 'statusCatalogo.ts'), 'utf8');

    expect(cmdIgreja).toContain('enforceAppCheck: true');
    expect(cmdIgreja).toContain('if (!request.auth)');
    expect(cmdIgreja).toContain('podeAdministrar(atorSnap.data())');

    expect(cmdEquipe).toContain('enforceAppCheck: true');
    expect(cmdEquipe).toContain('if (!request.auth)');
    expect(cmdEquipe).toContain('podeAdministrar(atorSnap.data())');

    expect(index).toContain('export { alternarStatusIgreja }');
    expect(index).toContain('export { alternarStatusEquipe }');

    // Repositório usa update atômico de status sem delete físico
    expect(repoStatusCatalogo).toContain('alternarStatusIgrejaRepo');
    expect(repoStatusCatalogo).toContain('alternarStatusEquipeRepo');
    expect(repoStatusCatalogo).toContain('tx.update(igrejaRef, {');
    expect(repoStatusCatalogo).toContain('tx.update(equipeRef, {');
  });
});


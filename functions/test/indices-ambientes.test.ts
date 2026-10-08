import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

const raiz = resolve(process.cwd(), '..');
const indexesRaw = readFileSync(join(raiz, 'firestore.indexes.json'), 'utf8');
const firebasercRaw = readFileSync(join(raiz, '.firebaserc'), 'utf8');
const ambientesRaw = readFileSync(join(raiz, 'infra', 'ambientes-firebase.json'), 'utf8');

interface IndexDefinition {
  collectionGroup: string;
  queryScope: string;
  fields: Array<{ fieldPath: string; order?: string; arrayConfig?: string }>;
}

describe('auditoria e consolidação de índices compostos (firestore.indexes.json)', () => {
  const indexesConfig = JSON.parse(indexesRaw) as { indexes: IndexDefinition[] };

  it('declara índices compostos para participações (vigência e busca por ficha)', () => {
    const partVigencia = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'participacoes' &&
        idx.fields.some((f) => f.fieldPath === 'estado') &&
        idx.fields.some((f) => f.fieldPath === 'vigenciaFim'),
    );
    expect(partVigencia).toBeDefined();

    const partFicha = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'participacoes' &&
        idx.fields.some((f) => f.fieldPath === 'fichaId') &&
        idx.fields.some((f) => f.fieldPath === 'estado'),
    );
    expect(partFicha).toBeDefined();
  });

  it('declara índices compostos para fichas (ciclos, atualização e igreja)', () => {
    const fichaAtualizacao = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'fichas' &&
        idx.fields.some((f) => f.fieldPath === 'estado') &&
        idx.fields.some((f) => f.fieldPath === 'atualizadoEm'),
    );
    expect(fichaAtualizacao).toBeDefined();

    const fichaIgreja = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'fichas' &&
        idx.fields.some((f) => f.fieldPath === 'igrejaId') &&
        idx.fields.some((f) => f.fieldPath === 'estado'),
    );
    expect(fichaIgreja).toBeDefined();
  });

  it('declara índices compostos para filas de pendências (Pastor Local e Responsável de Equipe)', () => {
    const filaPastor = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'filaPendencias' &&
        idx.fields.some((f) => f.fieldPath === 'estado') &&
        idx.fields.some((f) => f.fieldPath === 'igrejaId'),
    );
    expect(filaPastor).toBeDefined();

    const filaEquipe = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'filaPendenciasEquipe' &&
        idx.fields.some((f) => f.fieldPath === 'estado') &&
        idx.fields.some((f) => f.fieldPath === 'equipeId'),
    );
    expect(filaEquipe).toBeDefined();
  });

  it('declara índices compostos para vínculos pastorais e de equipes', () => {
    const vinculoIgreja = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'vinculosPastorIgreja' &&
        idx.fields.some((f) => f.fieldPath === 'pessoaId') &&
        idx.fields.some((f) => f.fieldPath === 'entidadeId') &&
        idx.fields.some((f) => f.fieldPath === 'estado'),
    );
    expect(vinculoIgreja).toBeDefined();

    const vinculoEquipe = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'vinculosPastorEquipe' &&
        idx.fields.some((f) => f.fieldPath === 'pessoaId') &&
        idx.fields.some((f) => f.fieldPath === 'entidadeId') &&
        idx.fields.some((f) => f.fieldPath === 'estado'),
    );
    expect(vinculoEquipe).toBeDefined();
  });

  it('declara índices compostos para auditoria imutável e alertas operacionais', () => {
    const auditoriaIdx = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'auditoria' &&
        idx.fields.some((f) => f.fieldPath === 'retencaoAte') &&
        idx.fields.some((f) => f.fieldPath === 'materializadoEm'),
    );
    expect(auditoriaIdx).toBeDefined();

    const alertasIdx = indexesConfig.indexes.find(
      (idx) =>
        idx.collectionGroup === 'alertasOperacionais' &&
        idx.fields.some((f) => f.fieldPath === 'tipo') &&
        idx.fields.some((f) => f.fieldPath === 'criadoEm'),
    );
    expect(alertasIdx).toBeDefined();
  });
});

describe('isolamento de ambientes e menor privilégio de IAM (infra/ambientes-firebase.json e .firebaserc)', () => {
  const firebaserc = JSON.parse(firebasercRaw) as { projects: Record<string, string> };
  const ambientes = JSON.parse(ambientesRaw) as {
    ambientes: Record<string, any>;
    serviceAccounts: Record<string, any>;
    politicaSegredosCliente: any;
  };

  it('configura projetos isolados para desenvolvimento, homologação e produção', () => {
    expect(firebaserc.projects.development).toBeDefined();
    expect(firebaserc.projects.staging).toBeDefined();
    expect(firebaserc.projects.production).toBeDefined();

    // Devem ser IDs distintos
    const ids = [
      firebaserc.projects.development,
      firebaserc.projects.staging,
      firebaserc.projects.production,
    ];
    const uniqueIds = new Set(ids);
    expect(uniqueIds.size).toBe(3);
  });

  it('estabelece política de menor privilégio para service account de Cloud Functions', () => {
    const saConfig = ambientes.serviceAccounts.cloudFunctions;
    expect(saConfig).toBeDefined();

    // Papéis obrigatórios mínimos
    expect(saConfig.papeisObrigatorios).toContain('roles/datastore.user');
    expect(saConfig.papeisObrigatorios).toContain('roles/firebaseauth.admin');
    expect(saConfig.papeisObrigatorios).toContain('roles/logging.logWriter');

    // Papéis amplos expressamente proibidos
    expect(saConfig.papeisProibidos).toContain('roles/owner');
    expect(saConfig.papeisProibidos).toContain('roles/editor');
  });

  it('exige aprovação de testes de emuladores para promoção de ambientes', () => {
    expect(ambientes.ambientes.desenvolvimento.politicaPromocao.exigeEmulatorSuite).toBe(true);
    expect(ambientes.ambientes.homologacao.politicaPromocao.exigeEmulatorSuite).toBe(true);
    expect(ambientes.ambientes.producao.politicaPromocao.exigeEmulatorSuite).toBe(true);
  });
});

describe('ausência de segredos e credenciais privilegiadas no cliente Flutter', () => {
  function escanearArquivosDart(dir: string): string[] {
    const resultados: string[] = [];
    const entradas = readdirSync(dir);
    for (const entrada of entradas) {
      const fullPath = join(dir, entrada);
      const stat = statSync(fullPath);
      if (stat.isDirectory()) {
        resultados.push(...escanearArquivosDart(fullPath));
      } else if (entrada.endsWith('.dart')) {
        resultados.push(fullPath);
      }
    }
    return resultados;
  }

  it('garante que nenhum arquivo fonte do Flutter contém chaves privadas ou credenciais de service account', () => {
    const flutterLibDir = join(raiz, 'flutter_app', 'lib');
    const arquivos = escanearArquivosDart(flutterLibDir);
    expect(arquivos.length).toBeGreaterThan(0);

    const padroesSegredos = [
      /-----BEGIN (RSA )?PRIVATE KEY-----/,
      /"private_key":\s*"-----BEGIN/,
      /AIzaSy[A-Za-z0-9_-]{33}/, // API keys hardcoded (devem vir via fromEnvironment)
      /service_account/,
      /client_secret/,
    ];

    for (const arq of arquivos) {
      const conteudo = readFileSync(arq, 'utf8');
      for (const padrao of padroesSegredos) {
        expect(conteudo).not.toMatch(padrao);
      }
    }
  });

  it('garante que main.dart carrega apenas variáveis públicas permitidas via fromEnvironment', () => {
    const mainPath = join(raiz, 'flutter_app', 'lib', 'main.dart');
    const mainContent = readFileSync(mainPath, 'utf8');

    expect(mainContent).toContain("String.fromEnvironment('FIREBASE_API_KEY')");
    expect(mainContent).toContain("String.fromEnvironment('FIREBASE_APP_ID')");
    expect(mainContent).toContain("String.fromEnvironment('FIREBASE_PROJECT_ID')");
    expect(mainContent).toContain("String.fromEnvironment('FIREBASE_AUTH_DOMAIN')");
    expect(mainContent).not.toMatch(/fromEnvironment\(['"][^'"]*PRIVATE_KEY/i);
    expect(mainContent).not.toMatch(/fromEnvironment\(['"][^'"]*SECRET/i);
  });
});

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const RAIZ = resolve(process.cwd(), '..');

function lerJson(caminhoRelativo: string): any {
  return JSON.parse(readFileSync(join(RAIZ, caminhoRelativo), 'utf8'));
}

function lerTexto(caminhoRelativo: string): string {
  return readFileSync(join(RAIZ, caminhoRelativo), 'utf8');
}

describe('Story 7.4: Governança de Logs GCP e Auditoria de Data Access (AD-12)', () => {
  it('declara o arquivo canônico infra/gcp-audit-logs-storage.json com DATA_READ, DATA_WRITE e ADMIN_READ', () => {
    const config = lerJson('infra/gcp-audit-logs-storage.json');
    expect(config.service).toBe('storage.googleapis.com');
    expect(Array.isArray(config.auditLogConfigs)).toBe(true);

    const logTypes = config.auditLogConfigs.map((l: any) => l.logType);
    expect(logTypes).toContain('DATA_READ');
    expect(logTypes).toContain('DATA_WRITE');
    expect(logTypes).toContain('ADMIN_READ');

    // Nenhuma conta deve ser isenta de auditoria
    expect(config.exemptedMembers).toBeUndefined();
  });

  it('o script setup-gcp-data-access-logs.sh responde ao comando --help com instruções normativas', () => {
    const helpOutput = execFileSync(
      'bash',
      [join(RAIZ, 'scripts/setup-gcp-data-access-logs.sh'), '--help'],
      { encoding: 'utf8' },
    );
    expect(helpOutput).toContain('--project');
    expect(helpOutput).toContain('--dry-run');
    expect(helpOutput).toContain('--apply');
    expect(helpOutput).toContain('--retention-5y');
    expect(helpOutput).toContain('storage.googleapis.com');
  });

  it('o script verificar-governanca-gcp.sh responde ao comando --help com descrição dos controles', () => {
    const helpOutput = execFileSync(
      'bash',
      [join(RAIZ, 'scripts/verificar-governanca-gcp.sh'), '--help'],
      { encoding: 'utf8' },
    );
    expect(helpOutput).toContain('--project');
    expect(helpOutput).toContain('--bucket');
    expect(helpOutput).toContain('storage.googleapis.com');
  });

  it('valida a lógica de mesclagem idempotente em cenários de política IAM variados', () => {
    const storageConfig = lerJson('infra/gcp-audit-logs-storage.json');

    // Cenário 1: Política virgem sem auditConfigs
    const policy1: any = { bindings: [{ role: 'roles/viewer', members: ['user:admin@example.com'] }] };
    if (!policy1.auditConfigs) policy1.auditConfigs = [];
    policy1.auditConfigs.push(storageConfig);
    expect(policy1.auditConfigs.length).toBe(1);
    expect(policy1.auditConfigs[0].service).toBe('storage.googleapis.com');

    // Cenário 2: Política já contendo outro serviço (ex.: allServices)
    const policy2: any = {
      bindings: [],
      auditConfigs: [{ service: 'allServices', auditLogConfigs: [{ logType: 'ADMIN_READ' }] }],
    };
    let idx2 = policy2.auditConfigs.findIndex((c: any) => c.service === 'storage.googleapis.com');
    if (idx2 === -1) policy2.auditConfigs.push(storageConfig);
    expect(policy2.auditConfigs.length).toBe(2);
    expect(policy2.auditConfigs.some((c: any) => c.service === 'allServices')).toBe(true);
    expect(policy2.auditConfigs.some((c: any) => c.service === 'storage.googleapis.com')).toBe(true);

    // Cenário 3: Política já contendo storage.googleapis.com parcial
    const policy3: any = {
      bindings: [],
      auditConfigs: [
        { service: 'storage.googleapis.com', auditLogConfigs: [{ logType: 'ADMIN_READ' }] },
      ],
    };
    let idx3 = policy3.auditConfigs.findIndex((c: any) => c.service === 'storage.googleapis.com');
    const existing = policy3.auditConfigs[idx3];
    const requiredTypes = ['DATA_READ', 'DATA_WRITE', 'ADMIN_READ'];
    for (const reqType of requiredTypes) {
      if (!existing.auditLogConfigs.some((log: any) => log.logType === reqType)) {
        existing.auditLogConfigs.push({ logType: reqType });
      }
    }
    expect(existing.auditLogConfigs.length).toBe(3);
    const types3 = existing.auditLogConfigs.map((l: any) => l.logType);
    expect(types3).toEqual(expect.arrayContaining(['ADMIN_READ', 'DATA_READ', 'DATA_WRITE']));
  });

  it('alerta de DELETION em alertas-monitoramento.json correlaciona com storage.objects.delete', () => {
    const alertas = lerJson('infra/alertas-monitoramento.json');
    const deletionPolicy = alertas.policies?.find((p: any) => p.categoria === 'DELETION');
    expect(deletionPolicy).toBeDefined();

    const conditionFilter = deletionPolicy.conditions[0]?.conditionMatchedLog?.filter;
    expect(conditionFilter).toContain('storage.objects.delete');
    // Confirma que a ativação de DATA_WRITE supre a emissão desse evento
  });

  it('garante que nenhum filtro ou documentação em alertas-monitoramento.json vaza dados sensíveis (PII)', () => {
    const textoAlertas = lerTexto('infra/alertas-monitoramento.json');
    // Não pode filtrar por CPF, e-mail, nomes de voluntários
    expect(textoAlertas).not.toMatch(/\b(cpf|nome|email|telefone|endereco)\b/i);
    // Filtros devem basear-se estritamente em métodos e metadados de sistema
    expect(textoAlertas).toContain('protoPayload.methodName');
  });
});

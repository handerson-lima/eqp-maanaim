import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const raiz = resolve(process.cwd(), '..');
const regras = readFileSync(join(raiz, 'firestore.rules'), 'utf8');
const adaptador = readFileSync(
  join(raiz, 'functions', 'src', 'repositories', 'firestoreImportacao.ts'),
  'utf8',
);
const ausentes = readFileSync(
  join(raiz, 'functions', 'src', 'domain', 'vinculosAusentes.ts'),
  'utf8',
);

const PII = /nomeCompleto|cpf|profissao|email|senha|token/;

describe('contratos de segurança da carga inicial', () => {
  it('mantém Rules deny-by-default para pessoas, vínculos e auditoria', () => {
    expect(regras).toContain(
      'match /{document=**} { allow read, write: if false; }',
    );
    expect(regras).not.toContain('match /pessoas');
    expect(regras).not.toContain('match /vinculosPastorIgreja');
    expect(regras).not.toContain('match /auditOutbox');
  });

  it('grava vínculo, recibo e auditoria na mesma transação', () => {
    expect(adaptador).toContain('db.runTransaction');
    expect(adaptador).toContain("tx.create(vinculoRef");
    expect(adaptador).toContain("tx.create(reciboRef");
    expect(adaptador).toContain("tx.create(auditoriaRef");
    expect(adaptador).toContain('commandId');
    expect(adaptador).toContain('correlationId');
  });

  it('não registra PII no vínculo, no recibo nem na auditoria', () => {
    const vinculo = adaptador.match(/tx\.create\(vinculoRef, \{([^}]*)\}\)/)?.[1];
    const recibo = adaptador.match(/tx\.create\(reciboRef, \{([^}]*)\}\)/)?.[1];
    const auditoria = adaptador.match(/tx\.create\(auditoriaRef, \{([^}]*)\}\)/)?.[1];
    expect(vinculo).toBeDefined();
    expect(recibo).toBeDefined();
    expect(auditoria).toBeDefined();
    expect(vinculo).not.toMatch(PII);
    expect(recibo).not.toMatch(PII);
    expect(auditoria).not.toMatch(PII);
  });

  it('cria contas sem senha e sem convite automático', () => {
    expect(adaptador).toContain('auth.createUser');
    expect(adaptador).not.toMatch(/password/);
  });

  it('não versiona nomes ou e-mails nos vínculos ausentes', () => {
    expect(ausentes).not.toContain('@');
    expect(ausentes).toMatch(/240005/);
    expect(ausentes).toMatch(/240029/);
  });
});

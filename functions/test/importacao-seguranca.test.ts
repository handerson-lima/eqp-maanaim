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

/** Extrai o objeto de um `tx.create(...)` com chaves balanceadas (sem truncar em `}`). */
function extrairCorpo(fonte: string, marcador: string): string | null {
  const inicio = fonte.indexOf(marcador);
  if (inicio < 0) return null;
  const abre = fonte.indexOf('{', inicio);
  if (abre < 0) return null;
  let profundidade = 0;
  for (let i = abre; i < fonte.length; i += 1) {
    const caractere = fonte[i];
    if (caractere === '{') profundidade += 1;
    else if (caractere === '}') {
      profundidade -= 1;
      if (profundidade === 0) return fonte.slice(abre, i + 1);
    }
  }
  return null;
}

describe('contratos de segurança da carga inicial', () => {
  it('só permite as leituras mínimas ou negação explícita; o resto cai no deny global', () => {
    // Prova estrutural: toda instrução `allow` do arquivo é uma das permitidas.
    const permissivas = regras.match(/allow\s+[^;]*;/g) ?? [];
    expect(permissivas.length).toBeGreaterThan(0);
    for (const regra of permissivas) {
      expect([
        'allow get, list: if resource.data.ativo == true;',
        'allow write: if false;',
        'allow read, write: if false;',
      ]).toContain(regra.replace(/\s+/g, ' ').trim());
    }
    // O catch-all nega por padrão pessoas, vínculos, recibos e auditoria.
    expect(regras).toContain(
      'match /{document=**} { allow read, write: if false; }',
    );
    // Nenhuma regra concede acesso condicionado a autenticação (que poderia
    // abrir uma coleção de domínio).
    expect(regras).not.toMatch(/allow\s+[^;]*request\.auth/);
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
    const vinculo = extrairCorpo(adaptador, 'tx.create(vinculoRef');
    const recibo = extrairCorpo(adaptador, 'tx.create(reciboRef');
    const auditoria = extrairCorpo(adaptador, 'tx.create(auditoriaRef');
    expect(vinculo).not.toBeNull();
    expect(recibo).not.toBeNull();
    expect(auditoria).not.toBeNull();
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

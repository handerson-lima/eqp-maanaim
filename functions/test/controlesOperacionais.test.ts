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

describe('Story 6.4: Controles operacionais, índices e regras (AD-12)', () => {
  it('declara o índice composto fichas(estado, atualizadoEm)', () => {
    const indexes = lerJson('firestore.indexes.json');
    const indice = (indexes.indexes ?? []).find(
      (i: any) =>
        i.collectionGroup === 'fichas' &&
        i.fields?.some((f: any) => f.fieldPath === 'estado') &&
        i.fields?.some((f: any) => f.fieldPath === 'atualizadoEm'),
    );
    expect(indice).toBeDefined();
  });

  it('aplica retenção de 5 anos via lifecycle, sem lock irreversível', () => {
    const lifecycle = lerJson('infra/storage-lifecycle.json');
    const regra = (lifecycle.rule ?? []).find(
      (r: any) =>
        r.action?.type === 'Delete' &&
        r.condition?.age >= 1825 &&
        // A regra cobre os PDFs privados do bucket.
        (r.condition?.matchesPrefix ?? []).some((p: string) => p.startsWith('pdfs')),
    );
    expect(regra).toBeDefined();

    const bruto = JSON.stringify(lifecycle);
    expect(bruto).not.toContain('retentionPolicy');
    expect(bruto).not.toContain('isLocked');
  });

  it('declara alertas de IAM, Rules, conta de serviço, deleção e falha de backup', () => {
    const alertas = lerJson('infra/alertas-monitoramento.json');
    const categorias = new Set((alertas.policies ?? []).map((p: any) => p.categoria));
    expect(categorias.has('IAM')).toBe(true);
    expect(categorias.has('RULES')).toBe(true);
    expect(categorias.has('SERVICE_ACCOUNT')).toBe(true);
    expect(categorias.has('DELETION')).toBe(true);
    expect(categorias.has('BACKUP_FAILURE')).toBe(true);
  });

  it('mantém Firestore e Storage negando escrita e delete do cliente', () => {
    const firestoreRules = lerTexto('firestore.rules');
    const storageRules = lerTexto('storage.rules');
    expect(firestoreRules).toContain('allow write: if false');
    expect(firestoreRules).not.toMatch(/allow\s+[\w,\s]*delete/i);
    expect(storageRules).toContain('allow read, write: if false');
    expect(storageRules).not.toMatch(/allow\s+delete/i);
  });

  it('o script de controles operacionais apenas imprime comandos sem --executar', () => {
    const saida = execFileSync(
      'node',
      [
        join(RAIZ, 'scripts/aplicar-controles-operacionais.mjs'),
        '--projeto',
        'projeto-teste',
      ],
      { encoding: 'utf8' },
    );
    expect(saida).toContain('gcloud storage buckets update');
    expect(saida).toContain('gcloud monitoring policies create');
    expect(saida).toContain('Nada foi alterado');
  });
});

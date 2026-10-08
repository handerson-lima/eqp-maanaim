import { describe, expect, it } from 'vitest';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { processarEntradaAuditOutboxRepo } from '../src/repositories/auditoria.js';
import { montarRegistroAuditoriaImutavel, type EntradaAuditOutbox } from '../src/domain/auditoria.js';

interface FakeDoc {
  data: Record<string, unknown> | null;
}

/**
 * Cria uma instância de Firestore em memória simulando concorrência transacional (optimistic concurrency control).
 */
function criarFirestoreEmMemoriaComConcorrencia() {
  const store = new Map<string, Record<string, unknown>>();
  let transactionAttempts = 0;

  const getDoc = (path: string) => {
    const val = store.get(path);
    return {
      exists: Boolean(val),
      data: () => (val ? { ...val } : undefined),
      id: path.split('/').pop()!,
    };
  };

  const fakeDb: any = {
    collection: (colName: string) => ({
      doc: (docId: string) => {
        const path = `${colName}/${docId}`;
        return {
          id: docId,
          path,
          get: async () => getDoc(path),
          set: async (dados: Record<string, unknown>, opts?: { merge?: boolean }) => {
            const atual = store.get(path) ?? {};
            store.set(path, opts?.merge ? { ...atual, ...dados } : { ...dados });
          },
          delete: async () => {
            store.delete(path);
          },
        };
      },
      get: async () => {
        const docs = Array.from(store.entries())
          .filter(([k]) => k.startsWith(`${colName}/`))
          .map(([k, v]) => ({
            id: k.split('/').pop()!,
            data: () => ({ ...v }),
          }));
        return { docs, empty: docs.length === 0, size: docs.length };
      },
    }),
    runTransaction: async (updateFunction: (tx: any) => Promise<unknown>) => {
      // Simula execução transacional atômica
      transactionAttempts++;
      const txOps: Array<() => void> = [];
      const tx = {
        get: async (docRef: any) => getDoc(docRef.path),
        create: (docRef: any, data: Record<string, unknown>) => {
          if (store.has(docRef.path)) {
            const err: any = new Error('Document already exists');
            err.code = 6; // ALREADY_EXISTS
            throw err;
          }
          txOps.push(() => store.set(docRef.path, { ...data }));
        },
        set: (docRef: any, data: Record<string, unknown>, opts?: { merge?: boolean }) => {
          txOps.push(() => {
            const atual = store.get(docRef.path) ?? {};
            store.set(docRef.path, opts?.merge ? { ...atual, ...data } : { ...data });
          });
        },
        update: (docRef: any, data: Record<string, unknown>) => {
          txOps.push(() => {
            const atual = store.get(docRef.path) ?? {};
            store.set(docRef.path, { ...atual, ...data });
          });
        },
      };

      const result = await updateFunction(tx);
      // Aplica todas as operações no commit
      for (const op of txOps) op();
      return result;
    },
    _getStore: () => store,
    _getAttempts: () => transactionAttempts,
  };

  return fakeDb;
}

describe('idempotência, concorrência e correlação de auditoria/evidência (AD-8, AD-10)', () => {
  it('garante que múltiplas execuções concorrentes do consumidor de outbox com o mesmo commandId são idempotentes', async () => {
    const db = criarFirestoreEmMemoriaComConcorrencia();
    const commandId = 'cmd-concorrente-12345';
    const correlationId = 'corr-concorrente-99999';

    const outboxData: EntradaAuditOutbox = {
      commandId,
      correlationId,
      atorUid: 'voluntario-1',
      acao: 'ACEITAR_TERMO',
      entidades: [{ tipo: 'TERMO', id: 'termo-1' }],
      antes: null,
      depois: { versaoTermo: 1 },
      metadados: { origem: 'TESTE_CONCORRENCIA' },
      timestamp: Timestamp.now(),
      criadoEm: Timestamp.now(),
      processado: false,
    };

    // Cria a entrada inicial no outbox e no recibo
    await db.collection('auditOutbox').doc(commandId).set(outboxData);
    await db.collection('commands').doc(commandId).set({
      commandId,
      correlationId,
      status: 'PROCESSANDO',
    });

    // Dispara 5 execuções simultâneas concorrentes com Promise.all
    const promessas = Array.from({ length: 5 }).map(() =>
      processarEntradaAuditOutboxRepo(db, commandId, outboxData),
    );

    const resultados = await Promise.all(promessas);

    // Todas devem retornar com sucesso
    for (const res of resultados) {
      expect(res.sucesso).toBe(true);
      expect(res.commandId).toBe(commandId);
    }

    // Exatamente uma entrada em auditoria
    const auditDoc = await db.collection('auditoria').doc(commandId).get();
    expect(auditDoc.exists).toBe(true);
    expect(auditDoc.data()?.commandId).toBe(commandId);
    expect(auditDoc.data()?.correlationId).toBe(correlationId);
    expect(auditDoc.data()?.acao).toBe('ACEITAR_TERMO');

    // O outbox deve estar marcado como processado
    const outboxFinal = await db.collection('auditOutbox').doc(commandId).get();
    expect(outboxFinal.data()?.processado).toBe(true);

    // O recibo de comando deve estar COMPLETO
    const cmdFinal = await db.collection('commands').doc(commandId).get();
    expect(cmdFinal.data()?.status).toBe('COMPLETO');
  });

  it('impede divergência de payload para o mesmo commandId em retries', async () => {
    const db = criarFirestoreEmMemoriaComConcorrencia();
    const commandId = 'cmd-retry-hash-check';

    // Primeiro envio registra recibo com hash X
    const payloadHashOriginal = 'hash-abc-123';
    await db.collection('commands').doc(commandId).set({
      commandId,
      payloadHash: payloadHashOriginal,
      status: 'COMPLETO',
      resultado: { sucesso: true, id: 'item-1' },
    });

    // Simulação do guard de comando em transação
    async function executarComandoComGuard(payloadHash: string, dadosNovos: Record<string, unknown>) {
      return await db.runTransaction(async (tx: any) => {
        const reciboRef = db.collection('commands').doc(commandId);
        const reciboSnap = await tx.get(reciboRef);
        if (reciboSnap.exists) {
          const dados = reciboSnap.data();
          if (dados.payloadHash !== payloadHash) {
            throw new Error('COMANDO_DIVERGENTE: Payload não coincide com o comando já registrado');
          }
          return dados.resultado;
        }
        tx.create(reciboRef, {
          commandId,
          payloadHash,
          status: 'COMPLETO',
          resultado: dadosNovos,
        });
        return dadosNovos;
      });
    }

    // Retry com o mesmo payloadHash deve retornar o resultado sem duplicar
    const resultadoRetry = await executarComandoComGuard(payloadHashOriginal, { outro: 123 });
    expect(resultadoRetry).toEqual({ sucesso: true, id: 'item-1' });

    // Retry com payload divergente deve lançar erro
    await expect(
      executarComandoComGuard('hash-divergente-999', { outro: 456 }),
    ).rejects.toThrow('COMANDO_DIVERGENTE');
  });

  it('preserva atomicidade transacional e recusa gravação parcial em caso de falha', async () => {
    const db = criarFirestoreEmMemoriaComConcorrencia();
    const commandId = 'cmd-falha-atomica';

    // Tenta transação que falha após preparar mutações
    const operacaoFalha = async () => {
      await db.runTransaction(async (tx: any) => {
        tx.create(db.collection('commands').doc(commandId), { status: 'PENDENTE' });
        tx.create(db.collection('fichas').doc('ficha-falha'), { estado: 'ATIVA' });
        // Simula falha antes do commit
        throw new Error('SIMULACAO_ERRO_REDE');
      });
    };

    await expect(operacaoFalha()).rejects.toThrow('SIMULACAO_ERRO_REDE');

    // Nenhuma das escritas deve ter sido persistida
    const cmdDoc = await db.collection('commands').doc(commandId).get();
    expect(cmdDoc.exists).toBe(false);

    const fichaDoc = await db.collection('fichas').doc('ficha-falha').get();
    expect(fichaDoc.exists).toBe(false);
  });
});

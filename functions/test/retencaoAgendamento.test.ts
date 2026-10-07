import { describe, expect, it, vi } from 'vitest';
import {
  executarExpurgoRascunhosAgendado,
  semanaIso,
} from '../src/triggers/expurgarRascunhosGate.js';

describe('Story 6.4: semana ISO do job de expurgo', () => {
  it('resolve fronteiras de virada de ano ISO sem pular nem duplicar semanas', () => {
    expect(semanaIso(new Date('2026-01-01T00:00:00.000Z'))).toBe('2026-W01');
    expect(semanaIso(new Date('2025-12-29T00:00:00.000Z'))).toBe('2026-W01');
    expect(semanaIso(new Date('2024-12-30T00:00:00.000Z'))).toBe('2025-W01');
    expect(semanaIso(new Date('2021-01-01T00:00:00.000Z'))).toBe('2020-W53');
    expect(semanaIso(new Date('2021-01-04T00:00:00.000Z'))).toBe('2021-W01');
    expect(semanaIso(new Date('2023-01-01T00:00:00.000Z'))).toBe('2022-W52');
    expect(semanaIso(new Date('2023-01-02T00:00:00.000Z'))).toBe('2023-W01');
  });
});

describe('Story 6.4: gate do expurgo agendado (AD-12)', () => {
  const db = {} as never;

  it('não executa nenhum expurgo quando desabilitado/padrão', async () => {
    const executarRotina = vi.fn();
    const resultado = await executarExpurgoRascunhosAgendado(
      db,
      new Date('2026-10-07T12:00:00.000Z'),
      {
        obterConfiguracao: async () => ({
          diasRascunho: 180,
          expurgoAutomaticoHabilitado: false,
        }),
        executarRotina,
      },
    );

    expect(resultado.executado).toBe(false);
    expect(executarRotina).not.toHaveBeenCalled();
  });

  it('executa com somenteExpurgo=true quando habilitado', async () => {
    const executarRotina = vi.fn(async (_db: unknown, _entrada: unknown) => ({}));
    const agora = new Date('2026-10-07T12:00:00.000Z');

    const resultado = await executarExpurgoRascunhosAgendado(db, agora, {
      obterConfiguracao: async () => ({
        diasRascunho: 180,
        expurgoAutomaticoHabilitado: true,
      }),
      executarRotina,
    });

    expect(resultado.executado).toBe(true);
    expect(executarRotina).toHaveBeenCalledTimes(1);
    const entrada = executarRotina.mock.calls[0]?.[1] as {
      commandId: string;
      dryRun: boolean;
      somenteExpurgo?: boolean;
    };
    expect(entrada.commandId).toBe(`job_retencao_rascunho_${semanaIso(agora)}`);
    expect(entrada.commandId).toBe('job_retencao_rascunho_2026-W41');
    expect(entrada.dryRun).toBe(false);
    expect(entrada.somenteExpurgo).toBe(true);
  });
});

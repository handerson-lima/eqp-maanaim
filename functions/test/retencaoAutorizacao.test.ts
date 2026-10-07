import { beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * Cobertura das linhas da matriz AD-12 que dependem da borda (callable):
 * - "Sem papel" → `permission-denied` sem detalhes.
 * - "PDF de ficha anonimizada" → `failed-precondition`.
 *
 * Estas páginas mockam as dependências de borda para exercitar exclusivamente o
 * mapeamento de autorização/erro sem tocar em Firestore real.
 */
const mocks = vi.hoisted(() => ({
  validarAutoridade: vi.fn(),
  gerarPdfRepo: vi.fn(),
  obterUrlRepo: vi.fn(),
  getFirestore: vi.fn(() => ({})),
}));

vi.mock('../src/repositories/decisaoCoordenador.js', () => ({
  validarAutoridadeCoordenador: mocks.validarAutoridade,
}));

vi.mock('../src/repositories/pdfTermo.js', () => ({
  gerarPdfParticipacaoRepo: mocks.gerarPdfRepo,
  obterUrlDownloadPdfRepo: mocks.obterUrlRepo,
}));

vi.mock('firebase-admin/firestore', () => ({
  getFirestore: mocks.getFirestore,
  FieldValue: { serverTimestamp: () => ({ __serverTimestamp: true }) },
  Timestamp: {
    fromDate: (data: Date) => data,
    fromMillis: (ms: number) => new Date(ms),
  },
}));

import { FichaAnonimizadaParaPdfError } from '../src/domain/pdfTermo.js';
import { consultarConformidadeRetencao } from '../src/commands/consultarConformidadeRetencao.js';
import { executarRotinaRetencao } from '../src/commands/executarRotinaRetencao.js';
import { gerarPdfParticipacao } from '../src/commands/gerarPdfParticipacao.js';
import { obterUrlDownloadPdf } from '../src/commands/obterUrlDownloadPdf.js';

function executar(comando: unknown): (dados: unknown) => Promise<unknown> {
  return (comando as { run: (dados: unknown) => Promise<unknown> }).run;
}

describe('Story 6.4: Matriz — autorização e recusa na borda (AD-12)', () => {
  beforeEach(() => {
    mocks.validarAutoridade.mockReset();
    mocks.gerarPdfRepo.mockReset();
    mocks.obterUrlRepo.mockReset();
  });

  it('executarRotinaRetencao nega usuário sem papel com permission-denied', async () => {
    mocks.validarAutoridade.mockResolvedValue({
      autorizado: false,
      nome: 'Desconhecido',
      papel: '',
      autoridadeVersao: 0,
    });

    await expect(
      executar(executarRotinaRetencao)({
        auth: { uid: 'uid-sem-papel' },
        data: { commandId: 'cmd-retencao-sem-papel' },
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });

    expect(mocks.validarAutoridade).toHaveBeenCalledTimes(1);
  });

  it('consultarConformidadeRetencao nega usuário sem papel com permission-denied', async () => {
    mocks.validarAutoridade.mockResolvedValue({
      autorizado: false,
      nome: 'Desconhecido',
      papel: '',
      autoridadeVersao: 0,
    });

    await expect(
      executar(consultarConformidadeRetencao)({
        auth: { uid: 'uid-sem-papel' },
        data: {},
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('gerarPdfParticipacao recusa ficha anonimizada com failed-precondition', async () => {
    mocks.gerarPdfRepo.mockRejectedValue(new FichaAnonimizadaParaPdfError());

    await expect(
      executar(gerarPdfParticipacao)({
        auth: { uid: 'uid-voluntario' },
        data: { fichaId: 'ficha-anon', participacaoId: 'part-1' },
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('obterUrlDownloadPdf recusa ficha anonimizada com failed-precondition', async () => {
    mocks.obterUrlRepo.mockRejectedValue(new FichaAnonimizadaParaPdfError());

    await expect(
      executar(obterUrlDownloadPdf)({
        auth: { uid: 'uid-voluntario' },
        data: { fichaId: 'ficha-anon', participacaoId: 'part-1' },
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});

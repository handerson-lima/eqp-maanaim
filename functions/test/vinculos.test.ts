import { describe, expect, it } from 'vitest';
import {
  ACOES_VINCULO,
  ConflitoVersaoError,
  DataInvalidaError,
  EntidadeInexistenteError,
  OperacaoInvalidaError,
  SobreposicaoError,
  VigenteExistenteError,
  VinculoInexistenteError,
  camposVigente,
  dataEfetivaEmMs,
  hashVinculo,
  papelDoTipo,
  planejarVinculo,
  validarVinculo,
  type AcaoVinculo,
  type EntradaVinculo,
} from '../src/domain/vinculos.js';

const base = {
  commandId: 'a'.repeat(32),
  tipoEntidade: 'IGREJA',
  entidadeId: 'ig-opaca-1',
  acao: 'ATRIBUIR',
  pessoaId: 'pessoa-opaca-1',
  dataEfetiva: '2026-01-10',
  expectedVersion: 0,
};

const AGORA = Date.UTC(2026, 8, 30);

function entrada(extra: Record<string, unknown> = {}): EntradaVinculo {
  return validarVinculo({ ...base, ...extra });
}

function entidade(
  extra: Partial<{
    ativo: boolean;
    vigente: { vinculoId: string; pessoaId: string; inicioVigenciaMs: number | null } | null;
    versaoVinculo: number;
  }> = {},
) {
  return {
    ativo: true,
    vigente: null,
    versaoVinculo: 0,
    ...extra,
  };
}

describe('catálogo de vínculos', () => {
  it('mapeia papel e campos canônicos por tipo de entidade', () => {
    expect(papelDoTipo('IGREJA')).toBe('PASTOR_LOCAL');
    expect(papelDoTipo('EQUIPE')).toBe('PASTOR_EQUIPE');
    expect(camposVigente('IGREJA')).toMatchObject({
      colecao: 'igrejas',
      colecaoVinculos: 'vinculosPastorIgreja',
      pessoa: 'pastorLocalVigentePessoaId',
      vinculo: 'pastorLocalVigenteVinculoId',
    });
    expect(camposVigente('EQUIPE')).toMatchObject({
      colecao: 'equipes',
      colecaoVinculos: 'vinculosPastorEquipe',
      pessoa: 'responsavelVigentePessoaId',
      vinculo: 'responsavelVigenteVinculoId',
    });
  });
});

describe('validação de data efetiva', () => {
  it('aceita datas reais e recusa calendário/formatos inválidos', () => {
    expect(dataEfetivaEmMs('2026-01-10')).toBe(Date.UTC(2026, 0, 10));
    expect(dataEfetivaEmMs('2026-02-30')).toBeNull();
    expect(dataEfetivaEmMs('2026-13-01')).toBeNull();
    expect(dataEfetivaEmMs('10/01/2026')).toBeNull();
    expect(dataEfetivaEmMs('2026-1-10')).toBeNull();
  });
});

describe('contrato do comando de vínculo', () => {
  it('aceita apenas os campos permitidos e normaliza a data', () => {
    const e = entrada({ justificativa: '' });
    expect(e.dataEfetivaMs).toBe(Date.UTC(2026, 0, 10));
    expect(e.pessoaId).toBe('pessoa-opaca-1');
    expect(e.justificativa).toBeNull();
    expect(e.payloadHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('recusa campos fora do contrato e identificadores inválidos', () => {
    expect(() => validarVinculo({ ...base, extra: true })).toThrow('VINCULO_INVALIDO');
    expect(() => validarVinculo({ ...base, commandId: 'curto' })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, tipoEntidade: 'FICHA' })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, acao: 'RENOVAR' })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, entidadeId: 'id com espaço' })).toThrow(
      'VINCULO_INVALIDO',
    );
  });

  it('exige pessoa em ATRIBUIR/SUBSTITUIR e proíbe em ENCERRAR', () => {
    expect(() => validarVinculo({ ...base, pessoaId: undefined })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, acao: 'ENCERRAR' })).toThrow(
      'VINCULO_INVALIDO',
    );
    const encerrar = validarVinculo({ ...base, acao: 'ENCERRAR', pessoaId: undefined });
    expect(encerrar.pessoaId).toBeNull();
    const substituir = validarVinculo({ ...base, acao: 'SUBSTITUIR' });
    expect(substituir.pessoaId).toBe('pessoa-opaca-1');
  });

  it('recusa data inválida, versão inválida e justificativa abusiva', () => {
    expect(() => validarVinculo({ ...base, dataEfetiva: '2026-02-30' })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, expectedVersion: -1 })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, expectedVersion: 1.5 })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, expectedVersion: '0' })).toThrow(
      'VINCULO_INVALIDO',
    );
    expect(() => validarVinculo({ ...base, justificativa: 'x'.repeat(501) })).toThrow(
      'VINCULO_INVALIDO',
    );
  });

  it('liga o recibo ao conteúdo sem persistir PII', () => {
    const e = entrada();
    expect(hashVinculo(e)).toBe(e.payloadHash);
    expect(e.payloadHash).toMatch(/^[0-9a-f]{64}$/);
    expect(
      hashVinculo(entrada({ acao: 'SUBSTITUIR' })),
    ).not.toBe(e.payloadHash);
    expect(hashVinculo(entrada({ dataEfetiva: '2026-01-11' }))).not.toBe(
      e.payloadHash,
    );
    expect(hashVinculo(entrada({ expectedVersion: 1 }))).not.toBe(e.payloadHash);
    expect(hashVinculo(entrada({ justificativa: 'motivo' }))).not.toBe(
      e.payloadHash,
    );
    expect(
      hashVinculo(entrada({ correlationId: 'c'.repeat(32) })),
    ).not.toBe(e.payloadHash);
  });
});

describe('planejamento temporal', () => {
  it('atribui quando não há responsável vigente e aceita data passada', () => {
    const plano = planejarVinculo(entrada(), entidade(), AGORA);
    expect(plano.encerrarVinculoId).toBeNull();
    expect(plano.criar).toEqual({
      pessoaId: 'pessoa-opaca-1',
      inicioVigenciaMs: Date.UTC(2026, 0, 10),
    });
  });

  it('recusa atribuir quando já existe vigente ou quando é a mesma pessoa', () => {
    const vigente = {
      vinculoId: 'v-1',
      pessoaId: 'outra-pessoa',
      inicioVigenciaMs: Date.UTC(2026, 0, 1),
    };
    expect(() => planejarVinculo(entrada(), entidade({ vigente }), AGORA)).toThrow(
      VigenteExistenteError,
    );
    expect(() =>
      planejarVinculo(
        entrada(),
        entidade({ vigente: { ...vigente, pessoaId: 'pessoa-opaca-1' } }),
        AGORA,
      ),
    ).toThrow(OperacaoInvalidaError);
    expect(() =>
      planejarVinculo(
        entrada({ acao: 'SUBSTITUIR' }),
        entidade({ vigente: { ...vigente, pessoaId: 'pessoa-opaca-1' } }),
        AGORA,
      ),
    ).toThrow(OperacaoInvalidaError);
  });

  it('substitui encerrando o anterior e abrindo o novo sem sobreposição', () => {
    const vigente = {
      vinculoId: 'v-1',
      pessoaId: 'outra-pessoa',
      inicioVigenciaMs: Date.UTC(2026, 0, 1),
    };
    const plano = planejarVinculo(
      entrada({ acao: 'SUBSTITUIR', expectedVersion: 3 }),
      entidade({ vigente, versaoVinculo: 3 }),
      AGORA,
    );
    expect(plano.encerrarVinculoId).toBe('v-1');
    expect(plano.fimVigenciaMs).toBe(plano.criar?.inicioVigenciaMs);
    expect(plano.criar).toEqual({
      pessoaId: 'pessoa-opaca-1',
      inicioVigenciaMs: Date.UTC(2026, 0, 10),
    });
  });

  it('encerra o vínculo vigente com o fim igual à data efetiva', () => {
    const vigente = {
      vinculoId: 'v-1',
      pessoaId: 'outra-pessoa',
      inicioVigenciaMs: Date.UTC(2026, 0, 1),
    };
    const plano = planejarVinculo(
      entrada({ acao: 'ENCERRAR', pessoaId: undefined, expectedVersion: 2 }),
      entidade({ vigente, versaoVinculo: 2 }),
      AGORA,
    );
    expect(plano.encerrarVinculoId).toBe('v-1');
    expect(plano.fimVigenciaMs).toBe(Date.UTC(2026, 0, 10));
    expect(plano.criar).toBeNull();
  });

  it('recusa encerrar/substituir sem vínculo vigente', () => {
    expect(() =>
      planejarVinculo(entrada({ acao: 'ENCERRAR', pessoaId: undefined }), entidade(), AGORA),
    ).toThrow(VinculoInexistenteError);
    expect(() =>
      planejarVinculo(entrada({ acao: 'SUBSTITUIR' }), entidade(), AGORA),
    ).toThrow(VinculoInexistenteError);
  });

  it('recusa data futura e retroatividade que encerre antes do início', () => {
    expect(() =>
      planejarVinculo(entrada({ dataEfetiva: '2099-01-01' }), entidade(), AGORA),
    ).toThrow(DataInvalidaError);
    const vigente = {
      vinculoId: 'v-1',
      pessoaId: 'outra-pessoa',
      inicioVigenciaMs: Date.UTC(2026, 5, 1),
    };
    expect(() =>
      planejarVinculo(
        entrada({ acao: 'ENCERRAR', pessoaId: undefined, dataEfetiva: '2026-01-01' }),
        entidade({ vigente }),
        AGORA,
      ),
    ).toThrow(SobreposicaoError);
    expect(() =>
      planejarVinculo(
        entrada({ acao: 'SUBSTITUIR', dataEfetiva: '2026-01-01' }),
        entidade({ vigente }),
        AGORA,
      ),
    ).toThrow(SobreposicaoError);
  });

  it('recusa versão divergente e entidade inativa', () => {
    expect(() =>
      planejarVinculo(entrada({ expectedVersion: 5 }), entidade({ versaoVinculo: 1 }), AGORA),
    ).toThrow(ConflitoVersaoError);
    expect(() =>
      planejarVinculo(entrada(), entidade({ ativo: false }), AGORA),
    ).toThrow(EntidadeInexistenteError);
  });

  it('trata vínculo legado sem timestamp como vigente e substituível', () => {
    const plano = planejarVinculo(
      entrada({ acao: 'ENCERRAR', pessoaId: undefined }),
      entidade({
        vigente: { vinculoId: 'v-legado', pessoaId: 'pessoa-legada', inicioVigenciaMs: null },
      }),
      AGORA,
    );
    expect(plano.encerrarVinculoId).toBe('v-legado');
  });

  it('cobre as três ações válidas', () => {
    const acoes: readonly AcaoVinculo[] = ACOES_VINCULO;
    expect(acoes).toEqual(['ATRIBUIR', 'SUBSTITUIR', 'ENCERRAR']);
  });
});

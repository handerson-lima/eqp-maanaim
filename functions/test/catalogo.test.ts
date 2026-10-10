import { describe, expect, it } from 'vitest';
import {
  chaveEquipe,
  equipesAusentes,
  hashDataset,
  idEquipeSeed,
  idIgrejaSeed,
  igrejasAusentes,
  ordenarPorNome,
  pesquisarEquipes,
  pesquisarIgrejas,
  rotuloIgreja,
  validarCommandId,
  validarDataset,
  validarAlternarStatusIgreja,
  validarAlternarStatusEquipe,
  hashAlternarStatus,
  validarSalvarIgreja,
  validarSalvarEquipe,
  hashSalvarIgreja,
  hashSalvarEquipe,
  type DatasetCatalogo,
  type EquipeCatalogo,
  type IgrejaCatalogo,
} from '../src/domain/catalogo.js';
import { DATASET_CATALOGO } from '../src/domain/seedCatalogo.js';

const igreja = (codigo: string, extra: Partial<IgrejaCatalogo> = {}): IgrejaCatalogo => ({
  id: idIgrejaSeed(codigo),
  codigo,
  nome: `Igreja ${codigo}`,
  ativo: true,
  ...extra,
});

const equipe = (nome: string, extra: Partial<EquipeCatalogo> = {}): EquipeCatalogo => ({
  id: idEquipeSeed(nome),
  nome,
  nomeNormalizado: chaveEquipe(nome),
  ativo: true,
  ...extra,
});

describe('dataset canônico do catálogo', () => {
  it('contém as 25 igrejas e 14 equipes do PRD sem problemas de validação', () => {
    expect(DATASET_CATALOGO.igrejas).toHaveLength(25);
    expect(DATASET_CATALOGO.equipes).toHaveLength(14);
    expect(validarDataset(DATASET_CATALOGO)).toEqual([]);
  });

  it('usa códigos e nomes normalizados únicos, sem campos de responsável', () => {
    const codigos = DATASET_CATALOGO.igrejas.map((i) => i.codigo);
    expect(new Set(codigos).size).toBe(codigos.length);
    const nomes = DATASET_CATALOGO.equipes.map((e) => chaveEquipe(e.nome));
    expect(new Set(nomes).size).toBe(nomes.length);
    for (const equipe of DATASET_CATALOGO.equipes) {
      expect(Object.keys(equipe)).toEqual(['nome']);
    }
    for (const igreja of DATASET_CATALOGO.igrejas) {
      expect(Object.keys(igreja).sort()).toEqual(['codigo', 'nome']);
    }
  });

  it('recusa código inválido, duplicidades e dataset vazio', () => {
    const problemas = validarDataset({
      versao: 1,
      igrejas: [
        { codigo: '240001', nome: 'A' },
        { codigo: '240001', nome: 'B' },
        { codigo: '123', nome: 'Igreja Curta' },
      ],
      equipes: [
        { nome: 'Apoio' },
        { nome: 'apoio' },
      ],
    });
    const motivos = problemas.map((p) => p.motivo);
    expect(motivos).toContain('CODIGO_DUPLICADO');
    expect(motivos).toContain('CODIGO_INVALIDO');
    expect(motivos).toContain('NOME_INVALIDO');
    expect(motivos).toContain('NOME_DUPLICADO');
  });

  it('liga o hash ao conteúdo versionado do dataset', () => {
    const base = hashDataset(DATASET_CATALOGO);
    expect(base).toBe(hashDataset(DATASET_CATALOGO));
    const alterado: DatasetCatalogo = {
      ...DATASET_CATALOGO,
      igrejas: DATASET_CATALOGO.igrejas.map((i) =>
        i.codigo === '240001' ? { ...i, nome: 'Outro Nome' } : i,
      ),
    };
    expect(hashDataset(alterado)).not.toBe(base);
  });

  it('exige commandId opaco', () => {
    expect(validarCommandId('a'.repeat(16))).toBe(true);
    expect(validarCommandId('curto')).toBe(false);
    expect(validarCommandId('com espaço'.repeat(4))).toBe(false);
  });
});

describe('planejamento idempotente do seed', () => {
  it('base vazia planeja todas as 25 igrejas e 14 equipes', () => {
    expect(igrejasAusentes(DATASET_CATALOGO, [])).toHaveLength(25);
    expect(equipesAusentes(DATASET_CATALOGO, [])).toHaveLength(14);
  });

  it('base parcial cria só o ausente e preserva o existente', () => {
    const faltamIgrejas = igrejasAusentes(DATASET_CATALOGO, [
      igreja('240001'),
      igreja('240002'),
    ]);
    expect(faltamIgrejas).toHaveLength(23);
    expect(faltamIgrejas.map((i) => i.codigo)).not.toContain('240001');
    const faltamEquipes = equipesAusentes(DATASET_CATALOGO, [equipe('Apoio')]);
    expect(faltamEquipes).toHaveLength(13);
    expect(faltamEquipes.map((e) => e.nome)).not.toContain('Apoio');
  });

  it('não recria a igreja pelo código mesmo com ID divergente', () => {
    const existentes = [igreja('240001', { id: 'id-administrado', nome: 'Renomeada' })];
    const faltam = igrejasAusentes(DATASET_CATALOGO, existentes);
    expect(faltam.map((i) => i.codigo)).not.toContain('240001');
    expect(faltam).toHaveLength(24);
  });

  it('não recria a equipe renomeada ancorada ao ID determinístico', () => {
    const existentes = [equipe('Apoio', { nome: 'Apoio Geral' })];
    const faltam = equipesAusentes(DATASET_CATALOGO, existentes);
    expect(faltam.map((e) => e.nome)).not.toContain('Apoio');
    expect(faltam).toHaveLength(13);
  });
});

describe('apresentação e pesquisa do catálogo', () => {
  const igrejas = [igreja('240008', { nome: 'Goianinha' }), igreja('240001', { nome: 'Igapó' })];

  it('ordena alfabeticamente e formata "Nome - Código"', () => {
    const ordenadas = ordenarPorNome(igrejas);
    expect(ordenadas.map((i) => i.nome)).toEqual(['Goianinha', 'Igapó']);
    expect(rotuloIgreja(ordenadas[0])).toBe('Goianinha - 240008');
  });

  it('pesquisa por nome sem acento/caixa e por código parcial', () => {
    expect(pesquisarIgrejas(igrejas, 'iga').map((i) => i.nome)).toEqual(['Igapó']);
    expect(pesquisarIgrejas(igrejas, '24000').map((i) => i.codigo)).toEqual([
      '240008',
      '240001',
    ]);
    expect(pesquisarIgrejas(igrejas, 'inexistente')).toEqual([]);
  });

  it('pesquisa equipes por nome sem acento', () => {
    const equipes = [equipe('Comunicação'), equipe('Limpeza')];
    expect(pesquisarEquipes(equipes, 'comunicacao').map((e) => e.nome)).toEqual([
      'Comunicação',
    ]);
  });
});

describe('Story 7.2: validação e hash de alternar status de catálogo', () => {
  const commandIdValido = 'a'.repeat(32);

  it('valida entrada correta para alternar status de igreja', () => {
    const res = validarAlternarStatusIgreja({
      commandId: commandIdValido,
      igrejaId: 'ig_123',
      ativo: false,
    });
    expect(res).toEqual({
      commandId: commandIdValido,
      igrejaId: 'ig_123',
      ativo: false,
      correlationId: undefined,
    });
  });

  it('rejeita commandId ou igrejaId inválidos e ativo não booleano', () => {
    expect(() =>
      validarAlternarStatusIgreja({
        commandId: 'curto',
        igrejaId: 'ig_123',
        ativo: false,
      }),
    ).toThrowError(/commandId inválido/);

    expect(() =>
      validarAlternarStatusIgreja({
        commandId: commandIdValido,
        igrejaId: '',
        ativo: false,
      }),
    ).toThrowError(/igrejaId inválido/);

    expect(() =>
      validarAlternarStatusIgreja({
        commandId: commandIdValido,
        igrejaId: 'ig_123',
        ativo: 'nao' as unknown as boolean,
      }),
    ).toThrowError(/ativo deve ser booleano/);
  });

  it('valida entrada correta para alternar status de equipe', () => {
    const res = validarAlternarStatusEquipe({
      commandId: commandIdValido,
      equipeId: 'eq_apoio',
      ativo: true,
      correlationId: 'corr_1',
    });
    expect(res).toEqual({
      commandId: commandIdValido,
      equipeId: 'eq_apoio',
      ativo: true,
      correlationId: 'corr_1',
    });
  });

  it('rejeita equipeId inválido', () => {
    expect(() =>
      validarAlternarStatusEquipe({
        commandId: commandIdValido,
        equipeId: '   ',
        ativo: false,
      }),
    ).toThrowError(/equipeId inválido/);
  });

  it('gera hash determinístico e sensível ao tipo, id e estado ativo', () => {
    const h1 = hashAlternarStatus('IGREJA', 'ig_1', false);
    const h2 = hashAlternarStatus('IGREJA', 'ig_1', false);
    const h3 = hashAlternarStatus('IGREJA', 'ig_1', true);
    const h4 = hashAlternarStatus('EQUIPE', 'ig_1', false);

    expect(h1).toBe(h2);
    expect(h1).not.toBe(h3);
    expect(h1).not.toBe(h4);
  });
});

describe('Story 8.11: criação, edição e validações de catálogo', () => {
  const commandIdValido = 'cmd_1234567890abcdef';

  it('valida criação e edição de igreja com código String de 6 dígitos', () => {
    const criacao = validarSalvarIgreja({
      commandId: commandIdValido,
      codigo: '240099',
      nome: 'Igreja Nova Esperança',
      expectedVersion: 0,
    });
    expect(criacao).toEqual({
      commandId: commandIdValido,
      igrejaId: undefined,
      codigo: '240099',
      nome: 'Igreja Nova Esperança',
      expectedVersion: 0,
      correlationId: undefined,
    });

    const edicao = validarSalvarIgreja({
      commandId: commandIdValido,
      igrejaId: 'ig_existente',
      codigo: '240099',
      nome: 'Igreja Atualizada',
      expectedVersion: 2,
      correlationId: 'corr_salvar',
    });
    expect(edicao).toEqual({
      commandId: commandIdValido,
      igrejaId: 'ig_existente',
      codigo: '240099',
      nome: 'Igreja Atualizada',
      expectedVersion: 2,
      correlationId: 'corr_salvar',
    });
  });

  it('rejeita código de igreja inválido ou não estrito a 6 dígitos numéricos', () => {
    expect(() =>
      validarSalvarIgreja({
        commandId: commandIdValido,
        codigo: '123',
        nome: 'Igreja Teste',
        expectedVersion: 0,
      }),
    ).toThrowError(/Código de igreja inválido/);

    expect(() =>
      validarSalvarIgreja({
        commandId: commandIdValido,
        codigo: '240001a',
        nome: 'Igreja Teste',
        expectedVersion: 0,
      }),
    ).toThrowError(/Código de igreja inválido/);
  });

  it('rejeita nome de igreja inválido ou expectedVersion negativo', () => {
    expect(() =>
      validarSalvarIgreja({
        commandId: commandIdValido,
        codigo: '240099',
        nome: 'A',
        expectedVersion: 0,
      }),
    ).toThrowError(/Nome de igreja inválido/);

    expect(() =>
      validarSalvarIgreja({
        commandId: commandIdValido,
        codigo: '240099',
        nome: 'Igreja Teste',
        expectedVersion: -1,
      }),
    ).toThrowError(/expectedVersion deve ser um número inteiro/);
  });

  it('valida criação e edição de equipe', () => {
    const criacao = validarSalvarEquipe({
      commandId: commandIdValido,
      nome: 'Equipe de Intercessão',
      expectedVersion: 0,
    });
    expect(criacao).toEqual({
      commandId: commandIdValido,
      equipeId: undefined,
      nome: 'Equipe de Intercessão',
      expectedVersion: 0,
      correlationId: undefined,
    });

    const edicao = validarSalvarEquipe({
      commandId: commandIdValido,
      equipeId: 'eq_1',
      nome: 'Equipe de Apoio Logístico',
      expectedVersion: 1,
    });
    expect(edicao).toEqual({
      commandId: commandIdValido,
      equipeId: 'eq_1',
      nome: 'Equipe de Apoio Logístico',
      expectedVersion: 1,
      correlationId: undefined,
    });
  });

  it('rejeita equipe com nome inválido', () => {
    expect(() =>
      validarSalvarEquipe({
        commandId: commandIdValido,
        nome: '12',
        expectedVersion: 0,
      }),
    ).toThrowError(/Nome de equipe inválido/);
  });

  it('gera hashes determinísticos e sensíveis para salvarIgreja e salvarEquipe', () => {
    const hIg1 = hashSalvarIgreja({
      commandId: commandIdValido,
      codigo: '240001',
      nome: 'Igreja Um',
      expectedVersion: 0,
    });
    const hIg2 = hashSalvarIgreja({
      commandId: commandIdValido,
      codigo: '240001',
      nome: 'Igreja Um',
      expectedVersion: 0,
    });
    const hIg3 = hashSalvarIgreja({
      commandId: commandIdValido,
      codigo: '240002',
      nome: 'Igreja Um',
      expectedVersion: 0,
    });
    expect(hIg1).toBe(hIg2);
    expect(hIg1).not.toBe(hIg3);

    const hEq1 = hashSalvarEquipe({
      commandId: commandIdValido,
      nome: 'Apoio',
      expectedVersion: 0,
    });
    const hEq2 = hashSalvarEquipe({
      commandId: commandIdValido,
      nome: 'apoio',
      expectedVersion: 0,
    });
    const hEq3 = hashSalvarEquipe({
      commandId: commandIdValido,
      nome: 'Som',
      expectedVersion: 0,
    });
    expect(hEq1).toBe(hEq2); // Mesma chave normalizada
    expect(hEq1).not.toBe(hEq3);
  });
});



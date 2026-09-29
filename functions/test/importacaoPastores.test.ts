import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  ConflitoVinculoError,
  IgrejaInativaError,
  extrairCodigoIgreja,
  idDaLinha,
  importarPastoresIniciais,
  validarEntradas,
  type ContextoLinha,
  type EntradaValidada,
  type IgrejaResumo,
  type PessoaResumo,
  type PortasImportacao,
} from '../src/domain/importacaoPastores.js';
import { parsearPlanilhaPastores } from '../src/domain/planilhaPastores.js';
import { aplicarVinculosAusentes } from '../src/domain/vinculosAusentes.js';
import { prepararEntradas } from '../src/commands/importarPastoresIniciais.js';

class PortasFake implements PortasImportacao {
  igrejas = new Map<string, IgrejaResumo>();
  pessoas = new Map<string, PessoaResumo>();
  vinculos: { codigoIgreja: string; pessoaId: string }[] = [];
  recibos = new Map<string, string>();
  private sequencia = 0;

  adicionarIgreja(codigo: string, ativo = true): IgrejaResumo {
    const igreja: IgrejaResumo = {
      id: `igreja-${codigo}`,
      codigo,
      ativo,
      pastorLocalVigentePessoaId: null,
    };
    this.igrejas.set(codigo, igreja);
    return igreja;
  }

  async buscarIgrejaPorCodigo(codigo: string): Promise<IgrejaResumo | null> {
    return this.igrejas.get(codigo) ?? null;
  }

  async buscarPessoaPorEmail(email: string): Promise<PessoaResumo | null> {
    return this.pessoas.get(email) ?? null;
  }

  async garantirIdentidade(
    entrada: EntradaValidada,
  ): Promise<PessoaResumo> {
    const existente = this.pessoas.get(entrada.emailNormalizado);
    if (existente) return existente;
    this.sequencia += 1;
    const pessoa = { id: `pessoa-${this.sequencia}` };
    this.pessoas.set(entrada.emailNormalizado, pessoa);
    return pessoa;
  }

  async aplicarVinculo(
    entrada: EntradaValidada,
    pessoa: PessoaResumo,
    igreja: IgrejaResumo,
    contexto: ContextoLinha,
  ): Promise<'CRIADO' | 'JA_VIGENTE'> {
    const linhaId = idDaLinha(contexto.commandId, entrada.codigoIgreja);
    const hash = this.recibos.get(linhaId);
    if (hash !== undefined) {
      if (hash === entrada.payloadHash) return 'JA_VIGENTE';
      throw new ComandoDivergenteError();
    }
    const atual = this.igrejas.get(entrada.codigoIgreja);
    if (!atual || !atual.ativo) throw new IgrejaInativaError();
    if (atual.pastorLocalVigentePessoaId) {
      if (atual.pastorLocalVigentePessoaId === pessoa.id) return 'JA_VIGENTE';
      throw new ConflitoVinculoError();
    }
    atual.pastorLocalVigentePessoaId = pessoa.id;
    this.vinculos.push({ codigoIgreja: entrada.codigoIgreja, pessoaId: pessoa.id });
    this.recibos.set(linhaId, entrada.payloadHash);
    return 'CRIADO';
  }
}

const COMMAND_ID = 'c'.repeat(32);

function requisicao(entradas: { codigoIgreja: unknown; nomePastor: unknown; email: unknown }[], modo: 'EXECUCAO' | 'SIMULACAO' = 'EXECUCAO') {
  return {
    commandId: COMMAND_ID,
    correlacaoId: COMMAND_ID,
    origem: 'seed-inicial-do-sistema',
    modo,
    agora: new Date('2026-09-29T12:00:00.000Z'),
    entradas,
  } as const;
}

const linhaValida = (codigo: string, nome: string, email: string) => ({
  codigoIgreja: `${codigo} - IGREJA`,
  nomePastor: nome,
  email,
});

describe('planilha e vínculos ausentes', () => {
  it('lê o cabeçalho canônico e separa as colunas na ordem', () => {
    const entradas = parsearPlanilhaPastores(
      'igreja,pastor,email\n240001 - IGAPÓ,LUANDO DOS SANTOS LUCINDO,luando@example.com\n',
    );
    expect(entradas).toEqual([
      {
        codigoIgreja: '240001 - IGAPÓ',
        nomePastor: 'LUANDO DOS SANTOS LUCINDO',
        email: 'luando@example.com',
      },
    ]);
  });

  it('recusa cabeçalho fora do contrato sem ecoar conteúdo', () => {
    expect(() => parsearPlanilhaPastores('igreja,pessoa\n240001,Alguém')).toThrow(
      'CABECALHO_INVALIDO',
    );
  });

  it('acrescenta 240005 e 240029 herdando a identidade de referência', () => {
    const entradas = aplicarVinculosAusentes([
      linhaValida('240006', 'VICENTE DE PAULO BRAGA', 'vbraga@example.com'),
      linhaValida('240022', 'MAURO AZEVEDO INACIO | RN', 'mauro@example.com'),
    ]);
    expect(entradas).toHaveLength(4);
    expect(entradas[2]).toMatchObject({
      codigoIgreja: '240005',
      nomePastor: 'VICENTE DE PAULO BRAGA',
      email: 'vbraga@example.com',
    });
    expect(entradas[3]).toMatchObject({
      codigoIgreja: '240029',
      nomePastor: 'MAURO AZEVEDO INACIO | RN',
      email: 'mauro@example.com',
    });
  });

  it('compõe parser e vínculos ausentes no fluxo usado pela CLI', () => {
    const csv = [
      'igreja,pastor,email',
      '240006 - MOSSORÓ,VICENTE DE PAULO BRAGA,vbraga@example.com',
      '240022 - MONTE ALEGRE,MAURO AZEVEDO INACIO | RN,mauro@example.com',
    ].join('\n');

    const entradas = prepararEntradas(csv);

    expect(entradas).toHaveLength(4);
    const porCodigo = new Map(
      entradas.map((entrada) => [
        extrairCodigoIgreja(entrada.codigoIgreja),
        entrada,
      ]),
    );
    expect(porCodigo.get('240005')).toMatchObject({
      nomePastor: 'VICENTE DE PAULO BRAGA',
      email: 'vbraga@example.com',
    });
    expect(porCodigo.get('240029')).toMatchObject({
      email: 'mauro@example.com',
    });
  });
});

describe('validação antes da mutação', () => {
  it('remove o sufixo | RN e normaliza identidade', () => {
    const { validas } = validarEntradas([
      linhaValida('240022', 'MAURO AZEVEDO INACIO | RN', 'Mauro@Example.com'),
    ]);
    expect(validas).toHaveLength(1);
    expect(validas[0].entrada.nomeCompleto).toBe('MAURO AZEVEDO INACIO');
    expect(validas[0].entrada.emailNormalizado).toBe('mauro@example.com');
  });

  it('recusa código, nome e e-mail inválidos', () => {
    const { validas, recusadas } = validarEntradas([
      { codigoIgreja: '24001 - X', nomePastor: 'Pessoa Válida', email: 'a@b.com' },
      linhaValida('240002', 'X', 'a@b.com'),
      linhaValida('240003', 'Pessoa Válida', 'invalido'),
    ]);
    expect(validas).toHaveLength(0);
    expect(recusadas.map((r) => r.motivo).sort()).toEqual([
      'CODIGO_INVALIDO',
      'EMAIL_INVALIDO',
      'NOME_INVALIDO',
    ]);
  });

  it('recusa código duplicado e identidade ambígua de forma atômica', () => {
    const { recusadas } = validarEntradas([
      linhaValida('240001', 'PESSOA A', 'a@example.com'),
      linhaValida('240001', 'PESSOA B', 'b@example.com'),
      linhaValida('240003', 'PESSOA C', 'c@example.com'),
      linhaValida('240004', 'PESSOA C', 'd@example.com'),
    ]);
    expect(recusadas.map((r) => r.motivo)).toContain('CODIGO_DUPLICADO');
    expect(recusadas.map((r) => r.motivo)).toContain('IDENTIDADE_AMBIGUA');
  });
});

describe('matriz I/O da carga inicial', () => {
  it('carga válida cria pastor e vínculo vigente sem expor PII', async () => {
    const portas = new PortasFake();
    portas.adicionarIgreja('240001');
    portas.adicionarIgreja('240002');

    const resultado = await importarPastoresIniciais(
      requisicao([
        linhaValida('240001', 'ANA DA SILVA', 'ana@example.com'),
        linhaValida('240002', 'ANA DA SILVA', 'ana@example.com'),
      ]),
      portas,
    );

    expect(resultado.status).toBe('COMPLETO');
    expect(resultado.criados).toBe(2);
    expect(resultado.recusados).toBe(0);
    expect(portas.vinculos).toHaveLength(2);
    expect(portas.vinculos[0].pessoaId).toBe(portas.vinculos[1].pessoaId);
    for (const linha of resultado.linhas) {
      expect(Object.keys(linha).every((chave) =>
        ['codigoIgreja', 'status', 'motivo'].includes(chave),
      )).toBe(true);
    }
    expect(JSON.stringify(resultado)).not.toContain('ana@example.com');
    expect(JSON.stringify(resultado)).not.toContain('ANA DA SILVA');
  });

  it('reexecução é idempotente e não duplica vínculos nem pessoas', async () => {
    const portas = new PortasFake();
    portas.adicionarIgreja('240001');
    const entrada = [linhaValida('240001', 'ANA DA SILVA', 'ana@example.com')];
    await importarPastoresIniciais(requisicao(entrada), portas);
    const segundo = await importarPastoresIniciais(requisicao(entrada), portas);

    expect(segundo.criados).toBe(0);
    expect(segundo.jaVigentes).toBe(1);
    expect(portas.vinculos).toHaveLength(1);
    expect(portas.pessoas.size).toBe(1);
  });

  it('igreja desconhecida ou inativa não cria vínculo parcial', async () => {
    const portas = new PortasFake();
    portas.adicionarIgreja('240099', false);

    const resultado = await importarPastoresIniciais(
      requisicao([
        linhaValida('240777', 'PESSOA UM', 'um@example.com'),
        linhaValida('240099', 'PESSOA DOIS', 'dois@example.com'),
      ]),
      portas,
    );

    expect(resultado.linhas.map((l) => l.motivo)).toEqual([
      'IGREJA_INEXISTENTE',
      'IGREJA_INATIVA',
    ]);
    expect(portas.vinculos).toHaveLength(0);
    expect(portas.pessoas.size).toBe(0);
  });

  it('conflito de vínculo vigente recusa a linha sem substituir', async () => {
    const portas = new PortasFake();
    const igreja = portas.adicionarIgreja('240001');
    igreja.pastorLocalVigentePessoaId = 'pastor-antigo';

    const resultado = await importarPastoresIniciais(
      requisicao([linhaValida('240001', 'PESSOA NOVA', 'nova@example.com')]),
      portas,
    );

    expect(resultado.linhas[0]).toMatchObject({
      status: 'RECUSADO',
      motivo: 'CONFLITO_VINCULO',
    });
    expect(igreja.pastorLocalVigentePessoaId).toBe('pastor-antigo');
    expect(portas.vinculos).toHaveLength(0);
    expect(portas.pessoas.size).toBe(0);
  });

  it('dados inválidos não geram nenhuma gravação daquela entrada', async () => {
    const portas = new PortasFake();
    portas.adicionarIgreja('240001');
    const resultado = await importarPastoresIniciais(
      requisicao([
        linhaValida('240001', 'PESSOA VÁLIDA', 'valida@example.com'),
        linhaValida('240002', 'PESSOA INVÁLIDA', 'sem-arroba'),
      ]),
      portas,
    );
    expect(resultado.criados).toBe(1);
    expect(resultado.recusados).toBe(1);
    expect(portas.vinculos).toHaveLength(1);
    expect(portas.pessoas.size).toBe(1);
  });

  it('modo simulação valida sem gravar nada', async () => {
    const portas = new PortasFake();
    portas.adicionarIgreja('240001');
    portas.adicionarIgreja('240002');
    const igreja = portas.igrejas.get('240001')!;
    igreja.pastorLocalVigentePessoaId = 'outro';

    const resultado = await importarPastoresIniciais(
      requisicao(
        [
          linhaValida('240001', 'CONFLITO', 'conflito@example.com'),
          linhaValida('240777', 'INEXISTENTE', 'x@example.com'),
          linhaValida('240002', 'NOVO VÍNCULO', 'novo@example.com'),
        ],
        'SIMULACAO',
      ),
      portas,
    );

    expect(resultado.modo).toBe('SIMULACAO');
    expect(resultado.simulados).toBe(1);
    expect(resultado.recusados).toBe(2);
    expect(portas.vinculos).toHaveLength(0);
    expect(portas.pessoas.size).toBe(0);
  });

  it('exige commandId opaco e origem auditável', async () => {
    const portas = new PortasFake();
    await expect(
      importarPastoresIniciais(
        { ...requisicao([]), commandId: 'curto' },
        portas,
      ),
    ).rejects.toThrow('COMANDO_INVALIDO');
    await expect(
      importarPastoresIniciais(
        { ...requisicao([]), origem: 'nome com espaço' },
        portas,
      ),
    ).rejects.toThrow('ORIGEM_INVALIDA');
  });
});

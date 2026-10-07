import { describe, expect, it, vi } from 'vitest';
import {
  DadosPdfIncompletosError,
  FichaAnonimizadaParaPdfError,
  ParticipacaoNaoAprovadaParaPdfError,
  comporTextoPrincipal,
  formatarDataExtenso,
  gerarBufferPdfTermo,
  quebrarLinhas,
  type DadosTermoPdf,
} from '../src/domain/pdfTermo.js';
import {
  extrairDadosCanonicosTermo,
  gerarPdfParticipacaoRepo,
  obterUrlDownloadPdfRepo,
  validarAcessoPdf,
  type ContextoPdf,
  type StorageBucketLike,
} from '../src/repositories/pdfTermo.js';
import { AcessoNaoAutorizadoError } from '../src/domain/consultaHistorico.js';

describe('Story 6.3 - Motor de Projeção de PDF Institucional (Domain)', () => {
  const dadosValidos: DadosTermoPdf = {
    fichaId: 'ficha-123',
    participacaoId: 'part-456',
    cicloId: 'ciclo-789',
    nomeVoluntario: 'Lucas Pereira dos Santos',
    nacionalidadeVoluntario: 'Brasileiro(a)',
    profissaoVoluntario: 'Engenheiro de Software',
    cpfVoluntario: '123.456.789-00',
    nomeCoordenador: 'Pastor João da Silva',
    nacionalidadeCoordenador: 'brasileiro',
    estadoCivilCoordenador: 'casado',
    cpfCoordenador: '987.654.321-11',
    nomeEquipe: 'Grupo de Louvor',
    nomeIgreja: 'Igreja Cristã Maranata - Ponta Negra',
    nomePastorVoluntario: 'Pastor Marcos Souza',
    nomePastorEquipe: 'Pastor Carlos Andrade',
    dataAprovacaoIso: '2026-10-15T14:30:00.000Z',
    dataTexto: '15 de outubro de 2026',
    hashSha256Termo: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    versaoTermo: 1,
    vigenciaInicioIso: '2026-10-15T00:00:00.000Z',
    vigenciaFimIso: '2027-10-15T00:00:00.000Z',
  };

  it('formata data por extenso corretamente em português', () => {
    const dataExtenso = formatarDataExtenso('2026-10-15T12:00:00.000Z');
    expect(dataExtenso).toBe('15 de outubro de 2026');
  });

  it('compõe o primeiro parágrafo institucional conforme AD-13 e padrão DOCX', () => {
    const texto = comporTextoPrincipal(dadosValidos);
    expect(texto).toContain('LUCAS PEREIRA DOS SANTOS, Brasileiro(a), Profissão ENGENHEIRO DE SOFTWARE');
    expect(texto).toContain('inscrito(a) no CPF/MF sob o nº 123.456.789-00');
    expect(texto).toContain('IGREJA CRISTÃ MARANATA');
    expect(texto).toContain('CNPJ sob o nº 27.056.910/0001-42');
    expect(texto).toContain('PASTOR JOÃO DA SILVA');
    expect(texto).toContain('inscrito no CPF/MF sob o nº 987.654.321-11');
    expect(texto).toContain('Lei nº 9.608 de 18/02/1998');
    expect(texto).toContain('prestação de serviço na equipe GRUPO DE LOUVOR');
  });

  it('quebra texto longo em múltiplas linhas respeitando largura máxima', () => {
    const fakeFont = {
      widthOfTextAtSize: (t: string, s: number) => t.length * s * 0.5,
    };
    const linhas = quebrarLinhas('Uma linha muito longa para teste de quebra de parágrafo', 100, 10, fakeFont);
    expect(linhas.length).toBeGreaterThan(1);
    expect(linhas.join(' ')).toBe('Uma linha muito longa para teste de quebra de parágrafo');
  });

  it('gera Uint8Array de PDF válido com cabeçalho institucional e assinaturas', async () => {
    const buffer = await gerarBufferPdfTermo(dadosValidos);
    expect(buffer).toBeInstanceOf(Uint8Array);
    expect(buffer.length).toBeGreaterThan(1000);

    // Valida assinatura binária do padrão PDF (%PDF-)
    const pdfHeader = Buffer.from(buffer.slice(0, 5)).toString('ascii');
    expect(pdfHeader).toBe('%PDF-');
  });

  it('rejeita geração quando faltam dados canônicos obrigatórios', async () => {
    const dadosIncompletos = {
      ...dadosValidos,
      cpfVoluntario: '',
    };
    await expect(gerarBufferPdfTermo(dadosIncompletos)).rejects.toThrow(DadosPdfIncompletosError);
  });
});

describe('Story 6.3 - Repositório e Permissões de PDF (Repository)', () => {
  function criarMockStorage(): {
    bucket: StorageBucketLike;
    savedFiles: Map<string, { buffer: Buffer; options?: Record<string, unknown> }>;
  } {
    const savedFiles = new Map<string, { buffer: Buffer; options?: Record<string, unknown> }>();

    const bucket: StorageBucketLike = {
      file: (caminho: string) => ({
        save: async (buffer: Buffer, options?: Record<string, unknown>) => {
          savedFiles.set(caminho, { buffer, options });
        },
        exists: async () => {
          return [savedFiles.has(caminho)];
        },
        getSignedUrl: async ({ expires }) => {
          return [`https://storage.googleapis.com/private-bucket/${caminho}?expires=${expires}`];
        },
      }),
    };

    return { bucket, savedFiles };
  }

  function criarMockFirestore(opcoes: {
    fichaExiste?: boolean;
    fichaOwnerUid?: string;
    fichaAnonimizada?: boolean;
    participacaoExiste?: boolean;
    participacaoFichaId?: string;
    participacaoEstado?: string;
    equipeId?: string;
    igrejaId?: string;
    coordenadorUid?: string;
  }) {
    const auditoriaDocs = new Map<string, Record<string, unknown>>();

    const db = {
      collection: (nomeColecao: string) => ({
        doc: (docId: string) => ({
          get: async () => {
            if (nomeColecao === 'fichas') {
              if (opcoes.fichaExiste === false) return { exists: false, data: () => undefined };
              return {
                exists: true,
                data: () => ({
                  ownerUid: opcoes.fichaOwnerUid ?? docId,
                  nomeCompleto: 'Lucas Voluntário Teste',
                  profissao: 'Arquiteto',
                  cpf: '111.222.333-44',
                  igrejaId: opcoes.igrejaId ?? 'igreja-1',
                  ...(opcoes.fichaAnonimizada
                    ? {
                        nomeCompleto: 'Nome Anonimizado',
                        cpf: '***.***.***-**',
                        profissao: '',
                        anonimizadaEm: '2026-10-07T12:00:00.000Z',
                      }
                    : {}),
                  decisaoPastorLocal: { pastorNome: 'Pastor Local Bento' },
                  termoAceito: {
                    hashSha256: 'abc123hash',
                    numeroVersao: 1,
                    aceitoEm: '2026-10-01T10:00:00.000Z',
                  },
                }),
              };
            }
            if (nomeColecao === 'participacoes') {
              if (opcoes.participacaoExiste === false) return { exists: false, data: () => undefined };
              return {
                exists: true,
                data: () => ({
                  fichaId: opcoes.participacaoFichaId ?? 'ficha-123',
                  equipeId: opcoes.equipeId ?? 'equipe-som',
                  nomeEquipe: 'Equipe de Som',
                  estado: opcoes.participacaoEstado ?? 'ATIVA',
                  cicloAtualId: 'ciclo-2026',
                  decisaoResponsavel: { responsavelNome: 'Pastor Responsável Som' },
                  decisaoCoordenador: {
                    decisao: 'APROVADO',
                    coordenadorUid: opcoes.coordenadorUid ?? 'coord-1',
                    coordenadorNome: 'Pastor Coordenador Geral',
                  },
                }),
              };
            }
            if (nomeColecao === 'pessoas') {
              return {
                exists: true,
                data: () => ({
                  nomeCompleto: 'Pastor Coordenador Geral',
                  cpf: '999.888.777-66',
                  coordenador: true,
                }),
              };
            }
            if (nomeColecao === 'igrejas') {
              return {
                exists: true,
                data: () => ({
                  nome: 'Igreja Central',
                  pastorLocalVigentePessoaId: 'pastor-local-uid',
                }),
              };
            }
            if (nomeColecao === 'equipes') {
              return {
                exists: true,
                data: () => ({
                  nome: 'Equipe de Som',
                  responsavelVigentePessoaId: 'resp-equipe-uid',
                }),
              };
            }
            if (nomeColecao === 'ciclos') {
              return {
                exists: true,
                data: () => ({
                  anoVigencia: 2026,
                  estado: 'ATIVO',
                }),
              };
            }
            if (nomeColecao === 'autoridadesAdministrativas') {
              if (docId === 'coord-1') {
                return {
                  exists: true,
                  data: () => ({ papeis: ['COORDENADOR'], versao: 1 }),
                };
              }
              return { exists: false, data: () => undefined };
            }
            return { exists: false, data: () => undefined };
          },
          set: async (data: Record<string, unknown>) => {
            if (nomeColecao === 'auditOutbox') {
              auditoriaDocs.set(docId, data);
            }
          },
        }),
        where: () => {
          const queryMock: any = {
            where: () => queryMock,
            limit: () => queryMock,
            get: async () => ({ empty: true, docs: [] }),
          };
          return queryMock;
        },
      }),
    };

    return { db: db as any, auditoriaDocs };
  }

  it('extrai dados canônicos consolidados do Firestore exclusivamente de evidências', async () => {
    const { db } = criarMockFirestore({
      fichaExiste: true,
      participacaoExiste: true,
      participacaoEstado: 'ATIVA',
    });

    const { dados, equipeId } = await extrairDadosCanonicosTermo(db, 'ficha-123', 'part-1');
    expect(equipeId).toBe('equipe-som');
    expect(dados.nomeVoluntario).toBe('Lucas Voluntário Teste');
    expect(dados.cpfVoluntario).toBe('111.222.333-44');
    expect(dados.nomeCoordenador).toBe('Pastor Coordenador Geral');
    expect(dados.cpfCoordenador).toBe('999.888.777-66');
    expect(dados.nomeEquipe).toBe('Equipe de Som');
  });

  it('rejeita extração de dados para participação não aprovada', async () => {
    const { db } = criarMockFirestore({
      fichaExiste: true,
      participacaoExiste: true,
      participacaoEstado: 'AGUARDANDO_PASTOR_LOCAL',
    });

    await expect(extrairDadosCanonicosTermo(db, 'ficha-123', 'part-1')).rejects.toThrow(
      ParticipacaoNaoAprovadaParaPdfError,
    );
  });

  it('recusa geração de PDF para ficha anonimizada (AD-12)', async () => {
    const { db } = criarMockFirestore({
      fichaExiste: true,
      fichaAnonimizada: true,
      participacaoExiste: true,
      participacaoFichaId: 'ficha-123',
      participacaoEstado: 'ATIVA',
    });
    const { bucket } = criarMockStorage();

    await expect(
      gerarPdfParticipacaoRepo(
        db,
        { atorUid: 'voluntario-proprietario' },
        'ficha-123',
        'part-1',
        bucket,
      ),
    ).rejects.toThrow(FichaAnonimizadaParaPdfError);
  });

  it('rejeita geração de PDF por usuário sem escopo sobre a ficha', async () => {
    const { db } = criarMockFirestore({
      fichaExiste: true,
      fichaOwnerUid: 'voluntario-proprietario',
      participacaoFichaId: 'ficha-123',
      participacaoExiste: true,
      participacaoEstado: 'ATIVA',
    });
    const { bucket } = criarMockStorage();
    const contexto: ContextoPdf = {
      atorUid: 'usuario-estranho-sem-vinculo',
    };

    await expect(
      gerarPdfParticipacaoRepo(db, contexto, 'ficha-123', 'part-1', bucket),
    ).rejects.toThrow(AcessoNaoAutorizadoError);
  });

  it('gera PDF, armazena no Storage privado e emite auditoria probatória em auditOutbox', async () => {
    const { db, auditoriaDocs } = criarMockFirestore({
      fichaExiste: true,
      fichaOwnerUid: 'voluntario-proprietario',
      participacaoFichaId: 'voluntario-proprietario',
      participacaoExiste: true,
      participacaoEstado: 'ATIVA',
    });
    const { bucket, savedFiles } = criarMockStorage();

    const contexto: ContextoPdf = {
      commandId: 'cmd-gerar-pdf-001',
      correlationId: 'corr-001',
      atorUid: 'voluntario-proprietario', // o próprio voluntário dono
    };

    const resultado = await gerarPdfParticipacaoRepo(
      db,
      contexto,
      'voluntario-proprietario',
      'part-1',
      bucket,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.caminhoStorage).toBe('pdfs/voluntario-proprietario/part-1.pdf');
    expect(resultado.urlDownload).toContain('https://storage.googleapis.com/');
    expect(resultado.nomeArquivo).toBe('Termo_Voluntariado_Equipe_de_Som.pdf');

    // Valida gravação no Storage com metadados corretos
    expect(savedFiles.has('pdfs/voluntario-proprietario/part-1.pdf')).toBe(true);
    const arquivoSalvo = savedFiles.get('pdfs/voluntario-proprietario/part-1.pdf');
    expect(arquivoSalvo?.options?.contentType).toBe('application/pdf');

    // Retenção probatória de 5 anos gravada em customMetadata (AD-12).
    const custom = (arquivoSalvo?.options?.metadata as any)?.metadata;
    expect(typeof custom?.retencaoAte).toBe('string');
    expect(new Date(custom.retencaoAte).getUTCFullYear()).toBe(
      new Date().getUTCFullYear() + 5,
    );

    // Valida registro de auditoria probatória
    expect(auditoriaDocs.has('cmd-gerar-pdf-001')).toBe(true);
    const audit = auditoriaDocs.get('cmd-gerar-pdf-001');
    expect(audit?.acao).toBe('GERAR_PDF_TERMO');
    expect(audit?.atorPapel).toBe('VOLUNTARIO');
    expect(audit?.entidadeId).toBe('part-1');
  });

  it('obterUrlDownloadPdfRepo gera automaticamente quando o arquivo ainda não existe no storage', async () => {
    const { db, auditoriaDocs } = criarMockFirestore({
      fichaExiste: true,
      fichaOwnerUid: 'voluntario-proprietario',
      participacaoFichaId: 'voluntario-proprietario',
      participacaoExiste: true,
      participacaoEstado: 'ATIVA',
    });
    const { bucket } = criarMockStorage();

    const contexto: ContextoPdf = {
      commandId: 'cmd-download-001',
      correlationId: 'corr-download-001',
      atorUid: 'voluntario-proprietario',
    };

    const resultado = await obterUrlDownloadPdfRepo(
      db,
      contexto,
      'voluntario-proprietario',
      'part-1',
      bucket,
    );

    expect(resultado.urlDownload).toContain('https://storage.googleapis.com/');
    expect(resultado.nomeArquivo).toBe('Termo_Voluntariado_Equipe_de_Som.pdf');
  });
});


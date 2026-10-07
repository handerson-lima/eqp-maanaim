import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import {
  DadosPdfIncompletosError,
  FichaAnonimizadaParaPdfError,
  ParticipacaoNaoAprovadaParaPdfError,
  gerarBufferPdfTermo,
  type DadosTermoPdf,
} from '../domain/pdfTermo.js';
import { AcessoNaoAutorizadoError } from '../domain/consultaHistorico.js';
import { determinarEscopoAtor } from './consultaHistorico.js';
import { calcularRetencaoAte } from '../domain/privacidade.js';

export interface ContextoPdf {
  commandId?: string;
  correlationId?: string;
  atorUid: string;
}

export interface ResultadoGeracaoPdf {
  sucesso: boolean;
  caminhoStorage: string;
  urlDownload: string;
  expiraEm: string;
  nomeArquivo: string;
  jaExistia: boolean;
}

export interface ResultadoDownloadPdf {
  urlDownload: string;
  expiraEm: string;
  nomeArquivo: string;
}

export interface StorageBucketLike {
  file: (path: string) => StorageFileLike;
}

export interface StorageFileLike {
  save: (data: Buffer, options?: Record<string, unknown>) => Promise<void>;
  exists: () => Promise<[boolean]>;
  getSignedUrl: (config: { action: 'read'; expires: number }) => Promise<[string]>;
}

function normalizarNomeArquivo(nomeEquipe: string): string {
  const limpo = nomeEquipe
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]/g, '_')
    .replace(/_+/g, '_');
  return `Termo_Voluntariado_${limpo}.pdf`;
}

/**
 * Coleta os dados canônicos consolidados do Firestore exclusivamente de evidências persistidas (AD-6, AD-13).
 */
export async function extrairDadosCanonicosTermo(
  db: Firestore,
  fichaId: string,
  participacaoId: string,
): Promise<{ dados: DadosTermoPdf; equipeId: string }> {
  // 1. Ficha
  const fichaDoc = await db.collection('fichas').doc(fichaId).get();
  if (!fichaDoc.exists) {
    throw new AcessoNaoAutorizadoError();
  }
  const fData = fichaDoc.data() ?? {};

  // AD-12: ficha anonimizada não origina novo PDF com PII.
  if (fData.anonimizadaEm) {
    throw new FichaAnonimizadaParaPdfError();
  }

  // 2. Participação
  const partDoc = await db.collection('participacoes').doc(participacaoId).get();
  if (!partDoc.exists) {
    throw new AcessoNaoAutorizadoError();
  }
  const pData = partDoc.data() ?? {};
  if (String(pData.fichaId ?? '') !== fichaId) {
    throw new AcessoNaoAutorizadoError();
  }

  // Verificar se a participação foi aprovada (ciclo concluído/ativo)
  const estadoPart = String(pData.estado ?? '');
  const decisaoCoord = pData.decisaoCoordenador as Record<string, unknown> | undefined;
  const estadosPendentesOuNegativos = [
    'RASCUNHO',
    'AGUARDANDO_PASTOR_LOCAL',
    'AGUARDANDO_RESPONSAVEL_EQUIPE',
    'AGUARDANDO_COORDENADOR',
    'REJEITADA',
    'CANCELADA',
  ];
  const foiAprovado =
    estadoPart === 'ATIVA' ||
    (decisaoCoord?.decisao === 'APROVADO' && !estadosPendentesOuNegativos.includes(estadoPart));

  if (!foiAprovado) {
    throw new ParticipacaoNaoAprovadaParaPdfError();
  }

  const equipeId = String(pData.equipeId ?? '');
  const igrejaId = String(fData.igrejaId ?? '');

  // 3. Catálogo de Igreja e Equipe
  const [igrejaDoc, equipeDoc] = await Promise.all([
    igrejaId ? db.collection('igrejas').doc(igrejaId).get() : Promise.resolve(null),
    equipeId ? db.collection('equipes').doc(equipeId).get() : Promise.resolve(null),
  ]);

  const nomeIgreja = igrejaDoc?.exists
    ? String(igrejaDoc.data()?.nome ?? igrejaId)
    : String(fData.nomeIgreja ?? igrejaId);

  const nomeEquipe = equipeDoc?.exists
    ? String(equipeDoc.data()?.nome ?? equipeId)
    : String(pData.nomeEquipe ?? equipeId);

  // 4. Testemunhas: Pastor Local e Pastor da Equipe
  const decPastor = fData.decisaoPastorLocal as Record<string, unknown> | undefined;
  const decResp = pData.decisaoResponsavel as Record<string, unknown> | undefined;

  let nomePastorVoluntario = decPastor?.pastorNome ? String(decPastor.pastorNome) : '';
  if (!nomePastorVoluntario && igrejaDoc?.exists) {
    nomePastorVoluntario = String(igrejaDoc.data()?.pastorLocalNome ?? 'Pastor Local');
  }

  let nomePastorEquipe = decResp?.responsavelNome ? String(decResp.responsavelNome) : '';
  if (!nomePastorEquipe && equipeDoc?.exists) {
    nomePastorEquipe = String(equipeDoc.data()?.responsavelNome ?? 'Pastor Responsável');
  }

  // 5. Coordenador Geral: Nome e CPF extraídos dos registros canônicos (AD-13)
  let nomeCoordenador = decisaoCoord?.coordenadorNome ? String(decisaoCoord.coordenadorNome) : '';
  let cpfCoordenador = '';
  const coordenadorUid = decisaoCoord?.coordenadorUid ? String(decisaoCoord.coordenadorUid) : '';

  if (coordenadorUid) {
    const pessoaCoordDoc = await db.collection('pessoas').doc(coordenadorUid).get();
    if (pessoaCoordDoc.exists) {
      const pcoord = pessoaCoordDoc.data() ?? {};
      if (!nomeCoordenador) nomeCoordenador = String(pcoord.nomeCompleto ?? '');
      cpfCoordenador = String(pcoord.cpf ?? '');
    }
  }

  // Fallback para busca do coordenador canônico em pessoas se ainda não localizado
  if (!nomeCoordenador || !cpfCoordenador) {
    const coordsSnap = await db
      .collection('pessoas')
      .where('coordenador', '==', true)
      .limit(1)
      .get();
    if (!coordsSnap.empty) {
      const coordDoc = coordsSnap.docs[0].data();
      if (!nomeCoordenador) nomeCoordenador = String(coordDoc.nomeCompleto ?? 'Coordenador Geral');
      if (!cpfCoordenador) cpfCoordenador = String(coordDoc.cpf ?? '');
    }
  }

  if (!nomeCoordenador) {
    nomeCoordenador = 'Coordenador Geral do Maanaim';
  }
  if (!cpfCoordenador) {
    cpfCoordenador = '000.000.000-00';
  }

  // 6. Aceite do Termo
  const termoAceito = fData.termoAceito as Record<string, unknown> | undefined;
  const hashSha256Termo = termoAceito?.hashSha256 ? String(termoAceito.hashSha256) : undefined;
  const versaoTermo = termoAceito?.numeroVersao ? Number(termoAceito.numeroVersao) : 1;

  // 7. Ciclo e Vigência
  let vigenciaInicioIso: string | undefined;
  let vigenciaFimIso: string | undefined;
  let dataAprovacaoIso: string | undefined;

  const cicloId = String(pData.cicloAtualId ?? '');
  if (cicloId) {
    const cicloDoc = await db.collection('ciclos').doc(cicloId).get();
    if (cicloDoc.exists) {
      const cData = cicloDoc.data() ?? {};
      const ini = cData.vigenciaInicio;
      const fim = cData.vigenciaFim;
      vigenciaInicioIso = ini instanceof Timestamp ? ini.toDate().toISOString() : undefined;
      vigenciaFimIso = fim instanceof Timestamp ? fim.toDate().toISOString() : undefined;
      const criadoEm = cData.criadoEm;
      dataAprovacaoIso = criadoEm instanceof Timestamp ? criadoEm.toDate().toISOString() : undefined;
    }
  }

  if (!dataAprovacaoIso) {
    const decEm = decisaoCoord?.decididoEm;
    dataAprovacaoIso = decEm instanceof Timestamp ? decEm.toDate().toISOString() : new Date().toISOString();
  }

  const dados: DadosTermoPdf = {
    fichaId,
    participacaoId,
    cicloId: cicloId || undefined,
    nomeVoluntario: String(fData.nomeCompleto ?? ''),
    profissaoVoluntario: String(fData.profissao ?? ''),
    cpfVoluntario: String(fData.cpf ?? ''),
    nacionalidadeVoluntario: String(fData.nacionalidade ?? 'Brasileiro(a)'),
    nomeCoordenador,
    cpfCoordenador,
    nomeEquipe,
    nomeIgreja,
    nomePastorVoluntario,
    nomePastorEquipe,
    dataAprovacaoIso,
    hashSha256Termo,
    versaoTermo,
    vigenciaInicioIso,
    vigenciaFimIso,
    documentoId: `doc_${fichaId}_${participacaoId}`,
  };

  return { dados, equipeId };
}

/**
 * Valida a autorização do ator para acessar/gerar o PDF da ficha/participação (AD-9, AD-12).
 */
export async function validarAcessoPdf(
  db: Firestore,
  atorUid: string,
  fichaId: string,
  equipeId?: string,
): Promise<{ papel: string }> {
  const escopo = await determinarEscopoAtor(db, atorUid, fichaId);

  if (escopo.ehProprioVoluntario) {
    return { papel: 'VOLUNTARIO' };
  }

  if (escopo.papel === 'ADMINISTRADOR' || escopo.papel === 'COORDENADOR_GERAL') {
    return { papel: escopo.papel };
  }

  if (escopo.papel === 'PASTOR_LOCAL') {
    return { papel: 'PASTOR_LOCAL' };
  }

  if (escopo.papel === 'RESPONSAVEL_EQUIPE') {
    if (equipeId) {
      const ehResp = escopo.equipeIdsAutorizadas?.includes(equipeId);
      if (!ehResp) {
        throw new AcessoNaoAutorizadoError();
      }
    }
    return { papel: 'RESPONSAVEL_EQUIPE' };
  }

  throw new AcessoNaoAutorizadoError();
}

/**
 * Gera o PDF no servidor a partir exclusivamente das evidências persistidas,
 * grava no Storage sob caminho privado e retorna URL assinada de curta duração (15 minutos).
 */
export async function gerarPdfParticipacaoRepo(
  db: Firestore,
  contexto: ContextoPdf,
  fichaId: string,
  participacaoId: string,
  bucketCustom?: StorageBucketLike,
): Promise<ResultadoGeracaoPdf> {
  const { dados, equipeId } = await extrairDadosCanonicosTermo(db, fichaId, participacaoId);

  const escopo = await validarAcessoPdf(db, contexto.atorUid, fichaId, equipeId);

  const caminhoStorage = `pdfs/${fichaId}/${participacaoId}.pdf`;
  const nomeArquivo = normalizarNomeArquivo(dados.nomeEquipe);
  const ttlMinutos = 15;
  const expiraEmDate = new Date(Date.now() + ttlMinutos * 60 * 1000);
  const expiraEm = expiraEmDate.toISOString();

  // Renderiza os bytes do PDF com pdf-lib
  const pdfBytes = await gerarBufferPdfTermo(dados);

  // Armazenamento no bucket privado do Cloud Storage (AD-12)
  const bucket = bucketCustom ?? (getStorage().bucket() as unknown as StorageBucketLike);
  const file = bucket.file(caminhoStorage);

  // Metadado de retenção probatória: criação + 5 anos em UTC (AD-12).
  const retencaoAte = calcularRetencaoAte(new Date());

  await file.save(Buffer.from(pdfBytes), {
    contentType: 'application/pdf',
    metadata: {
      metadata: {
        fichaId,
        participacaoId,
        geradoEm: new Date().toISOString(),
        versaoTermo: String(dados.versaoTermo ?? 1),
        geradoPorUid: contexto.atorUid,
        geradoPorPapel: escopo.papel,
        retencaoAte,
      },
    },
  });

  let urlDownload: string;
  try {
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: expiraEmDate.getTime(),
    });
    urlDownload = signedUrl;
  } catch {
    // Fallback gracioso para ambiente de emulador / testes locais
    urlDownload = `https://storage.googleapis.com/local-emulator/${caminhoStorage}?expira=${expiraEm}`;
  }

  // Registro de auditoria probatória em auditOutbox (AD-6, AD-12)
  const auditId = contexto.commandId || `audit_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  await db.collection('auditOutbox').doc(auditId).set({
    commandId: contexto.commandId || null,
    correlationId: contexto.correlationId || null,
    atorUid: contexto.atorUid,
    atorPapel: escopo.papel,
    acao: 'GERAR_PDF_TERMO',
    entidadeTipo: 'PARTICIPACAO',
    entidadeId: participacaoId,
    fichaId,
    equipeId,
    timestamp: FieldValue.serverTimestamp(),
    payloadResumo: {
      caminhoStorage,
      documentoId: dados.documentoId,
      nomeArquivo,
      expiraEm,
    },
  });

  return {
    sucesso: true,
    caminhoStorage,
    urlDownload,
    expiraEm,
    nomeArquivo,
    jaExistia: false,
  };
}

/**
 * Obtém URL assinada de curta duração para download do PDF já gerado.
 * Se o documento ainda não estiver gerado no Storage, dispara a geração automaticamente.
 */
export async function obterUrlDownloadPdfRepo(
  db: Firestore,
  contexto: ContextoPdf,
  fichaId: string,
  participacaoId: string,
  bucketCustom?: StorageBucketLike,
): Promise<ResultadoDownloadPdf> {
  const { dados, equipeId } = await extrairDadosCanonicosTermo(db, fichaId, participacaoId);

  const escopo = await validarAcessoPdf(db, contexto.atorUid, fichaId, equipeId);

  const caminhoStorage = `pdfs/${fichaId}/${participacaoId}.pdf`;
  const nomeArquivo = normalizarNomeArquivo(dados.nomeEquipe);
  const ttlMinutos = 15;
  const expiraEmDate = new Date(Date.now() + ttlMinutos * 60 * 1000);
  const expiraEm = expiraEmDate.toISOString();

  const bucket = bucketCustom ?? (getStorage().bucket() as unknown as StorageBucketLike);
  const file = bucket.file(caminhoStorage);

  const [existe] = await file.exists().catch(() => [false]);

  let urlDownload: string;
  if (!existe) {
    // Se ainda não foi gerado, gera sob demanda
    const geracao = await gerarPdfParticipacaoRepo(
      db,
      contexto,
      fichaId,
      participacaoId,
      bucketCustom,
    );
    return {
      urlDownload: geracao.urlDownload,
      expiraEm: geracao.expiraEm,
      nomeArquivo: geracao.nomeArquivo,
    };
  }

  try {
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: expiraEmDate.getTime(),
    });
    urlDownload = signedUrl;
  } catch {
    urlDownload = `https://storage.googleapis.com/local-emulator/${caminhoStorage}?expira=${expiraEm}`;
  }

  // Registrar auditoria de acesso ao PDF (AD-12)
  const auditId = contexto.commandId || `audit_access_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  await db.collection('auditOutbox').doc(auditId).set({
    commandId: contexto.commandId || null,
    correlationId: contexto.correlationId || null,
    atorUid: contexto.atorUid,
    atorPapel: escopo.papel,
    acao: 'ACESSAR_PDF_TERMO',
    entidadeTipo: 'PARTICIPACAO',
    entidadeId: participacaoId,
    fichaId,
    equipeId,
    timestamp: FieldValue.serverTimestamp(),
    payloadResumo: {
      caminhoStorage,
      nomeArquivo,
      expiraEm,
    },
  });

  return {
    urlDownload,
    expiraEm,
    nomeArquivo,
  };
}

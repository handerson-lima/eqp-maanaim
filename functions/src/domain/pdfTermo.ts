import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

export interface DadosTermoPdf {
  fichaId: string;
  participacaoId: string;
  cicloId?: string;
  nomeVoluntario: string;
  nacionalidadeVoluntario?: string;
  profissaoVoluntario: string;
  cpfVoluntario: string;
  nomeCoordenador: string;
  nacionalidadeCoordenador?: string;
  estadoCivilCoordenador?: string;
  cpfCoordenador: string;
  nomeEquipe: string;
  nomeIgreja: string;
  nomePastorVoluntario: string;
  nomePastorEquipe: string;
  dataAprovacaoIso?: string;
  dataTexto?: string;
  hashSha256Termo?: string;
  versaoTermo?: number;
  vigenciaInicioIso?: string;
  vigenciaFimIso?: string;
  documentoId?: string;
}

export class DadosPdfIncompletosError extends Error {
  constructor(mensagem = 'Dados obrigatórios para geração do termo em PDF incompletos.') {
    super(mensagem);
    this.name = 'DadosPdfIncompletosError';
  }
}

export class ParticipacaoNaoAprovadaParaPdfError extends Error {
  constructor(
    mensagem = 'O termo em PDF só pode ser gerado para participações aprovadas no ciclo concluído.',
  ) {
    super(mensagem);
    this.name = 'ParticipacaoNaoAprovadaParaPdfError';
  }
}

/**
 * Converte data ISO ou objeto Date para formato institucional por extenso.
 * Exemplo: "15 de outubro de 2026"
 */
export function formatarDataExtenso(dataIsoOuDate?: string | Date): string {
  const dt = dataIsoOuDate
    ? typeof dataIsoOuDate === 'string'
      ? new Date(dataIsoOuDate)
      : dataIsoOuDate
    : new Date();

  const meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  const dia = dt.getUTCDate();
  const mes = meses[dt.getUTCMonth()];
  const ano = dt.getUTCFullYear();

  return `${dia} de ${mes} de ${ano}`;
}

/**
 * Divide um parágrafo em múltiplas linhas respeitando a largura máxima em pontos.
 */
export function quebrarLinhas(
  texto: string,
  larguraMaxima: number,
  tamanhoFonte: number,
  font: { widthOfTextAtSize: (t: string, s: number) => number },
): string[] {
  const palavras = texto.split(/\s+/);
  const linhas: string[] = [];
  let linhaAtual = '';

  for (const palavra of palavras) {
    const tentativa = linhaAtual ? `${linhaAtual} ${palavra}` : palavra;
    const largura = font.widthOfTextAtSize(tentativa, tamanhoFonte);

    if (largura <= larguraMaxima) {
      linhaAtual = tentativa;
    } else {
      if (linhaAtual) {
        linhas.push(linhaAtual);
      }
      linhaAtual = palavra;
    }
  }

  if (linhaAtual) {
    linhas.push(linhaAtual);
  }

  return linhas;
}

/**
 * Monta o texto canônico do primeiro parágrafo institucional conforme AD-13 e DOCX.
 */
export function comporTextoPrincipal(dados: DadosTermoPdf): string {
  const nomeVol = dados.nomeVoluntario.trim().toUpperCase();
  const nacionalidadeVol = dados.nacionalidadeVoluntario?.trim() || 'Brasileiro(a)';
  const profVol = dados.profissaoVoluntario.trim().toUpperCase();
  const cpfVol = dados.cpfVoluntario.trim();
  const nomeCoord = dados.nomeCoordenador.trim().toUpperCase();
  const nacionalidadeCoord = dados.nacionalidadeCoordenador?.trim() || 'brasileiro';
  const civilCoord = dados.estadoCivilCoordenador?.trim() || 'casado';
  const cpfCoord = dados.cpfCoordenador.trim();
  const equipe = dados.nomeEquipe.trim().toUpperCase();

  return (
    `${nomeVol}, ${nacionalidadeVol}, Profissão ${profVol}, inscrito(a) no CPF/MF sob o nº ${cpfVol}, ` +
    `celebra com a IGREJA CRISTÃ MARANATA, pessoa jurídica de direito privado, inscrita no CNPJ sob o ` +
    `nº 27.056.910/0001-42, com sede na Rua Torquato Laranja, 90, Centro, Vila Velha – ES, CEP 29106-720, ` +
    `neste ato, representada pelo Administrador Voluntário do Maanaim do RIO GRANDE DO NORTE, ` +
    `${nomeCoord}, ${nacionalidadeCoord}, ${civilCoord}, inscrito no CPF/MF sob o nº ${cpfCoord}, ` +
    `em conformidade aos preceitos da Lei nº 9.608 de 18/02/1998, o presente TERMO DE ADESÃO AO SERVIÇO ` +
    `VOLUNTÁRIO para prestação de serviço na equipe ${equipe}.`
  );
}

/**
 * Motor gerador do PDF institucional a partir exclusivamente das evidências persistidas (AD-6, AD-12, AD-13).
 */
export async function gerarBufferPdfTermo(dados: DadosTermoPdf): Promise<Uint8Array> {
  if (
    !dados.nomeVoluntario ||
    !dados.profissaoVoluntario ||
    !dados.cpfVoluntario ||
    !dados.nomeCoordenador ||
    !dados.cpfCoordenador ||
    !dados.nomeEquipe
  ) {
    throw new DadosPdfIncompletosError();
  }

  const pdfDoc = await PDFDocument.create();

  // Dimensões A4: 595.28 x 841.89 pontos
  const page = pdfDoc.addPage([595.28, 841.89]);
  const fontHelvetica = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontHelveticaBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

  const corTexto = rgb(0.1, 0.1, 0.1);
  const corPrimaria = rgb(0.0, 0.17, 0.29); // navy-900 (#002B49)
  const corSecundaria = rgb(0.3, 0.35, 0.4);
  const corLinha = rgb(0.7, 0.75, 0.8);

  const margemHorizontal = 50;
  const larguraUtil = 595.28 - margemHorizontal * 2; // 495.28
  let cursorY = 841.89 - 50; // Começando a 50 pt do topo

  // 1. Cabeçalho Institucional
  const tituloInstituicao = 'MAANAIM DO RIO GRANDE DO NORTE';
  const larguraTituloInst = fontHelveticaBold.widthOfTextAtSize(tituloInstituicao, 16);
  page.drawText(tituloInstituicao, {
    x: margemHorizontal + (larguraUtil - larguraTituloInst) / 2,
    y: cursorY,
    size: 16,
    font: fontHelveticaBold,
    color: corPrimaria,
  });

  cursorY -= 24;

  const tituloTermo = 'TERMO DE ADESÃO DE VOLUNTÁRIO';
  const larguraTituloTermo = fontHelveticaBold.widthOfTextAtSize(tituloTermo, 14);
  page.drawText(tituloTermo, {
    x: margemHorizontal + (larguraUtil - larguraTituloTermo) / 2,
    y: cursorY,
    size: 14,
    font: fontHelveticaBold,
    color: corPrimaria,
  });

  cursorY -= 16;

  // Linha divisória horizontal
  page.drawLine({
    start: { x: margemHorizontal, y: cursorY },
    end: { x: margemHorizontal + larguraUtil, y: cursorY },
    thickness: 1,
    color: corLinha,
  });

  cursorY -= 20;

  // Subtítulo da Lei
  const subtituloLei = 'Lei do Serviço Voluntário (LEI 9.608/1998)';
  const larguraSubtitulo = fontHelveticaBold.widthOfTextAtSize(subtituloLei, 11);
  page.drawText(subtituloLei, {
    x: margemHorizontal + (larguraUtil - larguraSubtitulo) / 2,
    y: cursorY,
    size: 11,
    font: fontHelveticaBold,
    color: corPrimaria,
  });

  cursorY -= 32;

  // 2. Primeiro Parágrafo (Identificação das partes e objeto)
  const textoPrincipal = comporTextoPrincipal(dados);
  const linhasPrincipal = quebrarLinhas(textoPrincipal, larguraUtil, 10.5, fontHelvetica);

  for (const linha of linhasPrincipal) {
    page.drawText(linha, {
      x: margemHorizontal,
      y: cursorY,
      size: 10.5,
      font: fontHelvetica,
      color: corTexto,
      lineHeight: 15,
    });
    cursorY -= 15;
  }

  cursorY -= 14;

  // 3. Segundo Parágrafo (Declaração de conhecimento)
  const textoSecundario =
    'Por ser verdade declaramos conhecer e aceitar todos os termos da Lei nr 9.608 de 18/02/1998, que trata sobre o serviço voluntário.';
  const linhasSecundario = quebrarLinhas(textoSecundario, larguraUtil, 10.5, fontHelvetica);

  for (const linha of linhasSecundario) {
    page.drawText(linha, {
      x: margemHorizontal,
      y: cursorY,
      size: 10.5,
      font: fontHelvetica,
      color: corTexto,
      lineHeight: 15,
    });
    cursorY -= 15;
  }

  cursorY -= 20;

  // 4. Local e Data
  const dataExtenso = dados.dataTexto || formatarDataExtenso(dados.dataAprovacaoIso);
  const textoLocalData = `Natal – RN, ${dataExtenso}.`;
  page.drawText(textoLocalData, {
    x: margemHorizontal,
    y: cursorY,
    size: 11,
    font: fontHelveticaBold,
    color: corTexto,
  });

  cursorY -= 40;

  // 5. Bloco de Assinaturas (2 colunas: Voluntário e Coordenador)
  const larguraColuna = (larguraUtil - 40) / 2;
  const col1X = margemHorizontal;
  const col2X = margemHorizontal + larguraColuna + 40;

  // Assinatura Voluntário
  page.drawLine({
    start: { x: col1X, y: cursorY },
    end: { x: col1X + larguraColuna, y: cursorY },
    thickness: 1,
    color: corLinha,
  });

  // Assinatura Coordenador
  page.drawLine({
    start: { x: col2X, y: cursorY },
    end: { x: col2X + larguraColuna, y: cursorY },
    thickness: 1,
    color: corLinha,
  });

  cursorY -= 14;

  // Nome Voluntário
  page.drawText(dados.nomeVoluntario.trim().toUpperCase(), {
    x: col1X,
    y: cursorY,
    size: 9.5,
    font: fontHelveticaBold,
    color: corTexto,
  });

  // Nome Coordenador
  page.drawText(dados.nomeCoordenador.trim().toUpperCase(), {
    x: col2X,
    y: cursorY,
    size: 9.5,
    font: fontHelveticaBold,
    color: corTexto,
  });

  cursorY -= 12;

  // Subtextos de cargo e aceite
  page.drawText('Voluntário (Aceite Eletrônico Registrado)', {
    x: col1X,
    y: cursorY,
    size: 8,
    font: fontHelvetica,
    color: corSecundaria,
  });

  page.drawText('Coordenador do Maanaim / Administrador', {
    x: col2X,
    y: cursorY,
    size: 8,
    font: fontHelvetica,
    color: corSecundaria,
  });

  cursorY -= 36;

  // 6. Testemunhas Canônicas
  page.drawText('TESTEMUNHAS:', {
    x: margemHorizontal,
    y: cursorY,
    size: 10,
    font: fontHelveticaBold,
    color: corPrimaria,
  });

  cursorY -= 32;

  // Linhas das testemunhas
  page.drawLine({
    start: { x: col1X, y: cursorY },
    end: { x: col1X + larguraColuna, y: cursorY },
    thickness: 1,
    color: corLinha,
  });

  page.drawLine({
    start: { x: col2X, y: cursorY },
    end: { x: col2X + larguraColuna, y: cursorY },
    thickness: 1,
    color: corLinha,
  });

  cursorY -= 14;

  // Nome Pastor Local
  page.drawText(
    (dados.nomePastorVoluntario || 'Pastor da Igreja Local').trim().toUpperCase(),
    {
      x: col1X,
      y: cursorY,
      size: 9.5,
      font: fontHelveticaBold,
      color: corTexto,
    },
  );

  // Nome Pastor Equipe
  page.drawText(
    (dados.nomePastorEquipe || 'Pastor Responsável pela Equipe').trim().toUpperCase(),
    {
      x: col2X,
      y: cursorY,
      size: 9.5,
      font: fontHelveticaBold,
      color: corTexto,
    },
  );

  cursorY -= 12;

  page.drawText(`Pastor da Igreja Local (${dados.nomeIgreja || 'Igreja'})`, {
    x: col1X,
    y: cursorY,
    size: 8,
    font: fontHelvetica,
    color: corSecundaria,
  });

  page.drawText(`Pastor Responsável (${dados.nomeEquipe})`, {
    x: col2X,
    y: cursorY,
    size: 8,
    font: fontHelvetica,
    color: corSecundaria,
  });

  // 7. Rodapé de integridade e auditoria probatória (AD-12)
  const rodapeY = 40;
  page.drawLine({
    start: { x: margemHorizontal, y: rodapeY + 20 },
    end: { x: margemHorizontal + larguraUtil, y: rodapeY + 20 },
    thickness: 0.5,
    color: corLinha,
  });

  const docId = dados.documentoId || `doc_${dados.fichaId}_${dados.participacaoId}`;
  const vigenciaTexto =
    dados.vigenciaInicioIso && dados.vigenciaFimIso
      ? ` | Vigência: ${formatarDataCurta(dados.vigenciaInicioIso)} a ${formatarDataCurta(dados.vigenciaFimIso)}`
      : '';
  const hashTexto = dados.hashSha256Termo ? ` | Hash Aceite: ${dados.hashSha256Termo.slice(0, 16)}...` : '';

  const linhaInfo1 = `Identificador: ${docId}${vigenciaTexto}${hashTexto}`;
  page.drawText(linhaInfo1, {
    x: margemHorizontal,
    y: rodapeY + 8,
    size: 7.5,
    font: fontHelvetica,
    color: corSecundaria,
  });

  const linhaInfo2 =
    'Documento emitido exclusivamente a partir de evidências persistidas no sistema Maanaim. Retenção legal: 5 anos (AD-12).';
  page.drawText(linhaInfo2, {
    x: margemHorizontal,
    y: rodapeY - 2,
    size: 7,
    font: fontHelvetica,
    color: corSecundaria,
  });

  return await pdfDoc.save();
}

function formatarDataCurta(iso?: string): string {
  if (!iso) return '';
  try {
    const d = new Date(iso);
    const dia = String(d.getUTCDate()).padStart(2, '0');
    const mes = String(d.getUTCMonth() + 1).padStart(2, '0');
    const ano = d.getUTCFullYear();
    return `${dia}/${mes}/${ano}`;
  } catch {
    return iso;
  }
}

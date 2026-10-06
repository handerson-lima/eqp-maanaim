import 'termo_adesao_model.dart';
import 'termo_logo_asset.dart';

/// Gera o código HTML/CSS estritamente fiel ao documento impresso
/// "TERMO DE ADESÃO DE VOLUNTÁRIO" da Igreja Cristã Maranata / Maanaim do RN.
String gerarHtmlTermoAdesao(TermoAdesaoModel model) {
  final nomeVol = model.nomeVoluntario.trim().toUpperCase();
  final profVol = model.profissaoVoluntario.trim().toUpperCase();
  final cpfVol = model.cpfVoluntario.trim();
  final nomeCoord = model.nomeCoordenador.trim().toUpperCase();
  final cpfCoord = model.cpfCoordenador.trim();
  final equipe = model.nomeEquipe.trim().toUpperCase();
  final pastorVol = model.nomePastorVoluntario.trim().toUpperCase();
  final pastorEqp = model.nomePastorEquipe.trim().toUpperCase();
  final dataExtenso = model.dataFormatadaExtenso;

  return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Termo de Adesão de Voluntário - $nomeVol</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 25mm 20mm 20mm 20mm;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: Arial, Helvetica, sans-serif;
      font-size: 13.5pt;
      line-height: 1.6;
      color: #000;
      background-color: #fff;
      padding: 30px;
      max-width: 800px;
      margin: 0 auto;
    }
    .header {
      text-align: center;
      margin-bottom: 25px;
    }
    .logo-container {
      margin-bottom: 8px;
      text-align: center;
    }
    .logo-img {
      max-width: 220px;
      height: auto;
      display: inline-block;
    }
    .titulo-maanaim {
      font-size: 15pt;
      font-weight: 800;
      letter-spacing: 0.5px;
      margin-top: 18px;
      text-transform: uppercase;
    }
    .titulo-termo {
      font-size: 15pt;
      font-weight: 800;
      letter-spacing: 0.5px;
      margin-top: 10px;
      text-transform: uppercase;
    }
    .divider {
      border-bottom: 1.5px solid #000;
      margin: 18px 0 26px 0;
      width: 100%;
    }
    .subtitulo-lei {
      text-align: center;
      font-size: 13.5pt;
      font-weight: 800;
      text-decoration: underline;
      margin-bottom: 28px;
      line-height: 1.4;
    }
    .corpo-texto {
      text-align: justify;
      text-justify: inter-word;
      font-size: 11.5pt;
      line-height: 1.65;
      margin-bottom: 20px;
    }
    .declaracao {
      text-align: justify;
      font-size: 11.5pt;
      line-height: 1.65;
      margin-top: 24px;
      margin-bottom: 30px;
    }
    .local-data {
      font-size: 11.5pt;
      margin-bottom: 45px;
    }
    .bloco-assinaturas {
      margin-top: 30px;
    }
    .assinatura-item {
      text-align: center;
      margin-bottom: 40px;
    }
    .linha-assinatura {
      border-top: 1.2px solid #000;
      width: 440px;
      margin: 0 auto 6px auto;
    }
    .nome-assinatura {
      font-size: 12pt;
      font-weight: 800;
      letter-spacing: 0.3px;
      text-transform: uppercase;
    }
    .titulo-testemunhas {
      font-size: 12pt;
      font-weight: 700;
      margin-top: 20px;
      margin-bottom: 40px;
      text-align: left;
    }
    .testemunha-item {
      text-align: center;
      margin-bottom: 40px;
    }
    @media print {
      body {
        padding: 0;
        max-width: 100%;
      }
      .no-print {
        display: none !important;
      }
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo-container">
      <img src="data:image/png;base64,$kLogoMaranataPngBase64" alt="Igreja Cristã Maranata" class="logo-img" />
    </div>
    <div class="titulo-maanaim">MAANAIM DO RIO GRANDE DO NORTE</div>
    <div class="titulo-termo">TERMO DE ADESÃO DE VOLUNTÁRIO</div>
  </div>

  <div class="divider"></div>

  <div class="subtitulo-lei">
    <u>Lei do Serviço Voluntário (LEI 9.608/1998)</u>
  </div>

  <p class="corpo-texto">
    <strong>$nomeVol</strong>, ${model.nacionalidadeVoluntario}, Profissão <strong>$profVol</strong>, inscrito(a) no CPF/MF sob o nº <strong>$cpfVol</strong>, celebra com a <strong>IGREJA CRISTÃ MARANATA</strong>, pessoa jurídica de direito privado, inscrito no CNPJ sob o nº 27.056.910/0001-42, com sede na Rua Torquato Laranja, 90, Centro, Vila Velha – ES, CEP 29106-720, neste ato, representado pelo Administrador Voluntário do Maanaim do RIO GRANDE DO NORTE, <strong>$nomeCoord</strong>, ${model.nacionalidadeCoordenador}, ${model.estadoCivilCoordenador}, inscrito no CPF/MF sob o nº <strong>$cpfCoord</strong>, em conformidade aos preceitos da Lei nº 9.608 de 18/02/1998, o presente <strong>TERMO DE ADESÃO AO SERVIÇO VOLUNTÁRIO</strong> para prestação de serviço na equipe <strong>$equipe</strong>.
  </p>

  <p class="declaracao">
    Por ser verdade declaramos conhecer e aceitar todos os termos da Lei nr 9.608 de 18/02/1998, que trata sobre o serviço voluntário.
  </p>

  <p class="local-data">
    Natal – RN, <strong>$dataExtenso.</strong>
  </p>

  <div class="bloco-assinaturas">
    <div class="assinatura-item">
      <div class="linha-assinatura"></div>
      <div class="nome-assinatura">$nomeVol</div>
    </div>

    <div class="assinatura-item">
      <div class="linha-assinatura"></div>
      <div class="nome-assinatura">$nomeCoord</div>
    </div>

    <div class="titulo-testemunhas">TESTEMUNHAS:</div>

    <div class="testemunha-item">
      <div class="linha-assinatura"></div>
      <div class="nome-assinatura">$pastorVol</div>
    </div>

    <div class="testemunha-item">
      <div class="linha-assinatura"></div>
      <div class="nome-assinatura">$pastorEqp</div>
    </div>
  </div>
</body>
</html>
''';
}

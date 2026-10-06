/// Modelo de dados representativo do Termo de Adesão de Voluntário
/// em estrita conformidade com a Lei do Serviço Voluntário (Lei 9.608/1998)
/// e o modelo oficial da Igreja Cristã Maranata / Maanaim do Rio Grande do Norte.
class TermoAdesaoModel {
  const TermoAdesaoModel({
    required this.nomeVoluntario,
    required this.profissaoVoluntario,
    required this.cpfVoluntario,
    required this.nomeCoordenador,
    required this.cpfCoordenador,
    required this.nomeEquipe,
    required this.nomePastorVoluntario,
    required this.nomePastorEquipe,
    this.nacionalidadeVoluntario = 'Brasileiro(a)',
    this.estadoCivilCoordenador = 'casado',
    this.nacionalidadeCoordenador = 'brasileiro',
    this.dataAprovacao,
    this.dataTexto,
    this.estadoParticipacao,
    this.numeroFicha,
    this.hashAuditoria,
  });

  /// Dados do Voluntário
  final String nomeVoluntario;
  final String nacionalidadeVoluntario;
  final String profissaoVoluntario;
  final String cpfVoluntario;

  /// Dados da Instituição e Coordenador do Maanaim
  final String nomeCoordenador;
  final String nacionalidadeCoordenador;
  final String estadoCivilCoordenador;
  final String cpfCoordenador;

  /// Dados da Equipe de Serviço
  final String nomeEquipe;

  /// Testemunhas canônicas
  /// 1. Pastor do Voluntário = Pastor da Igreja Local do Voluntário
  final String nomePastorVoluntario;

  /// 2. Pastor Chefe da Equipe = Pastor responsável pela equipe
  final String nomePastorEquipe;

  /// Data de emissão/aprovação
  final DateTime? dataAprovacao;
  final String? dataTexto;

  /// Rastreabilidade e estado
  final String? estadoParticipacao;
  final String? numeroFicha;
  final String? hashAuditoria;

  /// Retorna a data formatada por extenso: ex: "15 de outubro de 2026"
  String get dataFormatadaExtenso {
    if (dataTexto != null && dataTexto!.trim().isNotEmpty) {
      return dataTexto!.trim();
    }
    final dt = dataAprovacao ?? DateTime.now();
    final meses = [
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
    final mes = meses[dt.month - 1];
    return '${dt.day} de $mes de ${dt.year}';
  }

  /// Retorna o texto canônico do primeiro parágrafo do termo
  String get textoParagrafoPrincipal {
    final nomeVol = nomeVoluntario.trim().toUpperCase();
    final profVol = profissaoVoluntario.trim().toUpperCase();
    final cpfVol = cpfVoluntario.trim();
    final nomeCoord = nomeCoordenador.trim().toUpperCase();
    final cpfCoord = cpfCoordenador.trim();
    final equipe = nomeEquipe.trim().toUpperCase();

    return '$nomeVol, $nacionalidadeVoluntario, Profissão $profVol, '
        'inscrito(a) no CPF/MF sob o nº $cpfVol, celebra com a '
        'IGREJA CRISTÃ MARANATA, pessoa jurídica de direito privado, '
        'inscrito no CNPJ sob o nº 27.056.910/0001-42, com sede na Rua Torquato Laranja, 90, '
        'Centro, Vila Velha – ES, CEP 29106-720, neste ato, representado pelo Administrador '
        'Voluntário do Maanaim do RIO GRANDE DO NORTE, $nomeCoord, $nacionalidadeCoordenador, '
        '$estadoCivilCoordenador, inscrito no CPF/MF sob o nº $cpfCoord, em conformidade aos '
        'preceitos da Lei nº 9.608 de 18/02/1998, o presente TERMO DE ADESÃO AO SERVIÇO VOLUNTÁRIO '
        'para prestação de serviço na equipe $equipe.';
  }

  /// Retorna o texto do segundo parágrafo
  static const String textoParagrafoSecundario =
      'Por ser verdade declaramos conhecer e aceitar todos os termos da Lei nr 9.608 de 18/02/1998, '
      'que trata sobre o serviço voluntário.';

  /// Retorna o texto do local e data
  String get textoLocalEData => 'Natal – RN, $dataFormatadaExtenso.';
}

import 'package:cloud_functions/cloud_functions.dart';

/// Modelo de resultado da geração de termo em PDF.
class ResultadoGeracaoPdfModel {
  const ResultadoGeracaoPdfModel({
    required this.caminhoStorage,
    required this.urlDownload,
    required this.expiraEm,
    required this.nomeArquivo,
    this.jaExistia = false,
  });

  final String caminhoStorage;
  final String urlDownload;
  final String expiraEm;
  final String nomeArquivo;
  final bool jaExistia;

  factory ResultadoGeracaoPdfModel.fromMap(Map<String, dynamic> map) {
    return ResultadoGeracaoPdfModel(
      caminhoStorage: map['caminhoStorage'] as String? ?? '',
      urlDownload: map['urlDownload'] as String? ?? '',
      expiraEm: map['expiraEm'] as String? ?? '',
      nomeArquivo: map['nomeArquivo'] as String? ?? 'Termo_Voluntariado.pdf',
      jaExistia: map['jaExistia'] as bool? ?? false,
    );
  }
}

/// Modelo de resultado da obtenção de URL de download assinada.
class ResultadoDownloadPdfModel {
  const ResultadoDownloadPdfModel({
    required this.urlDownload,
    required this.expiraEm,
    required this.nomeArquivo,
  });

  final String urlDownload;
  final String expiraEm;
  final String nomeArquivo;

  factory ResultadoDownloadPdfModel.fromMap(Map<String, dynamic> map) {
    return ResultadoDownloadPdfModel(
      urlDownload: map['urlDownload'] as String? ?? '',
      expiraEm: map['expiraEm'] as String? ?? '',
      nomeArquivo: map['nomeArquivo'] as String? ?? 'Termo_Voluntariado.pdf',
    );
  }
}

/// Contrato para operações com PDF privado do termo de voluntariado (AD-6, AD-12, AD-13).
abstract class PdfTermoGateway {
  Future<ResultadoGeracaoPdfModel> gerarPdfParticipacao({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  });

  Future<ResultadoDownloadPdfModel> obterUrlDownloadPdf({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  });
}

/// Implementação real via Cloud Functions autenticadas.
class FirebasePdfTermoGateway implements PdfTermoGateway {
  FirebasePdfTermoGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoGeracaoPdfModel> gerarPdfParticipacao({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  }) async {
    try {
      final callable = _functions.httpsCallable('gerarPdfParticipacao');
      final resposta = await callable.call<Map<String, dynamic>>({
        'fichaId': fichaId,
        'participacaoId': participacaoId,
        if (commandId != null) 'commandId': commandId,
        if (correlationId != null) 'correlationId': correlationId,
      });

      return ResultadoGeracaoPdfModel.fromMap(
        Map<String, dynamic>.from(resposta.data),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Acesso não autorizado para baixar o termo desta equipe.');
      }
      if (e.code == 'failed-precondition') {
        throw Exception(e.message ?? 'A participação precisa estar aprovada para gerar o termo.');
      }
      throw Exception(e.message ?? 'Falha ao gerar o PDF do termo.');
    } catch (e) {
      throw Exception('Erro de comunicação ao gerar o termo: $e');
    }
  }

  @override
  Future<ResultadoDownloadPdfModel> obterUrlDownloadPdf({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  }) async {
    try {
      final callable = _functions.httpsCallable('obterUrlDownloadPdf');
      final resposta = await callable.call<Map<String, dynamic>>({
        'fichaId': fichaId,
        'participacaoId': participacaoId,
        if (commandId != null) 'commandId': commandId,
        if (correlationId != null) 'correlationId': correlationId,
      });

      return ResultadoDownloadPdfModel.fromMap(
        Map<String, dynamic>.from(resposta.data),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Acesso não autorizado para baixar o termo desta equipe.');
      }
      throw Exception(e.message ?? 'Falha ao recuperar a URL de download.');
    } catch (e) {
      throw Exception('Erro ao obter link de download: $e');
    }
  }
}

/// Implementação em memória para testes unitários e visualização offline.
class MemoriaPdfTermoGateway implements PdfTermoGateway {
  MemoriaPdfTermoGateway({
    this.lancarErroAoGerar,
    this.lancarErroAoObterDownload,
    this.urlDownloadRetorno = 'https://storage.googleapis.com/test-bucket/termo.pdf',
  });

  String? lancarErroAoGerar;
  String? lancarErroAoObterDownload;
  String urlDownloadRetorno;
  final List<String> geracoesRegistradas = [];

  @override
  Future<ResultadoGeracaoPdfModel> gerarPdfParticipacao({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  }) async {
    if (lancarErroAoGerar != null) {
      throw Exception(lancarErroAoGerar);
    }
    geracoesRegistradas.add('$fichaId/$participacaoId');
    return ResultadoGeracaoPdfModel(
      caminhoStorage: 'pdfs/$fichaId/$participacaoId.pdf',
      urlDownload: urlDownloadRetorno,
      expiraEm: DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      nomeArquivo: 'Termo_Voluntariado_Equipe.pdf',
    );
  }

  @override
  Future<ResultadoDownloadPdfModel> obterUrlDownloadPdf({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  }) async {
    if (lancarErroAoObterDownload != null) {
      throw Exception(lancarErroAoObterDownload);
    }
    return ResultadoDownloadPdfModel(
      urlDownload: urlDownloadRetorno,
      expiraEm: DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      nomeArquivo: 'Termo_Voluntariado_Equipe.pdf',
    );
  }
}

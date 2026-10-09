import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'contexto_acesso_model.dart';

/// Contrato para comunicação com o backend para obter o contexto de acesso.
abstract interface class ContextoAcessoGateway {
  Future<ContextoAcesso> obterContextoAcesso();
}

/// Implementação padrão que invoca a Cloud Function autenticada `obterContextoAcesso`.
class FirebaseContextoAcessoGateway implements ContextoAcessoGateway {
  FirebaseContextoAcessoGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ContextoAcesso> obterContextoAcesso() async {
    final callable = _functions.httpsCallable('obterContextoAcesso');
    final resultado = await callable.call();
    final dados = (resultado.data as Map).cast<String, dynamic>();
    return ContextoAcesso.fromJson(dados);
  }
}

/// Serviço reativo de gerenciamento e cache de sessão do Contexto de Acesso.
class ContextoAcessoService extends ChangeNotifier {
  ContextoAcessoService(this._gateway);

  final ContextoAcessoGateway _gateway;
  ContextoAcesso? _contextoAtual;
  bool _carregando = false;
  Object? _erro;

  ContextoAcesso? get contextoAtual => _contextoAtual;
  bool get carregando => _carregando;
  Object? get erro => _erro;

  /// Carrega ou recarrega o contexto de acesso via backend.
  Future<ContextoAcesso> carregarContexto({bool forcar = false}) async {
    if (!forcar && _contextoAtual != null) {
      return _contextoAtual!;
    }

    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final contexto = await _gateway.obterContextoAcesso();
      _contextoAtual = contexto;
      _erro = null;
      return contexto;
    } catch (e) {
      _erro = e;
      rethrow;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Invalida o cache atual (usado em logout ou revogação de permissão).
  void invalidar() {
    _contextoAtual = null;
    _erro = null;
    _carregando = false;
    notifyListeners();
  }
}

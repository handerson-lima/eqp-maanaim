import 'package:cloud_functions/cloud_functions.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ResultadoFake<T> implements HttpsCallableResult<T> {
  _ResultadoFake(this.data);

  @override
  final T data;
}

class _CallableFake implements HttpsCallable {
  _CallableFake(this.resposta);

  final Map<String, dynamic> resposta;
  Map<String, dynamic>? ultimosParametros;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    ultimosParametros = (parameters as Map).cast<String, dynamic>();
    return _ResultadoFake<T>(resposta as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FuncoesFake implements FirebaseFunctions {
  _FuncoesFake({this.resposta = const {}});

  final Map<String, dynamic> resposta;
  final List<String> nomesChamados = [];
  _CallableFake? ultimoCallable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    nomesChamados.add(name);
    final callable = _CallableFake(resposta);
    ultimoCallable = callable;
    return callable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FirebaseParticipacaoGateway.solicitarEquipeAdicional', () {
    test('invoca o callable correto com commandId e equipeId e mapeia a resposta',
        () async {
      final funcoes = _FuncoesFake(resposta: {
        'participacaoId': 'part-1',
        'cicloId': 'ciclo-1',
        'equipeId': 'equipe-som',
        'nomeEquipe': 'Som e Mídia',
        'estado': 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        'proximaAcao': 'Aguardando avaliação do Responsável de Equipe',
        'criadoEm': '2026-10-07T12:00:00.000Z',
      });
      final gateway = FirebaseParticipacaoGateway(funcoes);

      final part = await gateway.solicitarEquipeAdicional(
        'equipe-som',
        commandId: 'cmd-fixo-12345678',
      );

      expect(funcoes.nomesChamados, ['solicitarEquipeAdicional']);
      expect(funcoes.ultimoCallable!.ultimosParametros, {
        'commandId': 'cmd-fixo-12345678',
        'equipeId': 'equipe-som',
      });
      expect(part.id, 'part-1');
      expect(part.cicloAtualId, 'ciclo-1');
      expect(part.equipeId, 'equipe-som');
      expect(part.nomeEquipe, 'Som e Mídia');
      expect(part.estado, 'AGUARDANDO_RESPONSAVEL_EQUIPE');
    });

    test('gera commandId opaco quando não informado', () async {
      final funcoes = _FuncoesFake(resposta: {
        'participacaoId': 'part-2',
        'equipeId': 'equipe-louvor',
      });
      final gateway = FirebaseParticipacaoGateway(funcoes);

      await gateway.solicitarEquipeAdicional('equipe-louvor');

      final commandId =
          funcoes.ultimoCallable!.ultimosParametros!['commandId'] as String;
      expect(commandId, isNotEmpty);
      expect(commandId.length, greaterThanOrEqualTo(8));
    });
  });

  group('MemoriaParticipacaoGateway.solicitarEquipeAdicional', () {
    test('adiciona participação em AGUARDANDO_RESPONSAVEL_EQUIPE', () async {
      final gateway = MemoriaParticipacaoGateway();
      gateway.nomesEquipes['equipe-som'] = 'Som e Mídia';

      final part = await gateway.solicitarEquipeAdicional('equipe-som');

      expect(part.estado, 'AGUARDANDO_RESPONSAVEL_EQUIPE');
      expect(part.nomeEquipe, 'Som e Mídia');

      final lista = await gateway.obterMinhasParticipacoes();
      expect(lista.any((p) => p.equipeId == 'equipe-som'), isTrue);
    });
  });
}

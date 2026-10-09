import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/auth/contexto_acesso_model.dart';
import 'package:eqp_maanaim/features/auth/contexto_acesso_service.dart';

class MockContextoAcessoGateway implements ContextoAcessoGateway {
  MockContextoAcessoGateway(this.contexto);
  ContextoAcesso contexto;

  @override
  Future<ContextoAcesso> obterContextoAcesso() async => contexto;
}

void main() {
  group('Story 8.3: ContextoAcesso e CapacidadeAcesso Models', () {
    test('desserializa voluntário simples a partir de JSON', () {
      final json = {
        'uid': 'voluntario-123',
        'email': 'voluntario@teste.com',
        'capacidades': ['voluntario'],
        'ehAdministrador': false,
        'ehCoordenador': false,
        'ehPastorLocal': false,
        'ehResponsavelEquipe': false,
        'ehVoluntario': true,
        'igrejas': <Map<String, dynamic>>[],
        'equipes': <Map<String, dynamic>>[],
        'estadoFicha': 'ATIVA',
      };

      final contexto = ContextoAcesso.fromJson(json);

      expect(contexto.uid, equals('voluntario-123'));
      expect(contexto.email, equals('voluntario@teste.com'));
      expect(contexto.ehVoluntario, isTrue);
      expect(contexto.ehPastorLocal, isFalse);
      expect(contexto.ehResponsavelEquipe, isFalse);
      expect(contexto.ehAdministrador, isFalse);
      expect(contexto.ehCoordenador, isFalse);
      expect(contexto.temCapacidade(CapacidadeAcesso.voluntario), isTrue);
      expect(contexto.temCapacidade(CapacidadeAcesso.pastorLocal), isFalse);
      expect(contexto.temMultiplosDestinos, isFalse);
      expect(contexto.estadoFicha, equals('ATIVA'));
    });

    test('desserializa Pastor Local exclusivo com escopo de igrejas', () {
      final json = {
        'uid': 'pastor-1',
        'capacidades': ['voluntario', 'pastor_local'],
        'ehPastorLocal': true,
        'igrejas': [
          {'id': 'ig-central', 'nome': 'Maanaim Central', 'codigo': 'IG-01'},
        ],
        'equipes': <Map<String, dynamic>>[],
      };

      final contexto = ContextoAcesso.fromJson(json);

      expect(contexto.ehPastorLocal, isTrue);
      expect(contexto.temCapacidade(CapacidadeAcesso.pastorLocal), isTrue);
      expect(contexto.igrejas, hasLength(1));
      expect(contexto.igrejas.first.nome, equals('Maanaim Central'));
      expect(contexto.igrejas.first.codigo, equals('IG-01'));
      expect(contexto.temMultiplosDestinos, isFalse);
    });

    test('desserializa múltiplos vínculos simultâneos (Pastor Local + Responsável de Equipe)', () {
      final json = {
        'uid': 'lider-duplo',
        'capacidades': ['voluntario', 'pastor_local', 'responsavel_equipe'],
        'ehPastorLocal': true,
        'ehResponsavelEquipe': true,
        'igrejas': [
          {'id': 'ig-norte', 'nome': 'Igreja Norte'},
        ],
        'equipes': [
          {'id': 'eq-louvor', 'nome': 'Equipe de Louvor'},
        ],
      };

      final contexto = ContextoAcesso.fromJson(json);

      expect(contexto.ehPastorLocal, isTrue);
      expect(contexto.ehResponsavelEquipe, isTrue);
      expect(contexto.temCapacidade(CapacidadeAcesso.pastorLocal), isTrue);
      expect(contexto.temCapacidade(CapacidadeAcesso.responsavelEquipe), isTrue);
      expect(contexto.temMultiplosDestinos, isTrue);
      expect(contexto.igrejas, hasLength(1));
      expect(contexto.equipes, hasLength(1));
    });

    test('ContextoAcessoService gerencia cache, carregamento e invalidação', () async {
      final contextoInicial = ContextoAcesso.fromJson({
        'uid': 'user-1',
        'capacidades': ['voluntario', 'pastor_local'],
        'ehPastorLocal': true,
      });

      final mockGateway = MockContextoAcessoGateway(contextoInicial);
      final service = ContextoAcessoService(mockGateway);

      expect(service.contextoAtual, isNull);
      expect(service.carregando, isFalse);

      final obtido = await service.carregarContexto();
      expect(obtido.uid, equals('user-1'));
      expect(service.contextoAtual, equals(obtido));

      // Invalidação em logout ou revogação
      service.invalidar();
      expect(service.contextoAtual, isNull);
    });
  });
}

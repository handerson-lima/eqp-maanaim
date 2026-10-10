import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/termo/termo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/features/voluntario/solicitacao_equipe_screen.dart';
import 'package:eqp_maanaim/ui/components/stepper.dart';
import 'package:eqp_maanaim/ui/tokens.dart';

class CatalogoFakeGateway implements CatalogoGateway {
  CatalogoFakeGateway({
    this.equipes = const [
      EquipeCatalogo(id: 'eq-louvor', nome: 'Louvor e Adoração', ativo: true),
      EquipeCatalogo(id: 'eq-midia', nome: 'Mídia e Som', ativo: true),
      EquipeCatalogo(id: 'eq-infantil', nome: 'Trabalho de Crianças', ativo: true),
      EquipeCatalogo(id: 'eq-inativa', nome: 'Equipe Desativada', ativo: false),
    ],
    this.igrejas = const [
      IgrejaCatalogo(id: 'ig-central', nome: 'Igreja Central', codigo: 'IC01', ativo: true),
    ],
  });

  final List<EquipeCatalogo> equipes;
  final List<IgrejaCatalogo> igrejas;

  @override
  Future<CatalogoResposta> consultar({String? termo}) async {
    return CatalogoResposta(igrejas: igrejas, equipes: equipes);
  }

  @override
  Future<void> alternarStatusIgreja({
    required String commandId,
    required String igrejaId,
    required bool ativo,
    String? correlationId,
  }) async {}

  @override
  Future<void> alternarStatusEquipe({
    required String commandId,
    required String equipeId,
    required bool ativo,
    String? correlationId,
  }) async {}

  @override
  Future<void> salvarIgreja({
    required String commandId,
    required String nome,
    required String codigo,
    required int expectedVersion,
    String? igrejaId,
    String? correlationId,
  }) async {}

  @override
  Future<void> salvarEquipe({
    required String commandId,
    required String nome,
    required int expectedVersion,
    String? equipeId,
    String? correlationId,
  }) async {}
}

class FichaFakeGateway implements FichaGateway {
  FichaFakeGateway({
    this.ficha,
    this.deveFalharEnvio = false,
  });

  FichaModel? ficha;
  bool deveFalharEnvio;
  int chamadasEnvio = 0;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    return ObterFichaResposta(existe: ficha != null, ficha: ficha);
  }

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async {
    return SalvarFichaResposta(sucesso: true, repetido: false, ficha: ficha!);
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    chamadasEnvio++;
    if (deveFalharEnvio) {
      throw Exception('Falha simulada no envio da ficha para aprovação');
    }
    return EnviarFichaResposta(
      sucesso: true,
      repetido: false,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: 2,
      proximaAcao: 'Aguardando aprovação pastoral',
      igrejaId: ficha?.igrejaId ?? 'ig-central',
      enviadoEm: '2026-10-09T18:00:00Z',
    );
  }

  @override
  Future<void> cancelarVoluntariado({
    required String fichaId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {}
}

class ParticipacaoFakeGateway implements ParticipacaoGateway {
  ParticipacaoFakeGateway({
    List<ParticipacaoModel>? participacoes,
    this.deveFalhar = false,
  }) : participacoes = participacoes ?? [];

  final List<ParticipacaoModel> participacoes;
  bool deveFalhar;
  int chamadasSalvarRascunho = 0;
  int chamadasSolicitarAdicional = 0;
  List<String> ultimoLoteRascunho = [];
  String? ultimaEquipeAdicional;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async {
    return List.unmodifiable(participacoes);
  }

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async {
    chamadasSalvarRascunho++;
    ultimoLoteRascunho = List.of(equipeIds);
    return List.unmodifiable(participacoes);
  }

  @override
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  }) async {
    chamadasSolicitarAdicional++;
    ultimaEquipeAdicional = equipeId;
    if (deveFalhar) {
      throw Exception('Erro ao solicitar equipe adicional');
    }
    final nova = ParticipacaoModel(
      id: 'part-$equipeId',
      fichaId: 'ficha-01',
      equipeId: equipeId,
      nomeEquipe: 'Equipe $equipeId',
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao: 'Aguardando responsável de equipe',
    );
    participacoes.add(nova);
    return nova;
  }

  @override
  Future<void> cancelarParticipacao({
    required String participacaoId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async {
    return [];
  }

  @override
  Future<ParticipacaoModel> solicitarReativacao({
    required String equipeId,
    String? justificativa,
    String? participacaoId,
    String? commandId,
  }) async {
    throw UnimplementedError();
  }
}

class TermoFakeGateway implements TermoGateway {
  TermoFakeGateway({
    this.termoVigente = const TermoVigenteModel(
      id: 'versao-1',
      termoId: 'termo-adesao-voluntariado',
      numeroVersao: 1,
      titulo: 'Termo de Adesão ao Serviço Voluntário 2026',
      conteudo: 'Texto do termo de adesão institucional...',
      hashSha256: 'hash-termo-abc-123',
      publicadoEm: '2026-09-28T00:00:00Z',
    ),
    this.deveFalharAceite = false,
  });

  final TermoVigenteModel? termoVigente;
  bool deveFalharAceite;
  int chamadasAceite = 0;

  @override
  Future<TermoVigenteModel?> obterTermoVigente({String? termoId}) async {
    return termoVigente;
  }

  @override
  Future<ComprovanteAceiteModel> aceitarTermoVigente({
    required String commandId,
    required String versaoId,
    required String hashSha256,
    required bool declaracaoLidoEConcordo,
    String? correlationId,
    String? termoId,
  }) async {
    chamadasAceite++;
    if (deveFalharAceite) {
      throw Exception('Erro de teste ao aceitar termo');
    }
    return ComprovanteAceiteModel(
      id: 'comp-1',
      uid: 'user-1',
      fichaId: 'ficha-01',
      termoId: termoId ?? 'termo-adesao-voluntariado',
      versaoId: versaoId,
      numeroVersao: 1,
      hashSha256: hashSha256,
      titulo: 'Termo Aceito',
      declaracaoLidoEConcordo: declaracaoLidoEConcordo,
      aceitoEm: '2026-10-09T18:00:00Z',
      commandId: commandId,
    );
  }

  @override
  Future<List<ComprovanteAceiteModel>> obterHistoricoAceites() async {
    return [];
  }
}

Widget _construirAppTeste({
  required Widget child,
  double largura = 1200,
  double altura = 1200,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue600),
      useMaterial3: true,
    ),
    home: MediaQuery(
      data: MediaQueryData(size: Size(largura, altura)),
      child: child,
    ),
  );
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Story 8.8 — Solicitação de equipe em etapas (Tela S03)', () {
    late CatalogoFakeGateway catalogoGateway;
    late FichaFakeGateway fichaGateway;
    late ParticipacaoFakeGateway participacaoGateway;
    late TermoFakeGateway termoGateway;
    late FichaModel fichaPadrao;

    setUp(() {
      catalogoGateway = CatalogoFakeGateway();
      fichaPadrao = const FichaModel(
        id: 'ficha-01',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Engenheiro',
        cpf: '12345678901',
        igrejaId: 'ig-central',
        telefone: '84999999999',
        estado: 'RASCUNHO',
        versao: 1,
        termoAceito: null,
        proximaAcao: 'Selecionar equipes e assinar termo',
      );
      fichaGateway = FichaFakeGateway(ficha: fichaPadrao);
      participacaoGateway = ParticipacaoFakeGateway();
      termoGateway = TermoFakeGateway();
    });

    testWidgets('1. Stepper responsivo: horizontal no desktop (≥600px) e compacto no mobile (<600px)',
        (tester) async {
      // Teste Desktop (1200px)
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          largura: 1200,
          altura: 1000,
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica AppStepper presente
      expect(find.byType(AppStepper), findsOneWidget);
      // No desktop, os títulos das etapas aparecem na linha horizontal
      expect(find.text('Seleção de Equipes'), findsWidgets);
      expect(find.text('Termo de Adesão'), findsWidgets);
      expect(find.text('Revisão'), findsWidgets);
      expect(find.text('Envio'), findsWidgets);

      // Teste Mobile (380px)
      await tester.binding.setSurfaceSize(const Size(380, 800));
      await tester.pumpWidget(
        _construirAppTeste(
          largura: 380,
          altura: 800,
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No mobile, deve exibir o indicador compacto "Etapa 1 de 4"
      expect(find.text('Etapa 1 de 4'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('2. Grid de equipes com busca, seleção múltipla e tokens navy/blue nos cards',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // As equipes ativas devem estar visíveis no grid
      expect(find.text('Louvor e Adoração'), findsOneWidget);
      expect(find.text('Mídia e Som'), findsOneWidget);
      expect(find.text('Trabalho de Crianças'), findsOneWidget);
      // A desativada não deve aparecer
      expect(find.text('Equipe Desativada'), findsNothing);

      // Teste do campo de busca
      await tester.enterText(find.byKey(const Key('campo_busca_equipes_solicitacao')), 'Louvor');
      await tester.pumpAndSettle();
      expect(find.text('Louvor e Adoração'), findsOneWidget);
      expect(find.text('Mídia e Som'), findsNothing);

      // Limpa busca
      await tester.enterText(find.byKey(const Key('campo_busca_equipes_solicitacao')), '');
      await tester.pumpAndSettle();

      // Seleciona duas equipes
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-louvor')));
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-midia')));

      // Contador de selecionadas
      expect(find.text('2 equipe(s) selecionada(s)'), findsOneWidget);

      // Card selecionado deve ter ícone de checkbox marcado
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));
    });

    testWidgets('3. Validação de seleção: impede avançar para Etapa 1 sem equipe selecionada',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tenta avançar com 0 equipes selecionadas
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));

      // Deve exibir mensagem de erro e continuar na Etapa 0
      expect(find.text('Selecione pelo menos uma equipe para prosseguir.'), findsOneWidget);
      expect(find.text('1. Seleção de Equipes'), findsOneWidget);
    });

    testWidgets('4. Preservação de rascunho ao navegar entre as etapas (Voltar preserva seleção)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleciona Louvor
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-louvor')));
      expect(find.text('1 equipe(s) selecionada(s)'), findsOneWidget);

      // Avança para a Etapa 1 (Termo)
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));
      expect(find.text('2. Termo de Adesão ao Serviço Voluntário'), findsOneWidget);

      // Clica em Voltar para retornar à Etapa 0 (Seleção)
      await _tocar(tester, find.byKey(const Key('btn_voltar_etapa_solicitacao')));
      expect(find.text('1. Seleção de Equipes'), findsOneWidget);

      // A seleção anterior de Louvor DEVE estar preservada intacta!
      expect(find.text('1 equipe(s) selecionada(s)'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
    });

    testWidgets('5. Termo de adesão exige aceite explícito antes de avançar para a Revisão',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleciona equipe e vai para a Etapa 1 (Termo)
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-louvor')));
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));

      // Tenta avançar SEM aceitar o termo
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));

      // Exige aceite explícito
      expect(find.text('Você deve ler e aceitar o Termo de Adesão para continuar.'), findsOneWidget);
      expect(find.text('2. Termo de Adesão ao Serviço Voluntário'), findsOneWidget);

      // Marca o checkbox de aceite
      await _tocar(tester, find.byKey(const Key('checkbox_aceite_termo_solicitacao')));

      // Agora o avanço deve ser permitido para a Etapa 2 (Revisão)
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));
      expect(find.text('3. Revisão da Solicitação'), findsOneWidget);
    });

    testWidgets('6. Revisão exibe dados completos e Envio registra solicitação com sucesso',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Etapa 0: Seleciona Louvor e Crianças
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-louvor')));
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-infantil')));
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));

      // Etapa 1: Aceita termo e avança
      await _tocar(tester, find.byKey(const Key('checkbox_aceite_termo_solicitacao')));
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));

      // Etapa 2: Revisão
      expect(find.text('3. Revisão da Solicitação'), findsOneWidget);
      expect(find.text('Gabriel Silva'), findsOneWidget);
      expect(find.text('Igreja Central'), findsOneWidget);
      expect(find.text('Equipes Solicitadas (2)'), findsOneWidget);

      // Avança para Etapa 3 (Envio)
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));
      expect(find.text('4. Confirmação e Envio'), findsOneWidget);

      // Confirma e envia
      await _tocar(tester, find.byKey(const Key('btn_confirmar_envio_solicitacao')));

      // Feedback de sucesso com protocolo e botão de ir para o Início
      expect(find.text('Solicitação Enviada com Sucesso!'), findsOneWidget);
      expect(find.text('Suas equipes foram solicitadas!'), findsOneWidget);
      expect(find.byKey(const Key('btn_ir_para_inicio_voluntario')), findsOneWidget);
      expect(fichaGateway.chamadasEnvio, equals(1));
    });

    testWidgets('7. Modo adicional unitário mantém participações ativas intactas',
        (tester) async {
      // Voluntário já tem participação ativa em Louvor
      final participacaoAtiva = const ParticipacaoModel(
        id: 'part-ativa-01',
        fichaId: 'ficha-01',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Louvor e Adoração',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
      );
      participacaoGateway = ParticipacaoFakeGateway(participacoes: [participacaoAtiva]);

      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      await tester.pumpWidget(
        _construirAppTeste(
          child: SolicitacaoEquipeScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            termoGateway: termoGateway,
            modoAdicional: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Louvor deve estar marcado como inelegível (já inscrito)
      expect(find.text('Já inscrito'), findsOneWidget);
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-louvor')));
      // Não deve ter sido selecionada
      expect(find.text('0 equipe(s) selecionada(s)'), findsOneWidget);

      // Seleciona Mídia
      await _tocar(tester, find.byKey(const Key('card_equipe_eq-midia')));
      expect(find.text('1 equipe(s) selecionada(s)'), findsOneWidget);

      // Avança para o Termo
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));
      await _tocar(tester, find.byKey(const Key('checkbox_aceite_termo_solicitacao')));

      // Avança para Revisão
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));
      expect(find.text('Equipes Solicitadas (1)'), findsOneWidget);

      // Avança para Envio e Submete
      await _tocar(tester, find.byKey(const Key('btn_avancar_etapa_solicitacao')));
      await _tocar(tester, find.byKey(const Key('btn_confirmar_envio_solicitacao')));

      // Deve ter chamado solicitarEquipeAdicional para a nova equipe
      expect(participacaoGateway.chamadasSolicitarAdicional, equals(1));
      expect(participacaoGateway.ultimaEquipeAdicional, equals('eq-midia'));
      // A participação ativa em Louvor permanece intacta!
      expect(participacaoGateway.participacoes.any((p) => p.equipeId == 'eq-louvor' && p.isAtiva), isTrue);
    });
  });
}

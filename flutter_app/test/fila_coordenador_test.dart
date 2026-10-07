import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/coordenador/fila_coordenador_screen.dart';
import 'package:eqp_maanaim/features/coordenador/coordenador_service.dart';
import 'package:eqp_maanaim/ui/theme.dart';

void main() {
  final part1 = const ParticipacaoItemCoordenador(
    participacaoId: 'part-01',
    equipeId: 'eq-cozinha',
    nomeEquipe: 'Cozinha',
    estado: 'AGUARDANDO_COORDENADOR',
    proximaAcao: 'Aguardando conclusão do Coordenador',
    responsavelNome: 'Pr. André (Cozinha)',
    responsavelDecididoEm: '2026-10-06T12:00:00Z',
    elegivelAtivacao: true,
  );

  final part2 = const ParticipacaoItemCoordenador(
    participacaoId: 'part-02',
    equipeId: 'eq-louvor',
    nomeEquipe: 'Louvor',
    estado: 'REJEITADA',
    proximaAcao: 'Procure o Pastor da igreja local para mais informações',
    responsavelNome: 'Pr. Marcos (Louvor)',
    responsavelDecididoEm: '2026-10-06T11:00:00Z',
    justificativaResponsavel: 'Vagas esgotadas',
    elegivelAtivacao: false,
  );

  final itemExemplo1 = ItemFilaCoordenador(
    fichaId: 'ficha-01',
    voluntarioUid: 'vol-01',
    voluntarioNome: 'Lucas Oliveira',
    profissao: 'Analista de Sistemas',
    cpfMascarado: '111.***.***-22',
    igrejaId: 'igreja-central',
    nomeIgreja: 'Igreja Central',
    versaoFicha: 1,
    enviadoEm: '2026-10-06T09:00:00Z',
    pastorLocalNome: 'Pastor Paulo',
    pastorLocalDecididoEm: '2026-10-06T10:00:00Z',
    participacoes: [part1, part2],
  );

  Widget criarApp(CoordenadorGateway gateway) {
    return MaterialApp(
      theme: temaMaanaim(),
      home: FilaCoordenadorScreen(gateway: gateway),
    );
  }

  testWidgets('exibe cards de pendências com dados do voluntário, parecer local e equipes', (tester) async {
    final gateway = MemoriaCoordenadorGateway(
      pendenciasIniciais: [itemExemplo1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Fila de Conclusão do Coordenador'), findsOneWidget);
    expect(find.text('Lucas Oliveira'), findsOneWidget);
    expect(find.text('Igreja: Igreja Central'), findsOneWidget);
    expect(find.text('CPF: 111.***.***-22'), findsOneWidget);
    expect(find.text('Profissão: Analista de Sistemas'), findsOneWidget);
    expect(find.textContaining('Aprovado pelo Pastor Local: Pastor Paulo'), findsOneWidget);
    expect(find.text('Cozinha'), findsOneWidget);
    expect(find.text('Louvor'), findsOneWidget);
    expect(find.text('Aguardando Coordenação'), findsOneWidget);
    expect(find.byKey(const Key('btnAprovar_ficha-01')), findsOneWidget);
    expect(find.byKey(const Key('btnRecusar_ficha-01')), findsOneWidget);
  });

  testWidgets('exibe mensagem amigável quando fila está vazia', (tester) async {
    final gateway = MemoriaCoordenadorGateway(
      pendenciasIniciais: [],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma solicitação pendente!'), findsOneWidget);
    expect(
      find.text(
        'Não há solicitações com todas as equipes resolvidas aguardando conclusão do Coordenador.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('aprovação exige confirmação explícita da Reunião de Pastores', (tester) async {
    final gateway = MemoriaCoordenadorGateway(
      pendenciasIniciais: [itemExemplo1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Clica em "Homologar e Ativar"
    await tester.tap(find.byKey(const Key('btnAprovar_ficha-01')));
    await tester.pumpAndSettle();

    expect(find.text('Homologar e Ativar Voluntariado'), findsOneWidget);
    expect(find.byKey(const Key('chkConfirmarReuniao')), findsOneWidget);

    final btnConfirmar = tester.widget<ElevatedButton>(
      find.byKey(const Key('btnConfirmarAtivacaoModal')),
    );
    // Deve estar desabilitado enquanto o checkbox não estiver marcado
    expect(btnConfirmar.onPressed, isNull);

    // Marca o checkbox
    await tester.tap(find.byKey(const Key('chkConfirmarReuniao')));
    await tester.pumpAndSettle();

    final btnConfirmarHabilitado = tester.widget<ElevatedButton>(
      find.byKey(const Key('btnConfirmarAtivacaoModal')),
    );
    expect(btnConfirmarHabilitado.onPressed, isNotNull);

    // Clica em Confirmar Ativação
    await tester.tap(find.byKey(const Key('btnConfirmarAtivacaoModal')));
    await tester.pumpAndSettle();

    expect(find.text('Voluntariado ativado com sucesso!'), findsOneWidget);
    expect(gateway.historicoDecisoes, hasLength(1));
    expect(gateway.historicoDecisoes.first['decisao'], 'APROVADO');
    expect(gateway.historicoDecisoes.first['confirmouReuniaoPastores'], true);
  });

  testWidgets('decisão desfavorável exige justificativa interna com mínimo de 5 caracteres', (tester) async {
    final gateway = MemoriaCoordenadorGateway(
      pendenciasIniciais: [itemExemplo1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Clica em "Recusar"
    await tester.tap(find.byKey(const Key('btnRecusar_ficha-01')));
    await tester.pumpAndSettle();

    expect(find.text('Decisão Desfavorável'), findsOneWidget);
    expect(
      find.text(
        'A justificativa interna será gravada como evidência restrita da decisão (não vai para a auditoria geral). Ao voluntário será exibido exclusivamente: "Procure o Pastor da igreja local para mais informações".',
      ),
      findsOneWidget,
    );

    // Tenta confirmar sem preencher
    await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
    await tester.pumpAndSettle();

    expect(find.text('Mínimo de 5 caracteres obrigatório.'), findsOneWidget);
    expect(gateway.historicoDecisoes, isEmpty);

    // Digita justificativa válida
    await tester.enterText(
      find.byKey(const Key('campoJustificativaRecusa')),
      'Decisão contrária em reunião de pastores por pendência cadastral.',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
    await tester.pumpAndSettle();

    expect(
      find.text('Decisão desfavorável registrada com sucesso.'),
      findsOneWidget,
    );
    expect(gateway.historicoDecisoes, hasLength(1));
    expect(gateway.historicoDecisoes.first['decisao'], 'DESFAVORAVEL');
    expect(
      gateway.historicoDecisoes.first['observacao'],
      'Decisão contrária em reunião de pastores por pendência cadastral.',
    );
  });

  testWidgets('exibe mensagem de erro e botão de tentar novamente quando carregar falhar', (tester) async {
    final gateway = MemoriaCoordenadorGateway(
      erroAoObterFila: Exception('Falha de conexão'),
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar a fila do coordenador.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('falha ao decidir exibe aviso e mantém o item na fila', (tester) async {
    final gateway = MemoriaCoordenadorGateway(
      pendenciasIniciais: [itemExemplo1],
      erroAoDecidir: Exception('falha simulada'),
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btnAprovar_ficha-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chkConfirmarReuniao')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btnConfirmarAtivacaoModal')));
    await tester.pumpAndSettle();

    expect(
      find.text('Erro ao registrar decisão do coordenador. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('btnAprovar_ficha-01')), findsOneWidget);
  });

  testWidgets('AdminShell conecta a Fila do Coordenador', (tester) async {
    final gateway = MemoriaCoordenadorGateway(pendenciasIniciais: [itemExemplo1]);

    await tester.pumpWidget(MaterialApp(
      home: AdminShell(onSair: () {}, coordenador: gateway),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fila do Coordenador'), findsOneWidget);
    await tester.tap(find.text('Fila do Coordenador'));
    await tester.pumpAndSettle();

    expect(find.byType(FilaCoordenadorScreen), findsOneWidget);
  });
}

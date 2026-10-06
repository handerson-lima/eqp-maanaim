import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eqp_maanaim/features/termo/termo_adesao_model.dart';
import 'package:eqp_maanaim/features/termo/termo_adesao_widget.dart';
import 'package:eqp_maanaim/features/termo/termo_dialog.dart';
import 'package:eqp_maanaim/features/termo/termo_html_template.dart';

void main() {
  const modelTeste = TermoAdesaoModel(
    nomeVoluntario: 'JOÃO SILVA SANTOS',
    profissaoVoluntario: 'ANALISTA DE SISTEMAS',
    cpfVoluntario: '123.456.789-00',
    nomeCoordenador: 'CARLOS ALBERTO COORDENADOR',
    cpfCoordenador: '987.654.321-99',
    nomeEquipe: 'SEGURANÇA',
    nomePastorVoluntario: 'PASTOR JOSÉ DE SOUZA',
    nomePastorEquipe: 'PASTOR MANOEL CARNEIRO',
    dataTexto: '15 de outubro de 2026',
  );

  group('TermoAdesaoModel & HTML Template', () {
    test('formata campos dinâmicos e parágrafos canônicos corretamente', () {
      expect(modelTeste.dataFormatadaExtenso, '15 de outubro de 2026');
      expect(modelTeste.textoLocalEData, 'Natal – RN, 15 de outubro de 2026.');

      final textoPrincipal = modelTeste.textoParagrafoPrincipal;
      expect(textoPrincipal, contains('JOÃO SILVA SANTOS'));
      expect(textoPrincipal, contains('ANALISTA DE SISTEMAS'));
      expect(textoPrincipal, contains('123.456.789-00'));
      expect(textoPrincipal, contains('CARLOS ALBERTO COORDENADOR'));
      expect(textoPrincipal, contains('987.654.321-99'));
      expect(textoPrincipal, contains('SEGURANÇA'));
      expect(textoPrincipal, contains('Lei nº 9.608'));
    });

    test('gera HTML completo com CSS de impressão e marcas do documento', () {
      final html = gerarHtmlTermoAdesao(modelTeste);
      expect(html, contains('MAANAIM DO RIO GRANDE DO NORTE'));
      expect(html, contains('TERMO DE ADESÃO DE VOLUNTÁRIO'));
      expect(html, contains('Lei do Serviço Voluntário (LEI 9.608/1998)'));
      expect(html, contains('JOÃO SILVA SANTOS'));
      expect(html, contains('CARLOS ALBERTO COORDENADOR'));
      expect(html, contains('PASTOR JOSÉ DE SOUZA'));
      expect(html, contains('PASTOR MANOEL CARNEIRO'));
      expect(html, contains('@page'));
      expect(html, contains('A4 portrait'));
      expect(html, contains('data:image/png;base64'));
    });
  });

  group('TermoAdesaoWidget', () {
    testWidgets('renderiza fielmente os títulos, corpo e assinaturas do modelo',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TermoAdesaoWidget(model: modelTeste),
          ),
        ),
      );

      // Logo oficial
      expect(find.byType(Image), findsOneWidget);

      // Títulos principais
      expect(find.text('MAANAIM DO RIO GRANDE DO NORTE'), findsOneWidget);
      expect(find.text('TERMO DE ADESÃO DE VOLUNTÁRIO'), findsOneWidget);
      expect(find.text('Lei do Serviço Voluntário (LEI 9.608/1998)'), findsOneWidget);

      // Bloco de testemunhas e assinaturas
      expect(find.text('TESTEMUNHAS:'), findsOneWidget);
      expect(find.text('JOÃO SILVA SANTOS'), findsOneWidget);
      expect(find.text('CARLOS ALBERTO COORDENADOR'), findsOneWidget);
      expect(find.text('PASTOR JOSÉ DE SOUZA'), findsOneWidget);
      expect(find.text('PASTOR MANOEL CARNEIRO'), findsOneWidget);

      // Botão de impressão
      expect(find.byKey(const Key('botao_imprimir_termo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('botao_imprimir_termo')));
      await tester.pump();
    });

    testWidgets('exibe em diálogo fullscreen via exibirTermoAdesaoDialog',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => exibirTermoAdesaoDialog(ctx, modelTeste),
                child: const Text('Abrir Termo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Termo'));
      await tester.pumpAndSettle();

      expect(find.text('Termo de Adesão de Voluntário'), findsOneWidget);
      expect(find.text('MAANAIM DO RIO GRANDE DO NORTE'), findsOneWidget);

      // Fechar modal
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir Termo'), findsOneWidget);
    });
  });
}

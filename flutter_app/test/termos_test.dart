import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eqp_maanaim/features/admin/termos_screen.dart';
import 'package:eqp_maanaim/features/admin/termos_service.dart';
import 'package:eqp_maanaim/ui/identidade.dart';

import 'fakes.dart';

Widget _tela(TermosGateway gateway, {double escala = 1.0}) => MaterialApp(
      theme: temaMaanaim(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: TermosScreen(gateway: gateway),
      ),
    );

void _definirTamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Modelos e Gateway de Termos', () {
    test('converte VersaoTermo de map e formata hash', () {
      final versao = VersaoTermo.fromMap({
        'id': 'v-1',
        'termoId': 'termo-1',
        'numeroVersao': 1,
        'titulo': 'Termo de Adesão',
        'conteudo': 'Conteúdo completo do termo de adesão ao serviço voluntário.',
        'hashSha256': '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'publicadoEm': '2026-09-30T15:00:00.000Z',
        'publicadoPorUid': 'admin-uid',
        'imutavel': true,
      });

      expect(versao.numeroVersao, 1);
      expect(versao.rotuloVersao, 'v1');
      expect(versao.hashResumido, '1234567890ab...');
      expect(versao.imutavel, isTrue);
      expect(versao.publicadoEm, isNotNull);
    });

    test('TermosFake publica primeira versão e acumula histórico', () async {
      final fake = TermosFake();
      expect(await fake.consultarTermos(), isNull);

      final resultado = await fake.publicarTermo(
        commandId: 'cmd-1',
        titulo: 'Termo Inicial',
        conteudo: 'Conteúdo do termo com mais de vinte caracteres obrigatórios.',
        expectedVersion: 0,
      );

      expect(resultado.concluido, isTrue);
      expect(resultado.numeroVersao, 1);
      expect(resultado.hashSha256, isNotEmpty);

      final termoAtual = await fake.consultarTermos();
      expect(termoAtual, isNotNull);
      expect(termoAtual!.totalVersoes, 1);
      expect(termoAtual.versaoVigenteNumero, 1);
      expect(termoAtual.versoes, hasLength(1));

      // Publica segunda versão
      final resultado2 = await fake.publicarTermo(
        commandId: 'cmd-2',
        titulo: 'Termo v2',
        conteudo: 'Conteúdo atualizado da segunda versão com texto longo.',
        expectedVersion: 1,
      );

      expect(resultado2.numeroVersao, 2);
      final termoAtualizado = await fake.consultarTermos();
      expect(termoAtualizado!.totalVersoes, 2);
      expect(termoAtualizado.versaoVigenteNumero, 2);
      expect(termoAtualizado.versoes, hasLength(2));
    });
  });

  group('TermosScreen - Renderização e Interação', () {
    testWidgets('exibe estado vazio quando não há termo publicado', (tester) async {
      _definirTamanho(tester, const Size(1000, 800));
      final fake = TermosFake();

      await tester.pumpWidget(_tela(fake));
      await tester.pumpAndSettle();

      expect(find.text('Termos e Versões'), findsOneWidget);
      expect(find.text('Nenhum termo publicado'), findsOneWidget);
      expect(find.text('Publicar Primeiro Termo'), findsOneWidget);
    });

    testWidgets('valida campos obrigatórios no formulário de publicação', (tester) async {
      _definirTamanho(tester, const Size(1000, 800));
      final fake = TermosFake();

      await tester.pumpWidget(_tela(fake));
      await tester.pumpAndSettle();

      // Clica em Nova Versão para abrir o formulário
      await tester.tap(find.text('Nova Versão'));
      await tester.pumpAndSettle();

      expect(find.text('Publicar 1ª Versão do Termo'), findsOneWidget);

      // Tenta submeter vazio
      await tester.tap(find.text('Revisar e Publicar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe um título com pelo menos 3 caracteres.'), findsOneWidget);
      expect(find.text('O conteúdo deve ter no mínimo 20 caracteres.'), findsOneWidget);
    });

    testWidgets('exibe modal de confirmação de imutabilidade e publica primeira versão', (tester) async {
      _definirTamanho(tester, const Size(1000, 900));
      final fake = TermosFake();

      await tester.pumpWidget(_tela(fake));
      await tester.pumpAndSettle();

      // Abre formulário
      await tester.tap(find.text('Nova Versão'));
      await tester.pumpAndSettle();

      // Preenche dados válidos
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título do Termo *'),
        'Termo de Adesão ao Serviço Voluntário',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Conteúdo Integral do Termo *'),
        'Cláusula 1: O voluntário declara ciência de todas as condições estabelecidas no Maanaim.',
      );
      await tester.pumpAndSettle();

      // Clica em Revisar e Publicar
      await tester.tap(find.text('Revisar e Publicar'));
      await tester.pumpAndSettle();

      // Modal de confirmação com aviso de imutabilidade deve estar visível
      expect(find.text('Confirmar Publicação'), findsOneWidget);
      expect(
        find.textContaining('Atenção: A publicação da versão 1 é definitiva e estritamente imutável.'),
        findsOneWidget,
      );

      // Confirma no modal
      await tester.tap(find.text('Confirmar e Publicar'));
      await tester.pumpAndSettle();

      // Mensagem de sucesso
      expect(find.textContaining('publicada com sucesso!'), findsOneWidget);

      // Agora deve exibir o card do termo vigente
      expect(find.text('Termo Vigente'), findsOneWidget);
      expect(find.text('Vigente v1'), findsOneWidget);
      expect(find.text('Histórico de Versões (1)'), findsOneWidget);
    });

    testWidgets('abre modal com texto completo ao clicar no histórico', (tester) async {
      _definirTamanho(tester, const Size(1000, 800));
      final fake = TermosFake(
        termo: TermoVigente(
          id: 'termo-1',
          tipoTermo: 'ADESAO_VOLUNTARIADO',
          titulo: 'Termo de Voluntariado',
          versaoVigenteId: 'v-1',
          versaoVigenteNumero: 1,
          hashSha256: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          totalVersoes: 1,
          versoes: [
            VersaoTermo(
              id: 'v-1',
              termoId: 'termo-1',
              numeroVersao: 1,
              titulo: 'Termo de Voluntariado',
              conteudo: 'Texto integral longo e detalhado da versão 1 para verificação do modal.',
              hashSha256: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
              publicadoEm: DateTime.now().toUtc(),
              publicadoPorUid: 'admin-1',
              imutavel: true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_tela(fake));
      await tester.pumpAndSettle();

      expect(find.text('Termo Vigente'), findsOneWidget);

      // Clica para ver detalhes
      await tester.tap(find.text('Ver Documento Completo'));
      await tester.pumpAndSettle();

      // BottomSheet aberta
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Versão 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('Texto integral longo e detalhado da versão 1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('exibe banner de erro quando a consulta falha', (tester) async {
      _definirTamanho(tester, const Size(1000, 800));
      final fake = TermosFake(falhar: true);

      await tester.pumpWidget(_tela(fake));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar os termos. Tente novamente.'), findsOneWidget);
    });
  });
}

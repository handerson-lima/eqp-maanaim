import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/ui/components/cpf_formatter.dart';

void main() {
  group('CpfFormatter - Testes Unitários de Formatação e Máscara', () {
    test('apenasDigitos extrai exclusivamente números ou retorna vazio', () {
      expect(CpfFormatter.apenasDigitos('123.456.789-01'), '12345678901');
      expect(CpfFormatter.apenasDigitos('abc.123-def'), '123');
      expect(CpfFormatter.apenasDigitos(''), '');
      expect(CpfFormatter.apenasDigitos(null), '');
    });

    test('formatar com 11 dígitos brutos gera formato 000.000.000-00', () {
      expect(CpfFormatter.formatar('12345678901'), '123.456.789-01');
      expect(CpfFormatter.formatar('52998224725'), '529.982.247-25');
    });

    test('formatar é idempotente se já estiver no formato correto', () {
      expect(CpfFormatter.formatar('123.456.789-01'), '123.456.789-01');
      expect(CpfFormatter.formatar('529.982.247-25'), '529.982.247-25');
    });

    test('formatar lida com strings parciais progressivamente', () {
      expect(CpfFormatter.formatar('12'), '12');
      expect(CpfFormatter.formatar('123'), '123');
      expect(CpfFormatter.formatar('1234'), '123.4');
      expect(CpfFormatter.formatar('123456'), '123.456');
      expect(CpfFormatter.formatar('1234567'), '123.456.7');
      expect(CpfFormatter.formatar('123456789'), '123.456.789');
      expect(CpfFormatter.formatar('1234567890'), '123.456.789-0');
    });

    test('formatar trunca excedente a 11 dígitos', () {
      expect(CpfFormatter.formatar('123456789019999'), '123.456.789-01');
    });

    test('formatar retorna vazio para nulo ou em branco', () {
      expect(CpfFormatter.formatar(null), '');
      expect(CpfFormatter.formatar(''), '');
      expect(CpfFormatter.formatar('   '), '');
    });

    test('formatar preserva strings já mascaradas com asteriscos', () {
      expect(CpfFormatter.formatar('***.456.789-**'), '***.456.789-**');
      expect(CpfFormatter.formatar('111.***.***-22'), '111.***.***-22');
      expect(CpfFormatter.formatar('***.***.***-**'), '***.***.***-**');
    });

    test('mascarar aplica máscara de privacidade nos dígitos brutos', () {
      expect(CpfFormatter.mascarar('12345678901'), '123.***.***-01');
      expect(CpfFormatter.mascarar('123.456.789-01'), '123.***.***-01');
      expect(
        CpfFormatter.mascarar('12345678901', formatoCentral: true),
        '***.456.789-**',
      );
    });

    test('validar confere dígitos verificadores oficiais', () {
      expect(CpfFormatter.validar('529.982.247-25'), isTrue);
      expect(CpfFormatter.validar('52998224725'), isTrue);
      expect(CpfFormatter.validar('111.111.111-11'), isFalse);
      expect(CpfFormatter.validar('123.456.789-00'), isFalse);
      expect(CpfFormatter.validar('12345'), isFalse);
      expect(CpfFormatter.validar(null), isFalse);
    });

    test('rotuloAcessivel gera leitura inteligível sem pontuação para leitor de tela', () {
      expect(
        CpfFormatter.rotuloAcessivel('529.982.247-25'),
        'CPF: 5 2 9, 9 8 2, 2 4 7, 2 5',
      );
      expect(
        CpfFormatter.rotuloAcessivel('52998224725'),
        'CPF: 5 2 9, 9 8 2, 2 4 7, 2 5',
      );
      expect(
        CpfFormatter.rotuloAcessivel('***.456.789-**'),
        'CPF mascarado: dígitos centrais 4 5 6, 7 8 9',
      );
      expect(
        CpfFormatter.rotuloAcessivel('111.***.***-22'),
        'CPF mascarado: 1 1 1, dígitos centrais ocultos, final 2 2',
      );
      expect(
        CpfFormatter.rotuloAcessivel('***.***.***-**'),
        'CPF mascarado por privacidade',
      );
      expect(
        CpfFormatter.rotuloAcessivel(null),
        'CPF não informado',
      );
      expect(
        CpfFormatter.rotuloAcessivel(''),
        'CPF não informado',
      );
    });
  });

  group('CpfInputFormatter - Testes Unitários de TextInputFormatter', () {
    final formatter = CpfInputFormatter();

    test('formata texto simples inserido de uma vez', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '12345678901',
        selection: TextSelection.collapsed(offset: 11),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '123.456.789-01');
      expect(result.selection.end, 14);
    });

    test('ignora caracteres não numéricos durante digitação', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '12a3b4',
        selection: TextSelection.collapsed(offset: 6),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '123.4');
    });

    test('trunca colagem com mais de 11 dígitos', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '12345678901999999',
        selection: TextSelection.collapsed(offset: 17),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '123.456.789-01');
      expect(result.selection.end, 14);
    });

    test('trata deleção suave (backspace)', () {
      const oldValue = TextEditingValue(
        text: '123.',
        selection: TextSelection.collapsed(offset: 4),
      );
      const newValue = TextEditingValue(
        text: '123',
        selection: TextSelection.collapsed(offset: 3),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '123');
      expect(result.selection.end, 3);
    });
  });

  group('CpfText - Testes de Widget e Acessibilidade Semântica', () {
    testWidgets('renderiza texto formatado com rotulo semantico WCAG 2.2 AA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CpfText(
              cpf: '52998224725',
              incluirRotuloVisual: true,
            ),
          ),
        ),
      );

      // Verificação visual
      expect(find.text('CPF: 529.982.247-25'), findsOneWidget);

      // Verificação de Semantics para Leitores de Tela
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'CPF: 5 2 9, 9 8 2, 2 4 7, 2 5',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('renderiza CPF mascarado com rotulo semantico descritivo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CpfText(
              cpf: '***.456.789-**',
              incluirRotuloVisual: false,
            ),
          ),
        ),
      );

      // Verificação visual
      expect(find.text('***.456.789-**'), findsOneWidget);

      // Verificação de Semantics
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'CPF mascarado: dígitos centrais 4 5 6, 7 8 9',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('renderiza com estilo monospaced por padrão', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CpfText(
              cpf: '12345678901',
              destaqueMonospaced: true,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.style?.fontFamily, 'monospace');
    });
  });
}

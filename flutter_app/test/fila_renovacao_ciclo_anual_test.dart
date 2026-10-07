import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/coordenador/coordenador_service.dart';
import 'package:eqp_maanaim/features/coordenador/fila_coordenador_screen.dart';
import 'package:eqp_maanaim/features/pastor/fila_pastor_screen.dart';
import 'package:eqp_maanaim/features/pastor/pastor_service.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/fila_responsavel_equipe_screen.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/responsavel_equipe_service.dart';
import 'package:eqp_maanaim/ui/theme.dart';

void main() {
  group('Story 5.3: Processar aprovação e conclusão do ciclo anual', () {
    group('Etapa 1: Fila do Pastor Local (Ciclo Anual)', () {
      final itemCicloPastor = ItemFilaPastor(
        id: 'pendencia-ciclo-01',
        fichaId: 'ficha-01',
        voluntarioUid: 'vol-01',
        voluntarioNome: 'Marcos Vinicius',
        igrejaId: 'igreja-01',
        nomeIgreja: 'Igreja Central',
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        proximaAcao: 'Aguardando avaliação do Pastor Local',
        ano: 2026,
        equipes: const [
          EquipeFilaPastor(equipeId: 'eq-01', nomeEquipe: 'Acolhimento'),
        ],
        enviadoEm: '2026-10-06T12:00:00Z',
        versao: 1,
        cicloId: 'ciclo-2026-01',
        isRenovacaoAnual: true,
      );

      final igreja = const IgrejaEscopoPastor(id: 'igreja-01', nome: 'Igreja Central');

      testWidgets('exibe badge "Ciclo Anual 2026" para pendência de renovação na fila do pastor', (tester) async {
        final gateway = MemoriaPastorLocalGateway(
          pendenciasIniciais: [itemCicloPastor],
          igrejasIniciais: [igreja],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaPastorScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Marcos Vinicius'), findsOneWidget);
        expect(find.text('Ciclo Anual 2026'), findsOneWidget);
        expect(find.byKey(const Key('btnAprovar_ficha-01')), findsOneWidget);
        expect(find.byKey(const Key('btnRecusar_ficha-01')), findsOneWidget);
      });

      testWidgets('aprovação de ciclo anual invoca gateway.decidirCicloAnual', (tester) async {
        final gateway = MemoriaPastorLocalGateway(
          pendenciasIniciais: [itemCicloPastor],
          igrejasIniciais: [igreja],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaPastorScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnAprovar_ficha-01')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnConfirmarAprovacaoModal')));
        await tester.pumpAndSettle();

        expect(find.text('Ficha de Marcos Vinicius aprovada com sucesso!'), findsOneWidget);
        expect(find.text('Marcos Vinicius'), findsNothing);
      });

      testWidgets('recusa de ciclo anual exige justificativa e remove da fila', (tester) async {
        final gateway = MemoriaPastorLocalGateway(
          pendenciasIniciais: [itemCicloPastor],
          igrejasIniciais: [igreja],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaPastorScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnRecusar_ficha-01')));
        await tester.pumpAndSettle();

        expect(find.text('Decisão Pastoral Desfavorável'), findsOneWidget);
        // Tenta confirmar sem justificativa
        await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
        await tester.pumpAndSettle();
        expect(find.text('Informe uma justificativa de ao menos 5 caracteres.'), findsOneWidget);

        // Preenche justificativa válida
        await tester.enterText(find.byKey(const Key('campoJustificativaRecusa')), 'Mudança de ministério');
        await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
        await tester.pumpAndSettle();

        expect(find.text('Decisão desfavorável registrada com sucesso.'), findsOneWidget);
        expect(find.text('Marcos Vinicius'), findsNothing);
      });
    });

    group('Etapa 2: Fila do Responsável de Equipe (Ciclo Anual)', () {
      final itemCicloResp = const ItemFilaResponsavelEquipe(
        participacaoId: 'part-01',
        fichaId: 'ficha-01',
        voluntarioUid: 'vol-01',
        voluntarioNome: 'Beatriz Santos',
        equipeId: 'eq-musica',
        nomeEquipe: 'Música',
        igrejaId: 'igreja-01',
        nomeIgreja: 'Igreja Central',
        estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
        versao: 1,
        enviadoEm: '2026-10-06T12:00:00Z',
        cicloId: 'ciclo-2026-02',
        isRenovacaoAnual: true,
        anoVigencia: 2026,
      );

      final equipe = const EquipeEscopoResponsavel(id: 'eq-musica', nome: 'Música');

      testWidgets('exibe badge "Ciclo Anual 2026" na pendência do responsável', (tester) async {
        final gateway = MemoriaResponsavelEquipeGateway(
          pendenciasIniciais: [itemCicloResp],
          equipesIniciais: [equipe],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaResponsavelEquipeScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Beatriz Santos'), findsOneWidget);
        expect(find.text('Ciclo Anual 2026'), findsOneWidget);
        expect(find.byKey(const Key('btnAprovar_part-01')), findsOneWidget);
        expect(find.byKey(const Key('btnRecusar_part-01')), findsOneWidget);
      });

      testWidgets('aprovação pelo responsável invoca gateway.decidirCicloAnual', (tester) async {
        final gateway = MemoriaResponsavelEquipeGateway(
          pendenciasIniciais: [itemCicloResp],
          equipesIniciais: [equipe],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaResponsavelEquipeScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnAprovar_part-01')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnConfirmarAprovacaoModal')));
        await tester.pumpAndSettle();

        expect(find.text('Participação na equipe Música aprovada com sucesso!'), findsOneWidget);
        expect(find.text('Beatriz Santos'), findsNothing);
      });

      testWidgets('recusa pelo responsável de equipe exige justificativa e remove da fila', (tester) async {
        final gateway = MemoriaResponsavelEquipeGateway(
          pendenciasIniciais: [itemCicloResp],
          equipesIniciais: [equipe],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaResponsavelEquipeScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnRecusar_part-01')));
        await tester.pumpAndSettle();

        expect(find.text('Decisão Negativa de Equipe'), findsOneWidget);
        expect(find.textContaining('Procure o Pastor da igreja local para mais informações'), findsOneWidget);

        // Tenta confirmar sem justificativa
        await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
        await tester.pumpAndSettle();
        expect(find.text('Informe uma justificativa de ao menos 5 caracteres.'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('campoJustificativaRecusa')), 'Indisponibilidade de ensaios');
        await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
        await tester.pumpAndSettle();

        expect(find.text('Participação recusada. Mensagem padrão enviada ao voluntário.'), findsOneWidget);
        expect(find.text('Beatriz Santos'), findsNothing);
      });
    });

    group('Etapa 3: Fila do Coordenador Geral (Ciclo Anual)', () {
      final partCiclo = const ParticipacaoItemCoordenador(
        participacaoId: 'part-01',
        equipeId: 'eq-portaria',
        nomeEquipe: 'Portaria',
        estado: 'AGUARDANDO_COORDENADOR',
        proximaAcao: 'Aguardando conclusão do Coordenador',
        responsavelNome: 'Pr. Tiago',
        responsavelDecididoEm: '2026-10-06T14:00:00Z',
        elegivelAtivacao: true,
        isRenovacaoAnual: true,
        cicloId: 'ciclo-2026-03',
        anoVigencia: 2026,
      );

      final itemCicloCoord = ItemFilaCoordenador(
        fichaId: 'ficha-01',
        voluntarioUid: 'vol-01',
        voluntarioNome: 'Gabriel Ferreira',
        profissao: 'Engenheiro',
        cpfMascarado: '222.***.***-33',
        igrejaId: 'igreja-01',
        nomeIgreja: 'Igreja Central',
        versaoFicha: 1,
        enviadoEm: '2026-10-06T10:00:00Z',
        pastorLocalNome: 'Pr. João',
        pastorLocalDecididoEm: '2026-10-06T12:00:00Z',
        participacoes: [partCiclo],
      );

      testWidgets('exibe badge "Ciclo Anual 2026" na fila do coordenador', (tester) async {
        final gateway = MemoriaCoordenadorGateway(
          pendenciasIniciais: [itemCicloCoord],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaCoordenadorScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Gabriel Ferreira'), findsOneWidget);
        expect(find.text('Ciclo Anual 2026'), findsOneWidget);
        expect(find.byKey(const Key('btnAprovar_ficha-01')), findsOneWidget);
      });

      testWidgets('homologação anual pelo coordenador exige checkbox de reunião de pastores', (tester) async {
        final gateway = MemoriaCoordenadorGateway(
          pendenciasIniciais: [itemCicloCoord],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaCoordenadorScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnAprovar_ficha-01')));
        await tester.pumpAndSettle();

        expect(find.text('Homologar e Ativar Voluntariado'), findsOneWidget);

        // O botão 'Confirmar Ativação' deve estar desabilitado antes do checkbox
        final btnConfirmar = tester.widget<ElevatedButton>(find.byKey(const Key('btnConfirmarAtivacaoModal')));
        expect(btnConfirmar.onPressed, isNull);

        // Marca a confirmação da reunião de pastores
        await tester.tap(find.byKey(const Key('chkConfirmarReuniao')));
        await tester.pumpAndSettle();

        // Agora pode confirmar
        await tester.tap(find.byKey(const Key('btnConfirmarAtivacaoModal')));
        await tester.pumpAndSettle();

        expect(find.text('Renovação anual concluída com sucesso!'), findsOneWidget);
        expect(find.text('Gabriel Ferreira'), findsNothing);
      });

      testWidgets('decisão desfavorável do coordenador na renovação anual avisa sobre encerramento ao fim da vigência', (tester) async {
        final gateway = MemoriaCoordenadorGateway(
          pendenciasIniciais: [itemCicloCoord],
        );

        await tester.pumpWidget(MaterialApp(
          theme: temaMaanaim(),
          home: FilaCoordenadorScreen(gateway: gateway),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnRecusar_ficha-01')));
        await tester.pumpAndSettle();

        expect(find.text('Decisão Desfavorável'), findsOneWidget);
        expect(find.textContaining('A justificativa interna será gravada como evidência restrita da decisão'), findsOneWidget);
        expect(find.textContaining('Procure o Pastor da igreja local para mais informações'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('campoJustificativaRecusa')), 'Decisão da coordenação de polo');
        await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
        await tester.pumpAndSettle();

        expect(find.text('Decisão desfavorável da renovação anual registrada.'), findsOneWidget);
        expect(find.text('Gabriel Ferreira'), findsNothing);
      });
    });
  });
}

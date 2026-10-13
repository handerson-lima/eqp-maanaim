// HARNESS TEMPORÁRIO DO WP-06 — NÃO FAZ PARTE DA STORY. Apagar após capturas.
// Monta as telas reais com gateways em memória (Memoria*), sem Firebase.
// Seleção por query string: ?p=<perfil>&c=<cenario>
import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/analise/detalhe_solicitacao_model.dart';
import 'package:eqp_maanaim/features/analise/detalhe_solicitacao_service.dart';
import 'package:eqp_maanaim/features/coordenador/coordenador_service.dart';
import 'package:eqp_maanaim/features/coordenador/fila_coordenador_screen.dart';
import 'package:eqp_maanaim/features/pastor/fila_pastor_screen.dart';
import 'package:eqp_maanaim/features/pastor/pastor_service.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/fila_responsavel_equipe_screen.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/responsavel_equipe_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/inicio_voluntario_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/ui/theme.dart';
import 'package:eqp_maanaim/ui/components/metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class _FichaGw implements FichaGateway {
  _FichaGw(this.r);
  final ObterFichaResposta r;
  @override
  Future<ObterFichaResposta> obterMinhaFicha() async => r;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _PartGw implements ParticipacaoGateway {
  _PartGw(this.p);
  final List<ParticipacaoModel> p;
  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async => p;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _CatGw implements CatalogoGateway {
  @override
  Future<CatalogoResposta> consultar({
    String? termo,
    bool somenteAdmin = false,
  }) async => const CatalogoResposta(
    igrejas: [
      IgrejaCatalogo(
        id: 'ig-validacao-01',
        nome: 'Igreja de Validação',
        codigo: '240001',
        ativo: true,
        pastorLocalNome: 'Responsável de Validação',
      ),
    ],
    equipes: [],
  );
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _DetGw implements DetalheSolicitacaoGateway {
  @override
  Future<DetalheSolicitacaoDados> obterDetalhe({
    required String fichaId,
    String? cicloId,
  }) async {
    return DetalheSolicitacaoDados(
      fichaId: fichaId,
      voluntarioUid: 'user-456',
      voluntarioNome: 'Carlos Eduardo Silva',
      cpfMascarado: '111.***.***-22',
      profissao: 'Engenheiro Civil',
      igrejaId: 'igreja-01',
      nomeIgreja: 'Igreja Central',
      estadoFicha: 'AGUARDANDO_PASTOR_LOCAL',
      versao: 2,
      enviadoEm: '2026-10-09T10:00:00Z',
      participacoes: const [
        ItemParticipacaoDetalhe(
          id: 'part-1',
          equipeId: 'eq-louvor',
          nomeEquipe: 'Louvor e Adoração',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          ciclo: 'INICIAL',
        ),
        ItemParticipacaoDetalhe(
          id: 'part-2',
          equipeId: 'eq-acolh',
          nomeEquipe: 'Acolhimento',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          ciclo: 'INICIAL',
        ),
      ],
      documentos: const [
        DocumentoEvidenciaModel(
          tipo: 'TERMO_ADESAO',
          titulo: 'Termo de Adesão ao Voluntariado',
          descricao: 'Aceite registrado',
          disponivel: true,
        ),
      ],
    );
  }

  @override
  Future<void> decidirPastor(
    EntradaDecisaoPastor e, {
    bool isRenovacao = false,
  }) async {}
  @override
  Future<void> decidirResponsavel(
    EntradaDecidirParticipacaoResponsavel e, {
    bool isRenovacao = false,
  }) async {}
  @override
  Future<void> decidirCoordenador({
    required EntradaDecisaoCoordenadorContextual entrada,
    bool isRenovacao = false,
  }) async {}
}

ItemFilaPastor _p(String n, int i, {bool renov = false}) => ItemFilaPastor(
  id: 'pendencia-0$i',
  fichaId: 'ficha-0$i',
  voluntarioUid: 'vol-0$i',
  voluntarioNome: n,
  igrejaId: 'igreja-01',
  nomeIgreja: 'Igreja Central',
  estado: 'AGUARDANDO_PASTOR_LOCAL',
  proximaAcao: 'Aguardando avaliação do Pastor Local',
  ano: 2026,
  equipes: const [
    EquipeFilaPastor(equipeId: 'eq-01', nomeEquipe: 'Louvor e Adoração'),
    EquipeFilaPastor(equipeId: 'eq-02', nomeEquipe: 'Acolhimento'),
  ],
  enviadoEm: '2026-10-06T12:00:00Z',
  isRenovacaoAnual: renov,
);

ItemFilaResponsavelEquipe _r(String n, int i) => ItemFilaResponsavelEquipe(
  participacaoId: 'part-0$i',
  fichaId: 'ficha-0$i',
  voluntarioUid: 'vol-0$i',
  voluntarioNome: n,
  igrejaId: 'igreja-01',
  nomeIgreja: 'Igreja Central',
  equipeId: 'eq-cozinha',
  nomeEquipe: 'Cozinha',
  estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
  proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
  versao: 1,
  enviadoEm: '2026-10-06T14:00:00Z',
);

ItemFilaCoordenador _c(String n, int i) => ItemFilaCoordenador(
  fichaId: 'ficha-0$i',
  voluntarioUid: 'vol-0$i',
  voluntarioNome: n,
  profissao: 'Não informado',
  cpfMascarado: '***.***.***-**',
  igrejaId: 'igreja-central',
  nomeIgreja: 'Igreja de Validação',
  versaoFicha: 1,
  enviadoEm: '2026-10-06T09:00:00Z',
  pastorLocalNome: 'Responsável de Validação',
  pastorLocalDecididoEm: '2026-10-06T10:00:00Z',
  participacoes: const [
    ParticipacaoItemCoordenador(
      participacaoId: 'part-01',
      equipeId: 'eq-cozinha',
      nomeEquipe: 'Cozinha',
      estado: 'AGUARDANDO_COORDENADOR',
      proximaAcao: 'Aguardando conclusão do Coordenador',
      responsavelNome: 'Responsável de Validação',
      responsavelDecididoEm: '2026-10-06T12:00:00Z',
      elegivelAtivacao: true,
    ),
  ],
);

void main() {
  final q = Uri.base.queryParameters;
  final p = q['p'] ?? 'pastor';
  final c = q['c'] ?? 'cheia';
  final w = double.tryParse(q['w'] ?? '');
  final h = double.tryParse(q['h'] ?? '');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaMaanaim(),
      builder: (ctx, child) {
        if (w == null || h == null) return child!;
        return ColoredBox(
          color: const Color(0xFF444444),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: w,
              height: h,
              child: MediaQuery(
                data: MediaQuery.of(ctx).copyWith(size: Size(w, h)),
                child: child!,
              ),
            ),
          ),
        );
      },
      home: _tela(p, c),
    ),
  );
  final auto = q['auto'];
  if (auto != null && auto.isNotEmpty) {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      for (final step in auto.split(',')) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        _executar(step);
      }
    });
  }
}

void _executar(String step) {
  final kind = step.substring(0, 2);
  final arg = step.substring(2);
  final root = WidgetsBinding.instance.rootElement!;
  bool feito = false;
  void rolar(Element e) {
    if (feito) return;
    final wdg = e.widget;
    if (kind == 'k:' &&
        wdg.key is ValueKey &&
        (wdg.key as ValueKey).value == arg) {
      if (wdg is ElevatedButton) {
        wdg.onPressed?.call();
        feito = true;
        return;
      }
      if (wdg is OutlinedButton) {
        wdg.onPressed?.call();
        feito = true;
        return;
      }
      if (wdg is TextButton) {
        wdg.onPressed?.call();
        feito = true;
        return;
      }
      if (wdg is Checkbox) {
        wdg.onChanged?.call(true);
        feito = true;
        return;
      }
    }
    if (kind == 't:' && wdg is MetricCard && wdg.title == arg) {
      wdg.onTap?.call();
      feito = true;
      return;
    }
    if (kind == 'x:' && wdg is Text && wdg.data == arg) {
      e.visitAncestorElements((a) {
        final aw = a.widget;
        if (aw is InkWell && aw.onTap != null) {
          aw.onTap!();
          feito = true;
          return false;
        }
        if (aw is ListTile && aw.onTap != null) {
          aw.onTap!();
          feito = true;
          return false;
        }
        if (aw is GestureDetector && aw.onTap != null) {
          aw.onTap!();
          feito = true;
          return false;
        }
        return true;
      });
      return;
    }
    e.visitChildren(rolar);
  }

  // O Overlay (dialogs) fica sob o root; percorrer tudo.
  root.visitChildren(rolar);
  // ignore: avoid_print
  print('WP06 passo $step => ${feito ? 'ok' : 'NAO ENCONTRADO'}');
}

Widget _tela(String p, String c) {
  final vazia = c.startsWith('vazia');
  final erro = c == 'erro' ? Exception('falha') : null;
  final pastorGw = MemoriaPastorLocalGateway(
    pendenciasIniciais: vazia
        ? []
        : c == 'filtro'
        ? [_p('Carlos Eduardo Silva', 1)]
        : [_p('Carlos Eduardo Silva', 1), _p('Renato Santos', 2, renov: true)],
    igrejasIniciais: const [
      IgrejaEscopoPastor(id: 'igreja-01', nome: 'Igreja Central'),
      IgrejaEscopoPastor(id: 'igreja-02', nome: 'Igreja Norte'),
    ],
    erroAoObterFila: erro,
  );
  final respGw = MemoriaResponsavelEquipeGateway(
    pendenciasIniciais: vazia
        ? []
        : [_r('Gabriel Santos', 1), _r('Larissa Souza', 2)],
    equipesIniciais: const [
      EquipeEscopoResponsavel(id: 'eq-cozinha', nome: 'Cozinha'),
    ],
    erroAoObterFila: erro,
  );
  final coordGw = MemoriaCoordenadorGateway(
    pendenciasIniciais: vazia
        ? []
        : [
            _c('Registro de Validação 01', 1),
            _c('Registro de Validação 02', 2),
          ],
    erroAoObterFila: erro,
  );
  final det = _DetGw();
  switch (p) {
    case 'pastor':
      return FilaPastorScreen(
        gateway: pastorGw,
        detalheGateway: det,
        userName: 'Moisés',
      );
    case 'responsavel':
      return FilaResponsavelEquipeScreen(gateway: respGw, detalheGateway: det);
    case 'coordenador':
      return FilaCoordenadorScreen(gateway: coordGw, detalheGateway: det);
    case 'admin':
      return AdminShell(
        onSair: () {},
        catalogo: _CatGw(),
        pastor: pastorGw,
        responsavelEquipe: respGw,
        coordenador: coordGw,
      );
    case 'voluntario':
      final ficha = c == 'rascunho'
          ? const FichaModel(
              id: 'uid-1',
              nomeCompleto: 'Gabriel Silva',
              profissao: 'Engenheiro',
              cpf: '12345678901',
              igrejaId: 'ig-1',
              estado: 'RASCUNHO',
              versao: 1,
            )
          : const FichaModel(
              id: 'uid-2',
              nomeCompleto: 'Perfil de Validação',
              profissao: 'Não informado',
              cpf: '',
              igrejaId: 'ig-1',
              estado: 'ATIVA',
              versao: 2,
              termoAceito: TermoAceitoModel(
                termoId: 't-1',
                versaoId: 'v-1',
                numeroVersao: 1,
                hashSha256: 'h',
                aceitoEm: '2026-01-15T10:00:00Z',
                commandId: 'c',
              ),
            );
      final parts = c == 'rascunho'
          ? <ParticipacaoModel>[]
          : const [
              ParticipacaoModel(
                id: 'part-1',
                fichaId: 'uid-2',
                equipeId: 'eq-louvor',
                nomeEquipe: 'Grupo de Louvor',
                estado: 'ATIVA',
                ciclo: '2026',
                proximaAcao: 'Atuar nas escalas',
                vigenciaInicio: '2026-01-15T00:00:00Z',
                vigenciaFim: '2027-01-15T00:00:00Z',
                situacaoVigencia: 'VIGENTE',
                diasParaVencimento: 98,
              ),
              ParticipacaoModel(
                id: 'part-2',
                fichaId: 'uid-2',
                equipeId: 'eq-midia',
                nomeEquipe: 'Equipe de Mídia',
                estado: 'ATIVA',
                ciclo: '2026',
                proximaAcao: 'Renovação aberta',
                vigenciaInicio: '2026-01-01T00:00:00Z',
                vigenciaFim: '2026-11-01T00:00:00Z',
                situacaoVigencia: 'ALERTA_PREVIO_60D',
                diasParaVencimento: 23,
                emAlertaRenovacao: true,
              ),
            ];
      return Scaffold(
        body: InicioVoluntarioScreen(
          fichaGateway: _FichaGw(
            ObterFichaResposta(existe: true, ficha: ficha),
          ),
          participacaoGateway: _PartGw(parts),
          catalogoGateway: _CatGw(),
          userName: ficha.nomeCompleto,
        ),
      );
  }
  return const Scaffold(body: Center(child: Text('perfil desconhecido')));
}

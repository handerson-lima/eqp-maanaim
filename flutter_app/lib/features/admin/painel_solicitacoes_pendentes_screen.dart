import 'package:flutter/material.dart';

import '../../ui/identidade.dart';
import 'solicitacoes_pendentes_service.dart';

/// Tela do Painel Geral de Solicitações Pendentes por Equipes.
/// Permite ao Administrador Geral visualizar todas as pendências da organização,
/// agrupadas por equipe, com busca universal instantânea por qualquer dado.
class PainelSolicitacoesPendentesScreen extends StatefulWidget {
  const PainelSolicitacoesPendentesScreen({
    super.key,
    required this.gateway,
  });

  final SolicitacoesPendentesGateway gateway;

  @override
  State<PainelSolicitacoesPendentesScreen> createState() =>
      _PainelSolicitacoesPendentesScreenState();
}

class _PainelSolicitacoesPendentesScreenState
    extends State<PainelSolicitacoesPendentesScreen> {
  final TextEditingController _buscaController = TextEditingController();
  final FocusNode _buscaFocusNode = FocusNode();

  bool _carregando = true;
  String? _erro;
  ResultadoSolicitacoesPendentesModel? _resultado;

  String _termoBusca = '';
  final Set<String> _equipesExpandidas = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _buscaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final res = await widget.gateway.consultarSolicitacoesPendentesGlobal();
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _carregando = false;
        _equipesExpandidas.clear();
        for (final item in res.solicitacoes) {
          _equipesExpandidas.add(item.equipeNome);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as solicitações pendentes. ($e)';
      });
    }
  }

  String _normalizar(String texto) {
    var s = texto.toLowerCase();
    const comAcento = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
    const semAcento = 'aaaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < comAcento.length; i++) {
      s = s.replaceAll(comAcento[i], semAcento[i]);
    }
    return s.trim();
  }

  List<SolicitacaoPendenteItemModel> get _solicitacoesFiltradas {
    final todos = _resultado?.solicitacoes ?? [];
    if (_termoBusca.isEmpty) return todos;

    final termoNorm = _normalizar(_termoBusca);
    final termoDigitos = _termoBusca.replaceAll(RegExp(r'\D'), '');

    return todos.where((s) {
      if (termoDigitos.isNotEmpty && s.cpfDigitos.contains(termoDigitos)) {
        return true;
      }
      final campos = [
        s.nomeVoluntario,
        s.profissao,
        s.cpfMascarado,
        s.igrejaNome,
        s.igrejaCodigo,
        s.equipeNome,
        s.rotuloEstado,
        s.proximaAcao,
      ];
      return campos.any((c) => _normalizar(c).contains(termoNorm));
    }).toList();
  }

  Map<String, List<SolicitacaoPendenteItemModel>> get _agrupadoPorEquipe {
    final filtradas = _solicitacoesFiltradas;
    final map = <String, List<SolicitacaoPendenteItemModel>>{};
    for (final item in filtradas) {
      final key = item.equipeNome.isNotEmpty ? item.equipeNome : 'Sem Equipe';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Color _corEstado(String estado) {
    switch (estado) {
      case 'AGUARDANDO_PASTOR_LOCAL':
        return const Color(0xFFB45309);
      case 'AGUARDANDO_RESPONSAVEL_EQUIPE':
        return AppColors.blue600;
      case 'AGUARDANDO_COORDENADOR':
        return const Color(0xFF6D28D9);
      default:
        return AppColors.textSecondary;
    }
  }

  Color _fundoEstado(String estado) {
    switch (estado) {
      case 'AGUARDANDO_PASTOR_LOCAL':
        return AppColors.warningBg;
      case 'AGUARDANDO_RESPONSAVEL_EQUIPE':
        return AppColors.blue50;
      case 'AGUARDANDO_COORDENADOR':
        return const Color(0xFFF3E8FF);
      default:
        return AppColors.neutral100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final agrupado = _agrupadoPorEquipe;
    final totalFiltradas = _solicitacoesFiltradas.length;
    final totalGeral = _resultado?.totalGeral ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarDados,
          color: AppColors.blue600,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(totalGeral),
                    const SizedBox(height: AppSpacing.s16),
                    if (_carregando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_erro != null)
                      _buildErro()
                    else ...[
                      _buildPainelMetricas(totalGeral, agrupado.length, totalFiltradas),
                      const SizedBox(height: AppSpacing.s16),
                      _buildBarraPesquisa(),
                      const SizedBox(height: AppSpacing.s16),
                      if (agrupado.isEmpty)
                        _buildEstadoVazio()
                      else
                        _buildListaEquipes(agrupado),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalGeral) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final infoRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Atualizar solicitações pendentes',
              child: OutlinedButton.icon(
                onPressed: _carregando ? null : _carregarDados,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: AppColors.blue600,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Atualizar'),
              ),
            ),
          ],
        );

        final textCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.blue600.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.pending_actions_outlined,
                    color: AppColors.blue600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                const Expanded(
                  child: Text(
                    'Central de Solicitações',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Visão geral das solicitações pendentes agrupadas por equipes operacionais.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textCol,
              const SizedBox(height: AppSpacing.s8),
              Align(alignment: Alignment.centerLeft, child: infoRow),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: textCol),
            const SizedBox(width: AppSpacing.s16),
            infoRow,
          ],
        );
      },
    );
  }

  Widget _buildPainelMetricas(int totalGeral, int totalEquipes, int totalFiltradas) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final cardTotal = _buildCardMetrica(
          titulo: 'Total Pendente',
          valor: '$totalGeral',
          icone: Icons.assignment_late_outlined,
          corIcone: AppColors.blue600,
        );

        final cardEquipes = _buildCardMetrica(
          titulo: 'Equipes c/ Pendências',
          valor: '$totalEquipes',
          icone: Icons.groups_outlined,
          corIcone: const Color(0xFF6D28D9),
        );

        final cardFiltradas = _buildCardMetrica(
          titulo: 'Itens Filtrados',
          valor: '$totalFiltradas',
          icone: Icons.filter_list_outlined,
          corIcone: const Color(0xFFB45309),
        );

        if (isMobile) {
          return Column(
            children: [
              cardTotal,
              const SizedBox(height: AppSpacing.s8),
              cardEquipes,
              const SizedBox(height: AppSpacing.s8),
              cardFiltradas,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cardTotal),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardEquipes),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardFiltradas),
          ],
        );
      },
    );
  }

  Widget _buildCardMetrica({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color corIcone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: corIcone.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icone, color: corIcone, size: 22),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraPesquisa() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscaController,
            focusNode: _buscaFocusNode,
            style: const TextStyle(fontSize: 15, color: AppColors.navy900),
            onChanged: (val) {
              setState(() {
                _termoBusca = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Pesquise por voluntário, CPF, profissão, igreja ou equipe...',
              hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
              suffixIcon: _termoBusca.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _buscaController.clear();
                        setState(() {
                          _termoBusca = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: AppColors.background,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                borderSide: const BorderSide(color: AppColors.blue600, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _termoBusca.isEmpty
                      ? 'Exibindo todas as solicitações pendentes'
                      : 'Filtrado por "$_termoBusca"',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final todos = _agrupadoPorEquipe.keys;
                        _equipesExpandidas.addAll(todos);
                      });
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.unfold_more, size: 16),
                    label: const Text('Expandir Todas', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _equipesExpandidas.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.unfold_less, size: 16),
                    label: const Text('Recolher Todas', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaEquipes(Map<String, List<SolicitacaoPendenteItemModel>> agrupado) {
    final nomesEquipes = agrupado.keys.toList()..sort();

    return Column(
      children: nomesEquipes.map((equipeNome) {
        final lista = agrupado[equipeNome] ?? [];
        final expandido = _equipesExpandidas.contains(equipeNome);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              side: BorderSide(
                color: expandido
                    ? AppColors.blue600.withValues(alpha: 0.3)
                    : AppColors.border,
                width: expandido ? 1.5 : 1.0,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
              key: PageStorageKey<String>('equipe_$equipeNome'),
              initiallyExpanded: expandido,
              onExpansionChanged: (estaAberto) {
                setState(() {
                  if (estaAberto) {
                    _equipesExpandidas.add(equipeNome);
                  } else {
                    _equipesExpandidas.remove(equipeNome);
                  }
                });
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.navy900.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.diversity_3_outlined,
                      size: 18,
                      color: AppColors.navy900,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      equipeNome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blue600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${lista.length} ${lista.length == 1 ? 'pendência' : 'pendências'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: lista.map((item) => _buildCardVoluntario(item)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
    );
  }

  Widget _buildCardVoluntario(SolicitacaoPendenteItemModel item) {
    final corSt = _corEstado(item.estado);
    final fundoSt = _fundoEstado(item.estado);

    String dataFormatada = 'Data não informada';
    if (item.enviadoEm != null) {
      final d = item.enviadoEm!;
      final dia = d.day.toString().padLeft(2, '0');
      final mes = d.month.toString().padLeft(2, '0');
      final ano = d.year;
      final hora = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      dataFormatada = '$dia/$mes/$ano às $hora:$min';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.navy900.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  item.nomeVoluntario.isNotEmpty
                      ? item.nomeVoluntario[0].toUpperCase()
                      : 'V',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nomeVoluntario,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'CPF: ${item.cpfMascarado}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fundoSt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: corSt.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item.rotuloEstado,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: corSt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (item.profissao.isNotEmpty)
                _buildInfoPill(
                  icone: Icons.work_outline,
                  label: item.profissao,
                ),
              _buildInfoPill(
                icone: Icons.church_outlined,
                label: item.igrejaCodigo.isNotEmpty
                    ? '${item.igrejaNome} (${item.igrejaCodigo})'
                    : item.igrejaNome,
              ),
              _buildInfoPill(
                icone: Icons.schedule_outlined,
                label: 'Enviado em $dataFormatada',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.blue600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Próxima Ação: ${item.proximaAcao}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blue600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({required IconData icone, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoVazio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.neutral100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_circle_outline,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            _termoBusca.isEmpty
                ? 'Nenhuma solicitação pendente encontrada'
                : 'Nenhum resultado para "$_termoBusca"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _termoBusca.isEmpty
                ? 'Todas as solicitações de voluntariado foram processadas.'
                : 'Tente alterar os termos da pesquisa por nome, CPF ou equipe.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 28),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              _erro ?? 'Erro inesperado ao consultar solicitações pendentes.',
              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }
}

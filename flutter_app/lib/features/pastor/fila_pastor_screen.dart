import 'package:flutter/material.dart';
import '../../comando.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/metrics.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../analise/detalhe_solicitacao_model.dart';
import '../analise/detalhe_solicitacao_screen.dart';
import '../analise/detalhe_solicitacao_service.dart';
import '../renovacao/dashboard_renovacao_service.dart';
import 'pastor_service.dart';

class FilaPastorScreen extends StatefulWidget {
  const FilaPastorScreen({
    super.key,
    required this.gateway,
    this.detalheGateway,
    this.dashboardRenovacaoGateway,
    this.onSair,
    this.userName,
    this.dentroDeShell = false,
  });

  final PastorLocalGateway gateway;
  final DetalheSolicitacaoGateway? detalheGateway;
  final DashboardRenovacaoGateway? dashboardRenovacaoGateway;
  final VoidCallback? onSair;
  final String? userName;
  final bool dentroDeShell;

  @override
  State<FilaPastorScreen> createState() => _FilaPastorScreenState();
}

class _FilaPastorScreenState extends State<FilaPastorScreen> {
  bool _carregando = true;
  String? _erro;
  List<ItemFilaPastor> _pendencias = [];
  List<IgrejaEscopoPastor> _igrejas = [];
  String? _igrejaFiltroId;
  String? _processandoFichaId;
  String? _filtroKpi; // null = todas; 'RENOVACOES' = apenas renovações
  int? _metricasAtivos;
  int? _metricasProximosVencimento;

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  Future<void> _carregarFila() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final resultado = await widget.gateway.obterFila();

      // Carregar métricas complementares se gateway estiver disponível
      if (widget.dashboardRenovacaoGateway != null) {
        try {
          final resDashboard = await widget.dashboardRenovacaoGateway!.obterDashboardRenovacao(
            papelDesejado: PapelDashboard.pastorLocal,
            igrejaId: _igrejaFiltroId,
          );
          if (resDashboard.metricasPastor != null) {
            _metricasAtivos = resDashboard.metricasPastor!.totalSobEscopo;
            _metricasProximosVencimento = resDashboard.metricasPastor!.proximasVencimento;
          }
        } catch (_) {
          // Mantém null para fallback gracioso sem quebrar a tela
        }
      }

      if (!mounted) return;
      setState(() {
        _pendencias = List.of(resultado.pendencias);
        _igrejas = List.of(resultado.igrejas);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar a fila pastoral. Tente novamente.';
        _carregando = false;
      });
    }
  }

  List<ItemFilaPastor> get _pendenciasNoEscopoIgreja {
    if (_igrejaFiltroId == null || _igrejaFiltroId!.isEmpty) {
      // Agrega ESTRITAMENTE as igrejas com vínculos vigentes do usuário retornadas pelo gateway
      final idsAutorizados = _igrejas.map((i) => i.id).toSet();
      return _pendencias.where((p) => idsAutorizados.contains(p.igrejaId) || idsAutorizados.isEmpty).toList();
    }
    return _pendencias.where((p) => p.igrejaId == _igrejaFiltroId).toList();
  }

  List<ItemFilaPastor> get _pendenciasFiltradas {
    final base = _pendenciasNoEscopoIgreja;
    if (_filtroKpi == 'RENOVACOES') {
      return base.where((p) => p.isRenovacaoAnual).toList();
    }
    return base;
  }

  int get _countPendencias => _pendenciasNoEscopoIgreja.length;
  int get _countRenovacoes => _pendenciasNoEscopoIgreja.where((p) => p.isRenovacaoAnual).length;

  String _formatarData(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final data = DateTime.parse(iso).toLocal();
      final dd = data.day.toString().padLeft(2, '0');
      final mm = data.month.toString().padLeft(2, '0');
      return '$dd/$mm/${data.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _abrirModalAprovacao(ItemFilaPastor item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Aprovação da Ficha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja aprovar a solicitação de voluntariado de ${item.voluntarioNome}?',
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.s12),
            if (item.nomeIgreja != null && item.nomeIgreja!.isNotEmpty)
              Text('Igreja: ${item.nomeIgreja}', style: AppTypography.body),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Equipes solicitadas: ${item.equipes.map((e) => e.nomeEquipe).join(', ')}',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: AppGeometry.cardBorderRadius,
              ),
              child: Text(
                'Ao aprovar, a ficha avançará para a avaliação paralela dos Responsáveis de Equipe.',
                style: AppTypography.caption.copyWith(color: AppColors.blue600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('btnConfirmarAprovacaoModal'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, AppGeometry.minTouchTarget),
            ),
            child: const Text('Confirmar Aprovação'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _executarDecisao(
        item: item,
        decisao: 'APROVADO',
        justificativa: null,
      );
    }
  }

  Future<void> _abrirModalRecusa(ItemFilaPastor item) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decisão Pastoral Desfavorável'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voluntário: ${item.voluntarioNome}',
                  style: AppTypography.h2,
                ),
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: AppGeometry.cardBorderRadius,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          'Atenção: A justificativa registrada permanecerá estritamente interna. '
                          'Para o voluntário, a mensagem exibida será exclusivamente: '
                          '"Procure o Pastor da igreja local para mais informações".',
                          style: AppTypography.caption.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                TextFormField(
                  key: const Key('campoJustificativaRecusa'),
                  controller: controller,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Justificativa Pastoral Interna *',
                    hintText: 'Informe o motivo da decisão desfavorável (mínimo 5 caracteres)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().length < 5) {
                      return 'Informe uma justificativa de ao menos 5 caracteres.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('btnConfirmarRecusaModal'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, AppGeometry.minTouchTarget),
            ),
            child: const Text('Confirmar Recusa'),
          ),
        ],
      ),
    );

    if (resultado != null && resultado.isNotEmpty) {
      await _executarDecisao(
        item: item,
        decisao: 'DESFAVORAVEL',
        justificativa: resultado,
      );
    }
  }

  Future<void> _executarDecisao({
    required ItemFilaPastor item,
    required String decisao,
    String? justificativa,
  }) async {
    setState(() => _processandoFichaId = item.fichaId);

    try {
      final commandId = comandoOpaco();
      final entrada = EntradaDecisaoPastor(
        commandId: commandId,
        fichaId: item.fichaId,
        cicloId: item.cicloId,
        decisao: decisao,
        justificativa: justificativa,
        expectedVersion: item.versao,
      );

      if (item.isRenovacaoAnual) {
        await widget.gateway.decidirCicloAnual(entrada);
      } else {
        await widget.gateway.decidirFicha(entrada);
      }

      if (!mounted) return;

      setState(() {
        _pendencias.removeWhere((p) => p.fichaId == item.fichaId);
        _processandoFichaId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decisao == 'APROVADO'
                ? 'Ficha de ${item.voluntarioNome} aprovada com sucesso!'
                : 'Decisão desfavorável registrada com sucesso.',
          ),
          backgroundColor:
              decisao == 'APROVADO' ? AppColors.success : AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processandoFichaId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar decisão: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _abrirDetalheSolicitacao(ItemFilaPastor item) async {
    final resultado = await Navigator.of(context).push<ResultadoDecisaoContextual>(
      MaterialPageRoute(
        builder: (_) => DetalheSolicitacaoScreen(
          fichaId: item.fichaId,
          nomeVoluntarioInicial: item.voluntarioNome,
          papel: PapelContextualAnalise.pastorLocal,
          isRenovacaoAnual: item.isRenovacaoAnual,
          cicloId: item.cicloId,
          versaoInicial: item.versao,
          gateway: widget.detalheGateway ??
              CompostoDetalheSolicitacaoGateway(pastorGateway: widget.gateway),
          onDecisaoConcluida: (res) {
            if (mounted) {
              setState(() {
                _pendencias.removeWhere((p) => p.fichaId == res.fichaId);
              });
            }
          },
        ),
      ),
    );

    if (resultado != null && mounted) {
      setState(() {
        _pendencias.removeWhere((p) => p.fichaId == resultado.fichaId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final corpo = SafeArea(
      child: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? _buildErro()
              : _buildConteudo(),
    );

    if (widget.dentroDeShell) {
      return Container(
        color: AppColors.background,
        child: corpo,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fila do Pastor Local'),
        backgroundColor: AppColors.surface,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Atualizar Fila',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregarFila,
          ),
          if (widget.onSair != null)
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: widget.onSair,
            ),
        ],
      ),
      body: corpo,
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.s16),
            Text(
              _erro!,
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            PrimaryButton(
              label: 'Tentar novamente',
              onPressed: _carregarFila,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.s32 : AppSpacing.pagePaddingMobile,
            vertical: AppSpacing.s8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCabecalho(isDesktop),
                  const SizedBox(height: AppSpacing.s8),
                  _buildKpis(constraints.maxWidth),
                  const SizedBox(height: AppSpacing.s8),
                  if (_filtroKpi != null) ...[
                    _buildBannerFiltroAtivo(),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                  if (_pendenciasFiltradas.isEmpty)
                    _buildListaVazia()
                  else if (isDesktop)
                    _buildTabelaDesktop()
                  else
                    ..._pendenciasFiltradas.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: _buildCardPendencia(item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCabecalho(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitações de Voluntariado',
                style: AppTypography.h2,
              ),
              const SizedBox(height: 2),
              Text(
                'Avalie as fichas pendentes das igrejas sob sua responsabilidade.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (_igrejas.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.s12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
            child: DropdownButtonFormField<String?>(
              key: const Key('dropdownFiltroIgreja'),
              initialValue: _igrejaFiltroId,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                labelText: 'Igreja',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas as igrejas'),
                ),
                ..._igrejas.map(
                  (igreja) => DropdownMenuItem<String?>(
                    value: igreja.id,
                    child: Text(
                      igreja.nome,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (novo) {
                setState(() => _igrejaFiltroId = novo);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKpis(double maxWidth) {
    final kpiPendencias = MetricCard(
      title: 'Pendências',
      value: '$_countPendencias',
      icon: Icons.inbox_outlined,
      variant: MetricVariant.primary,
      badge: _filtroKpi == null && _countPendencias > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Fila', style: TextStyle(color: Colors.white, fontSize: 11)),
            )
          : null,
      onTap: () {
        setState(() => _filtroKpi = null);
      },
    );

    final kpiRenovacoes = MetricCard(
      title: 'Renovações',
      value: '$_countRenovacoes',
      icon: Icons.autorenew_rounded,
      variant: MetricVariant.warning,
      badge: _filtroKpi == 'RENOVACOES'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Ativo', style: TextStyle(color: Colors.white, fontSize: 11)),
            )
          : null,
      onTap: () {
        setState(() {
          _filtroKpi = _filtroKpi == 'RENOVACOES' ? null : 'RENOVACOES';
        });
      },
    );

    final kpiAtivos = MetricCard(
      title: 'Ativos',
      value: _metricasAtivos != null ? '$_metricasAtivos' : '--',
      icon: Icons.check_circle_outline,
      variant: MetricVariant.success,
      subtitle: 'Voluntários vigentes',
    );

    final kpiProximosVencimento = MetricCard(
      title: 'Próximos do vencimento',
      value: _metricasProximosVencimento != null ? '$_metricasProximosVencimento' : '--',
      icon: Icons.schedule_outlined,
      variant: MetricVariant.warning,
      subtitle: 'Janela de 60 dias',
    );

    if (maxWidth >= 600) {
      return Row(
        children: [
          Expanded(child: kpiPendencias),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: kpiRenovacoes),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: kpiAtivos),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: kpiProximosVencimento),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: kpiPendencias),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: kpiRenovacoes),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(child: kpiAtivos),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: kpiProximosVencimento),
          ],
        ),
      ],
    );
  }

  Widget _buildBannerFiltroAtivo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18, color: AppColors.blue600),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              _filtroKpi == 'RENOVACOES'
                  ? 'Exibindo apenas solicitações de Renovação Anual'
                  : 'Filtro ativo',
              style: AppTypography.caption.copyWith(
                color: AppColors.blue600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _filtroKpi = null),
            child: const Text('Limpar filtro'),
          ),
        ],
      ),
    );
  }

  Widget _buildListaVazia() {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.s32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Nenhuma solicitação pendente',
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Todas as fichas de voluntários nas suas igrejas foram avaliadas.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabelaDesktop() {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 960),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            dataRowMinHeight: 64,
            dataRowMaxHeight: 80,
            columns: const [
              DataColumn(label: Text('Voluntário', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Igreja', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Equipe(s)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Data de Envio', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status / Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _pendenciasFiltradas.map((item) {
              final processando = _processandoFichaId == item.fichaId;
              return DataRow(
                key: ValueKey('rowFicha_${item.fichaId}'),
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.voluntarioNome,
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (item.ano > 0)
                          Text('Ciclo ${item.ano}', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(item.nomeIgreja ?? 'Igreja', style: AppTypography.body),
                  ),
                  DataCell(
                    Wrap(
                      spacing: 4,
                      children: item.equipes.map((e) {
                        return Chip(
                          label: Text(e.nomeEquipe, style: const TextStyle(fontSize: 12)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ),
                  DataCell(
                    Text(_formatarData(item.enviadoEm), style: AppTypography.body),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isRenovacaoAnual) ...[
                          Container(
                            key: Key('badgeRenovacaoAnual_${item.fichaId}'),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue50,
                              border: Border.all(color: AppColors.blue600),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Renovação', style: TextStyle(color: AppColors.blue600, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const StatusChip(
                          status: 'AGUARDANDO',
                          label: 'AGUARDANDO AVALIAÇÃO',
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          key: Key('btnAnalisar_${item.fichaId}'),
                          onPressed: processando ? null : () => _abrirDetalheSolicitacao(item),
                          icon: const Icon(Icons.assignment_outlined, size: 16),
                          label: const Text('Analisar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy900,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, AppGeometry.minTouchTarget),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: Key('btnRecusar_${item.fichaId}'),
                          onPressed: processando ? null : () => _abrirModalRecusa(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            minimumSize: const Size(90, AppGeometry.minTouchTarget),
                          ),
                          child: const Text('Recusar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: Key('btnAprovar_${item.fichaId}'),
                          onPressed: processando ? null : () => _abrirModalAprovacao(item),
                          icon: processando
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: const Text('Aprovar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, AppGeometry.minTouchTarget),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPendencia(ItemFilaPastor item) {
    final processando = _processandoFichaId == item.fichaId;

    return SectionCard(
      key: Key('cardFicha_${item.fichaId}'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.voluntarioNome,
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    if (item.nomeIgreja != null)
                      Row(
                        children: [
                          const Icon(Icons.church_outlined, size: 16, color: AppColors.blue600),
                          const SizedBox(width: AppSpacing.s4),
                          Expanded(
                            child: Text(
                              item.nomeIgreja!,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                color: AppColors.blue600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (item.isRenovacaoAnual) ...[
                Container(
                  key: Key('badgeRenovacaoAnual_${item.fichaId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    border: Border.all(color: AppColors.blue600),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.blue600),
                      const SizedBox(width: 4),
                      Text(
                        'Ciclo Anual ${item.ano}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.blue600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
              ],
              const StatusChip(
                status: 'AGUARDANDO',
                label: 'AGUARDANDO AVALIAÇÃO',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Equipes selecionadas:',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            children: item.equipes.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  e.nomeEquipe,
                  style: AppTypography.body.copyWith(fontSize: 13),
                ),
              );
            }).toList(),
          ),
          const Divider(height: AppSpacing.s16),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  key: Key('btnAnalisar_${item.fichaId}'),
                  onPressed: processando ? null : () => _abrirDetalheSolicitacao(item),
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text('Analisar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy900,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, AppGeometry.minTouchTarget),
                  ),
                ),
                OutlinedButton(
                  key: Key('btnRecusar_${item.fichaId}'),
                  onPressed: processando ? null : () => _abrirModalRecusa(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(110, AppGeometry.minTouchTarget),
                  ),
                  child: const Text('Recusar'),
                ),
                ElevatedButton.icon(
                  key: Key('btnAprovar_${item.fichaId}'),
                  onPressed: processando ? null : () => _abrirModalAprovacao(item),
                  icon: processando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Aprovar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, AppGeometry.minTouchTarget),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/metrics.dart';
import '../../ui/tokens.dart';
import '../renovacao/dashboard_renovacao_service.dart';
import 'responsavel_equipe_service.dart';

class FilaResponsavelEquipeScreen extends StatefulWidget {
  const FilaResponsavelEquipeScreen({
    super.key,
    required this.gateway,
    this.dashboardRenovacaoGateway,
    this.onSair,
    this.dentroDeShell = false,
  });

  final ResponsavelEquipeGateway gateway;
  final DashboardRenovacaoGateway? dashboardRenovacaoGateway;
  final VoidCallback? onSair;
  final bool dentroDeShell;

  @override
  State<FilaResponsavelEquipeScreen> createState() =>
      _FilaResponsavelEquipeScreenState();
}

class _FilaResponsavelEquipeScreenState
    extends State<FilaResponsavelEquipeScreen> {
  bool _carregando = true;
  String? _erro;
  List<ItemFilaResponsavelEquipe> _pendencias = [];
  List<EquipeEscopoResponsavel> _equipes = [];
  String? _equipeFiltroId;
  String? _acaoEmProgressoId;
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
      final res = await widget.gateway.obterFila();

      if (widget.dashboardRenovacaoGateway != null) {
        try {
          final resDashboard = await widget.dashboardRenovacaoGateway!.obterDashboardRenovacao(
            papelDesejado: PapelDashboard.responsavelEquipe,
            equipeId: _equipeFiltroId,
          );
          if (resDashboard.metricasResponsavel != null) {
            _metricasAtivos = resDashboard.metricasResponsavel!.totalEquipe;
            _metricasProximosVencimento = resDashboard.metricasResponsavel!.expiradas;
          }
        } catch (_) {
          // Fallback gracioso
        }
      }

      if (!mounted) return;
      setState(() {
        _pendencias = List.of(res.pendencias);
        _equipes = List.of(res.equipes);
        _carregando = false;
        if (_equipeFiltroId != null &&
            !_equipes.any((e) => e.id == _equipeFiltroId)) {
          _equipeFiltroId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar a fila de equipe. Tente novamente.';
        _carregando = false;
      });
    }
  }

  List<ItemFilaResponsavelEquipe> get _pendenciasNoEscopoEquipe {
    if (_equipeFiltroId == null || _equipeFiltroId!.isEmpty) {
      final idsAutorizados = _equipes.map((e) => e.id).toSet();
      return _pendencias.where((p) => idsAutorizados.contains(p.equipeId) || idsAutorizados.isEmpty).toList();
    }
    return _pendencias.where((p) => p.equipeId == _equipeFiltroId).toList();
  }

  List<ItemFilaResponsavelEquipe> get _pendenciasFiltradas {
    final base = _pendenciasNoEscopoEquipe;
    if (_filtroKpi == 'RENOVACOES') {
      return base.where((p) => p.isRenovacaoAnual).toList();
    }
    return base;
  }

  int get _countPendencias => _pendenciasNoEscopoEquipe.length;
  int get _countRenovacoes => _pendenciasNoEscopoEquipe.where((p) => p.isRenovacaoAnual).length;

  String _gerarCommandId() {
    final rand = Random().nextInt(99999999).toString().padLeft(8, '0');
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'cmd_resp_${ts}_$rand';
  }

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

  Future<void> _abrirModalAprovacao(ItemFilaResponsavelEquipe item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Aprovação da Participação'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deseja aprovar a participação de ${item.voluntarioNome} na equipe ${item.nomeEquipe}?',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.s12),
                if (item.nomeIgreja != null && item.nomeIgreja!.isNotEmpty)
                  Text('Igreja: ${item.nomeIgreja}', style: AppTypography.body),
                const SizedBox(height: AppSpacing.s16),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: AppGeometry.cardBorderRadius,
                  ),
                  child: Text(
                    'Ao aprovar, esta participação avançará para a etapa do Coordenador do Maanaim. '
                    'Decisões de outras equipes permanecem independentes.',
                    style: AppTypography.caption.copyWith(color: AppColors.blue600),
                  ),
                ),
              ],
            ),
          ),
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
      );
    }
  }

  Future<void> _abrirModalRecusa(ItemFilaResponsavelEquipe item) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decisão Negativa de Equipe'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
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
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Equipe: ${item.nomeEquipe}',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
                            '"Procure o Pastor da igreja local para mais informações". '
                            'A recusa desta equipe não cancela outras equipes do voluntário.',
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
                      labelText: 'Justificativa Interna da Equipe *',
                      hintText: 'Informe o motivo da recusa (mínimo 5 caracteres)',
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
    required ItemFilaResponsavelEquipe item,
    required String decisao,
    String? justificativa,
  }) async {
    setState(() => _acaoEmProgressoId = item.participacaoId);

    try {
      final entrada = EntradaDecidirParticipacaoResponsavel(
        commandId: _gerarCommandId(),
        participacaoId: item.participacaoId,
        cicloId: item.cicloId,
        decisao: decisao,
        justificativa: justificativa,
        expectedVersion: item.versao,
      );

      if (item.isRenovacaoAnual) {
        await widget.gateway.decidirCicloAnual(entrada);
      } else {
        await widget.gateway.decidirParticipacao(entrada);
      }

      if (!mounted) return;
      setState(() {
        _pendencias.removeWhere((p) => p.participacaoId == item.participacaoId);
        _acaoEmProgressoId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decisao == 'APROVADO'
                ? 'Participação na equipe ${item.nomeEquipe} aprovada com sucesso!'
                : 'Participação recusada. Mensagem padrão enviada ao voluntário.',
          ),
          backgroundColor:
              decisao == 'APROVADO' ? AppColors.success : AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acaoEmProgressoId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao registrar decisão: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
      _carregarFila();
    }
  }

  @override
  Widget build(BuildContext context) {
    final corpo = SafeArea(
      child: _carregando
          ? const Center(
              child: CircularProgressIndicator(
                key: Key('progressoCarregamentoFilaEquipe'),
              ),
            )
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
        title: const Text('Fila do Responsável de Equipe'),
        actions: [
          IconButton(
            tooltip: 'Atualizar fila',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregarFila,
          ),
          if (widget.onSair != null)
            IconButton(
              tooltip: 'Sair da conta',
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
            Text(_erro!, style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s16),
            ElevatedButton.icon(
              key: const Key('btnTentarNovamenteFilaEquipe'),
              onPressed: _carregarFila,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_equipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Nenhuma equipe sob sua responsabilidade vigente.',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Você não possui vínculos ativos como responsável de equipe no momento.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        return RefreshIndicator(
          onRefresh: _carregarFila,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    _buildCabecalhoFiltros(isDesktop),
                    const SizedBox(height: AppSpacing.s8),
                    _buildKpis(constraints.maxWidth),
                    const SizedBox(height: AppSpacing.s8),
                    if (_filtroKpi != null) ...[
                      _buildBannerFiltroAtivo(),
                      const SizedBox(height: AppSpacing.s8),
                    ],
                    if (_pendenciasFiltradas.isEmpty)
                      _buildVazio()
                    else if (isDesktop)
                      _buildTabelaDesktop()
                    else
                      ..._pendenciasFiltradas.map((item) => _buildCardPendencia(item, isDesktop)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCabecalhoFiltros(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Participações Pendentes de Avaliação',
                style: AppTypography.h2,
              ),
              const SizedBox(height: 2),
              Text(
                'Avalie as solicitações de participação nas equipes sob sua responsabilidade.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (_equipes.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.s12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
            child: DropdownButtonFormField<String?>(
              key: const Key('dropdownFiltroEquipe'),
              initialValue: _equipeFiltroId,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                labelText: 'Equipe',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas as equipes'),
                ),
                ..._equipes.map(
                  (eq) => DropdownMenuItem<String?>(
                    value: eq.id,
                    child: Text(eq.nome, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _equipeFiltroId = val);
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
      subtitle: 'Voluntários na equipe',
    );

    final kpiProximosVencimento = MetricCard(
      title: 'Próximos do vencimento',
      value: _metricasProximosVencimento != null ? '$_metricasProximosVencimento' : '--',
      icon: Icons.schedule_outlined,
      variant: MetricVariant.warning,
      subtitle: 'Janela de renovação',
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

  Widget _buildVazio() {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.task_alt, size: 56, color: AppColors.success),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Nenhuma pendência na fila!',
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _equipeFiltroId != null
                  ? 'Todas as participações da equipe selecionada foram analisadas.'
                  : 'Todas as participações sob sua responsabilidade foram avaliadas.',
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
              DataColumn(label: Text('Equipe', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Data de Envio', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _pendenciasFiltradas.map((item) {
              final emProgresso = _acaoEmProgressoId == item.participacaoId;
              return DataRow(
                key: ValueKey('rowParticipacao_${item.participacaoId}'),
                cells: [
                  DataCell(
                    Text(
                      item.voluntarioNome,
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Text(item.nomeIgreja != null ? 'Igreja: ${item.nomeIgreja}' : '-', style: AppTypography.body),
                  ),
                  DataCell(
                    Chip(
                      label: Text(item.nomeEquipe, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.blue50,
                      labelStyle: const TextStyle(color: AppColors.navy900, fontWeight: FontWeight.w600),
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
                            key: Key('badgeRenovacaoAnual_${item.participacaoId}'),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pendente',
                            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    emProgresso
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                key: Key('btnRecusar_${item.participacaoId}'),
                                onPressed: () => _abrirModalRecusa(item),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  minimumSize: const Size(90, AppGeometry.minTouchTarget),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Recusar'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                key: Key('btnAprovar_${item.participacaoId}'),
                                onPressed: () => _abrirModalAprovacao(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, AppGeometry.minTouchTarget),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Aprovar'),
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

  Widget _buildCardPendencia(ItemFilaResponsavelEquipe item, bool isDesktop) {
    final emProgresso = _acaoEmProgressoId == item.participacaoId;

    return Container(
      key: Key('cardParticipacao_${item.participacaoId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.blue50,
                child: Text(
                  item.voluntarioNome.isNotEmpty
                      ? item.voluntarioNome[0].toUpperCase()
                      : 'V',
                  style: const TextStyle(
                    color: AppColors.navy900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.voluntarioNome,
                      style: AppTypography.h2,
                    ),
                    const SizedBox(height: 2),
                    if (item.nomeIgreja != null && item.nomeIgreja!.isNotEmpty)
                      Text(
                        'Igreja: ${item.nomeIgreja}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.isRenovacaoAnual) ...[
                Container(
                  key: Key('badgeRenovacaoAnual_${item.participacaoId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 6),
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
                        item.anoVigencia != null ? 'Ciclo Anual ${item.anoVigencia}' : 'Ciclo Anual',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.blue600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Pendente',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: [
              Text(
                'Equipe:',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Chip(
                label: Text(item.nomeEquipe),
                backgroundColor: AppColors.blue50,
                labelStyle: const TextStyle(
                  color: AppColors.navy900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          if (emProgresso)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: OverflowBar(
                spacing: AppSpacing.s12,
                overflowSpacing: AppSpacing.s8,
                alignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: Key('btnRecusar_${item.participacaoId}'),
                    onPressed: () => _abrirModalRecusa(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size(110, AppGeometry.minTouchTarget),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Recusar'),
                  ),
                  ElevatedButton.icon(
                    key: Key('btnAprovar_${item.participacaoId}'),
                    onPressed: () => _abrirModalAprovacao(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, AppGeometry.minTouchTarget),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprovar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../ui/components/layout_elements.dart';
import '../../ui/components/metrics.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import 'dashboard_renovacao_service.dart';

/// Tela responsiva mobile-first para exibição dos dashboards de renovação por papel (Story 5.4).
/// Suporta perfis: Voluntário, Pastor Local, Responsável de Equipe e Coordenador Geral.
class DashboardRenovacaoScreen extends StatefulWidget {
  const DashboardRenovacaoScreen({
    super.key,
    required this.gateway,
    this.papelInicial,
    this.onSair,
    this.onManifestarVoluntario,
    this.onAnalisarPastor,
    this.onDeliberarResponsavel,
    this.onDetalhesCoordenador,
  });

  final DashboardRenovacaoGateway gateway;
  final PapelDashboard? papelInicial;
  final VoidCallback? onSair;
  final void Function(ItemRenovacaoVoluntarioModel item)? onManifestarVoluntario;
  final void Function(ItemRenovacaoPastorModel item)? onAnalisarPastor;
  final void Function(ItemRenovacaoResponsavelModel item)? onDeliberarResponsavel;
  final void Function(ItemRenovacaoCoordenadorModel item)? onDetalhesCoordenador;

  @override
  State<DashboardRenovacaoScreen> createState() => _DashboardRenovacaoScreenState();
}

class _DashboardRenovacaoScreenState extends State<DashboardRenovacaoScreen> {
  bool _carregando = true;
  String? _erro;
  ResultadoDashboardRenovacaoModel? _dados;

  late PapelDashboard _papelAtivo;
  String? _filtroIgrejaId;
  String? _filtroEquipeId;
  String? _filtroEstado;
  int? _filtroAno;
  int _paginaAtual = 1;
  static const int _limitePorPagina = 15;

  @override
  void initState() {
    super.initState();
    _papelAtivo = widget.papelInicial ?? PapelDashboard.voluntario;
    _carregarDados();
  }

  Future<void> _carregarDados({int pagina = 1}) async {
    setState(() {
      _carregando = true;
      _erro = null;
      _paginaAtual = pagina;
    });

    try {
      final res = await widget.gateway.obterDashboardRenovacao(
        papelDesejado: _papelAtivo,
        igrejaId: _filtroIgrejaId,
        equipeId: _filtroEquipeId,
        estadoRenovacao: _filtroEstado,
        anoVigencia: _filtroAno,
        limite: _limitePorPagina,
        pagina: pagina,
      );

      if (mounted) {
        setState(() {
          _dados = res;
          _papelAtivo = res.papelResolvido;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar as informações do dashboard.';
          _carregando = false;
        });
      }
    }
  }

  String _formatarDataIso(String? iso) {
    if (iso == null || iso.isEmpty) return 'Não definida';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year.toString();
      return '$dia/$mes/$ano';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isDesktop = mediaWidth >= 1024;
    final isTablet = mediaWidth >= 600 && mediaWidth < 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _carregarDados(pagina: 1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop
                  ? AppSpacing.s32
                  : isTablet
                      ? AppSpacing.s24
                      : AppSpacing.s16,
              vertical: AppSpacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDesktop),
                const SizedBox(height: AppSpacing.s24),
                if (_carregando && _dados == null)
                  _buildEstadoCarregando()
                else if (_erro != null)
                  _buildEstadoErro()
                else if (_dados != null) ...[
                  _buildSecaoMetricas(isDesktop, isTablet),
                  const SizedBox(height: AppSpacing.s24),
                  _buildSecaoFiltros(isDesktop),
                  const SizedBox(height: AppSpacing.s16),
                  _buildSecaoConteudo(isDesktop),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    String subtitulo;
    switch (_papelAtivo) {
      case PapelDashboard.voluntario:
        subtitulo = 'Acompanhe a validade e a renovação de suas equipes voluntárias.';
        break;
      case PapelDashboard.pastorLocal:
        subtitulo = 'Gestão das renovações de voluntários sob seu pastoreio local.';
        break;
      case PapelDashboard.responsavelEquipe:
        subtitulo = 'Gestão de continuidade dos voluntários nas equipes sob sua liderança.';
        break;
      case PapelDashboard.coordenador:
      case PapelDashboard.administrador:
        subtitulo = 'Visão consolidada global do ciclo de renovações do Maanaim.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Dashboard de Renovação',
                      style: AppTypography.h1.copyWith(
                        fontSize: isDesktop ? 28 : 22,
                        color: AppColors.navy900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitulo,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.blue600),
              tooltip: 'Atualizar dados',
              onPressed: () => _carregarDados(pagina: _paginaAtual),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEstadoCarregando() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s48),
        child: Semantics(
          label: 'Carregando dashboard de renovação',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildEstadoErro() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: AppSpacing.s12),
          Text(
            _erro ?? 'Ocorreu um erro ao carregar os dados.',
            style: AppTypography.body.copyWith(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s16),
          ElevatedButton.icon(
            onPressed: () => _carregarDados(pagina: 1),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEÇÃO DE MÉTRICAS (KPIS)
  // ---------------------------------------------------------------------------
  Widget _buildSecaoMetricas(bool isDesktop, bool isTablet) {
    final dados = _dados!;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

    switch (_papelAtivo) {
      case PapelDashboard.voluntario:
        final m = dados.metricasVoluntario ??
            const MetricasRenovacaoVoluntarioModel(
              totalParticipacoesAtivas: 0,
              emJanelaRenovacao: 0,
              pendentesManifestacao: 0,
              emTramitacao: 0,
              expiradas: 0,
            );
        final kpis = [
          MetricCard(
            title: 'Equipes Ativas',
            value: m.totalParticipacoesAtivas.toString(),
            icon: Icons.check_circle_outline,
            variant: MetricVariant.primary,
          ),
          MetricCard(
            title: 'Em Janela de Renovação',
            value: m.emJanelaRenovacao.toString(),
            icon: Icons.alarm,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Pendente Manifestação',
            value: m.pendentesManifestacao.toString(),
            icon: Icons.pending_actions,
            variant: MetricVariant.danger,
          ),
          MetricCard(
            title: 'Em Tramitação / Análise',
            value: m.emTramitacao.toString(),
            icon: Icons.hourglass_top,
            variant: MetricVariant.neutral,
          ),
        ];
        return _buildGridMetricas(kpis, crossAxisCount);

      case PapelDashboard.pastorLocal:
        final m = dados.metricasPastor ??
            const MetricasRenovacaoPastorModel(
              pendentesParecer: 0,
              semManifestacao: 0,
              proximasVencimento: 0,
              expiradas: 0,
              totalSobEscopo: 0,
            );
        final kpis = [
          MetricCard(
            title: 'Pendentes do Pastor',
            value: m.pendentesParecer.toString(),
            icon: Icons.how_to_reg,
            variant: MetricVariant.danger,
          ),
          MetricCard(
            title: 'Sem Manifestação',
            value: m.semManifestacao.toString(),
            icon: Icons.warning_amber,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Vencimento < 30 dias',
            value: m.proximasVencimento.toString(),
            icon: Icons.alarm,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Expiradas',
            value: m.expiradas.toString(),
            icon: Icons.cancel_outlined,
            variant: MetricVariant.danger,
          ),
        ];
        return _buildGridMetricas(kpis, crossAxisCount);

      case PapelDashboard.responsavelEquipe:
        final m = dados.metricasResponsavel ??
            const MetricasRenovacaoResponsavelModel(
              pendentesEquipe: 0,
              emTramitacao: 0,
              semManifestacao: 0,
              expiradas: 0,
              totalEquipe: 0,
            );
        final kpis = [
          MetricCard(
            title: 'Pendentes da Equipe',
            value: m.pendentesEquipe.toString(),
            icon: Icons.groups,
            variant: MetricVariant.danger,
          ),
          MetricCard(
            title: 'Em Tramitação',
            value: m.emTramitacao.toString(),
            icon: Icons.sync,
            variant: MetricVariant.primary,
          ),
          MetricCard(
            title: 'Sem Manifestação',
            value: m.semManifestacao.toString(),
            icon: Icons.hourglass_empty,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Expiradas',
            value: m.expiradas.toString(),
            icon: Icons.event_busy,
            variant: MetricVariant.danger,
          ),
        ];
        return _buildGridMetricas(kpis, crossAxisCount);

      case PapelDashboard.coordenador:
      case PapelDashboard.administrador:
        final m = dados.metricasCoordenador ??
            const MetricasRenovacaoCoordenadorModel(
              totalAtivos: 0,
              emJanelaRenovacao: 0,
              pendentesPastorLocal: 0,
              pendentesResponsaveis: 0,
              aguardandoCoordenador: 0,
              renovadosConcluidos: 0,
              expirados: 0,
            );
        final kpis = [
          MetricCard(
            title: 'Total Ativos',
            value: m.totalAtivos.toString(),
            icon: Icons.people_outline,
            variant: MetricVariant.primary,
          ),
          MetricCard(
            title: 'Em Janela Renovação',
            value: m.emJanelaRenovacao.toString(),
            icon: Icons.event_repeat,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Aguardando Coordenação',
            value: m.aguardandoCoordenador.toString(),
            icon: Icons.verified_user_outlined,
            variant: MetricVariant.danger,
          ),
          MetricCard(
            title: 'Pendentes Responsáveis',
            value: m.pendentesResponsaveis.toString(),
            icon: Icons.group_work_outlined,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Pendentes Pastor Local',
            value: m.pendentesPastorLocal.toString(),
            icon: Icons.church_outlined,
            variant: MetricVariant.warning,
          ),
          MetricCard(
            title: 'Renovados / Concluídos',
            value: m.renovadosConcluidos.toString(),
            icon: Icons.check_circle_outline,
            variant: MetricVariant.success,
          ),
          MetricCard(
            title: 'Expirados',
            value: m.expirados.toString(),
            icon: Icons.cancel_outlined,
            variant: MetricVariant.danger,
          ),
        ];
        return _buildGridMetricas(kpis, crossAxisCount);
    }
  }

  Widget _buildGridMetricas(List<Widget> cards, int crossAxisCount) {
    if (crossAxisCount == 1) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: c,
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * AppSpacing.s16) / crossAxisCount;
        return Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SEÇÃO DE FILTROS DINÂMICOS
  // ---------------------------------------------------------------------------
  Widget _buildSecaoFiltros(bool isDesktop) {
    final dados = _dados!;
    final temFiltroIgreja = dados.igrejasEscopo.length > 1;
    final temFiltroEquipe = dados.equipesEscopo.length > 1;

    if (!temFiltroIgreja &&
        !temFiltroEquipe &&
        _papelAtivo == PapelDashboard.voluntario) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: AppColors.navy900),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Filtros',
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (temFiltroIgreja)
                DropdownButton<String?>(
                  value: _filtroIgrejaId,
                  hint: const Text('Todas as igrejas'),
                  onChanged: (val) {
                    setState(() => _filtroIgrejaId = val);
                    _carregarDados(pagina: 1);
                  },
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas as igrejas'),
                    ),
                    ...dados.igrejasEscopo.map(
                      (ig) => DropdownMenuItem<String?>(
                        value: ig.id,
                        child: Text(ig.nome),
                      ),
                    ),
                  ],
                ),
              if (temFiltroEquipe)
                DropdownButton<String?>(
                  value: _filtroEquipeId,
                  hint: const Text('Todas as equipes'),
                  onChanged: (val) {
                    setState(() => _filtroEquipeId = val);
                    _carregarDados(pagina: 1);
                  },
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas as equipes'),
                    ),
                    ...dados.equipesEscopo.map(
                      (eq) => DropdownMenuItem<String?>(
                        value: eq.id,
                        child: Text(eq.nome),
                      ),
                    ),
                  ],
                ),
              // Filtro rápido por situação
              if (_papelAtivo == PapelDashboard.pastorLocal) ...[
                _buildChipFiltro('TODOS', 'Todos', _filtroEstado == null),
                _buildChipFiltro('PENDENTE_PASTOR', 'Pendentes do Pastor', _filtroEstado == 'PENDENTE_PASTOR'),
                _buildChipFiltro('SEM_MANIFESTACAO', 'Sem Manifestação', _filtroEstado == 'SEM_MANIFESTACAO'),
                _buildChipFiltro('PROXIMO_VENCIMENTO', 'Próx. Vencimento', _filtroEstado == 'PROXIMO_VENCIMENTO'),
                _buildChipFiltro('EXPIRADA', 'Expiradas', _filtroEstado == 'EXPIRADA'),
              ],
              if (_papelAtivo == PapelDashboard.responsavelEquipe) ...[
                _buildChipFiltro('TODOS', 'Todos', _filtroEstado == null),
                _buildChipFiltro('PENDENTE_EQUIPE', 'Pendentes da Equipe', _filtroEstado == 'PENDENTE_EQUIPE'),
                _buildChipFiltro('EM_TRAMITACAO', 'Em Tramitação', _filtroEstado == 'EM_TRAMITACAO'),
                _buildChipFiltro('SEM_MANIFESTACAO', 'Sem Manifestação', _filtroEstado == 'SEM_MANIFESTACAO'),
                _buildChipFiltro('EXPIRADA', 'Expiradas', _filtroEstado == 'EXPIRADA'),
              ],
              if (_papelAtivo == PapelDashboard.coordenador || _papelAtivo == PapelDashboard.administrador) ...[
                _buildChipFiltro('TODOS', 'Todos', _filtroEstado == null),
                _buildChipFiltro('AGUARDANDO_COORDENADOR', 'Aguardando Coordenação', _filtroEstado == 'AGUARDANDO_COORDENADOR'),
                _buildChipFiltro('AGUARDANDO_RESPONSAVEL_EQUIPE', 'Pend. Responsável', _filtroEstado == 'AGUARDANDO_RESPONSAVEL_EQUIPE'),
                _buildChipFiltro('AGUARDANDO_PASTOR_LOCAL', 'Pend. Pastor', _filtroEstado == 'AGUARDANDO_PASTOR_LOCAL'),
                _buildChipFiltro('RENOVADO_CONCLUIDO', 'Renovados', _filtroEstado == 'RENOVADO_CONCLUIDO'),
                _buildChipFiltro('SEM_MANIFESTACAO', 'Sem Manifestação', _filtroEstado == 'SEM_MANIFESTACAO'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String valor, String label, bool selecionado) {
    return FilterChip(
      selected: selecionado,
      label: Text(label),
      selectedColor: AppColors.blue50,
      checkmarkColor: AppColors.blue600,
      labelStyle: TextStyle(
        color: selecionado ? AppColors.blue600 : AppColors.textPrimary,
        fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (_) {
        setState(() {
          _filtroEstado = valor == 'TODOS' ? null : valor;
        });
        _carregarDados(pagina: 1);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SEÇÃO DE CONTEÚDO (TABELAS / CARDS)
  // ---------------------------------------------------------------------------
  Widget _buildSecaoConteudo(bool isDesktop) {
    final dados = _dados!;

    switch (_papelAtivo) {
      case PapelDashboard.voluntario:
        return _buildConteudoVoluntario(dados.itensVoluntario);
      case PapelDashboard.pastorLocal:
        return _buildConteudoPastor(dados.itensPastor, isDesktop);
      case PapelDashboard.responsavelEquipe:
        return _buildConteudoResponsavel(dados.itensResponsavel, isDesktop);
      case PapelDashboard.coordenador:
      case PapelDashboard.administrador:
        return _buildConteudoCoordenador(dados.itensCoordenador, isDesktop);
    }
  }

  // --- Voluntário ---
  Widget _buildConteudoVoluntario(List<ItemRenovacaoVoluntarioModel> itens) {
    if (itens.isEmpty) {
      return _buildVazio('Você não possui participações registradas.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: itens.map((it) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppGeometry.cardBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      it.equipeNome,
                      style: AppTypography.h3.copyWith(color: AppColors.navy900),
                    ),
                  ),
                  StatusChip(status: it.estadoParticipacao),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    'Vencimento: ${_formatarDataIso(it.vigenciaFim)}',
                    style: AppTypography.caption,
                  ),
                  const Spacer(),
                  if (it.diasRestantes != null)
                    Text(
                      it.diasRestantes! <= 0
                          ? 'Vencida'
                          : '${it.diasRestantes} dias restantes',
                      style: AppTypography.label.copyWith(
                        color: it.diasRestantes! <= 30
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (it.estadoCiclo != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ciclo ${it.anoCiclo ?? ""}: ${it.estadoCiclo}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (it.podeManifestar) ...[
                const SizedBox(height: AppSpacing.s16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onManifestarVoluntario?.call(it),
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Manifestar Interesse de Renovação'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- Pastor Local ---
  Widget _buildConteudoPastor(List<ItemRenovacaoPastorModel> itens, bool isDesktop) {
    if (itens.isEmpty) {
      return _buildVazio('Nenhuma renovação encontrada para este escopo.');
    }

    if (!isDesktop) {
      return Column(
        children: [
          ...itens.map((it) => _buildCardPastor(it)),
          _buildPaginacao(),
        ],
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Voluntário')),
                DataColumn(label: Text('Igreja')),
                DataColumn(label: Text('Equipe')),
                DataColumn(label: Text('Vencimento')),
                DataColumn(label: Text('Situação')),
                DataColumn(label: Text('Ações')),
              ],
              rows: itens.map((it) {
                return DataRow(cells: [
                  DataCell(Text(it.voluntarioNome)),
                  DataCell(Text(it.igrejaNome)),
                  DataCell(Text(it.equipeNome)),
                  DataCell(Text(_formatarDataIso(it.vigenciaFim))),
                  DataCell(StatusChip(status: it.estadoRenovacao)),
                  DataCell(
                    it.estadoRenovacao == 'PENDENTE_PASTOR'
                        ? TextButton.icon(
                            onPressed: () => widget.onAnalisarPastor?.call(it),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Analisar'),
                          )
                        : const Text('-'),
                  ),
                ]);
              }).toList(),
            ),
          ),
          _buildPaginacao(),
        ],
      ),
    );
  }

  Widget _buildCardPastor(ItemRenovacaoPastorModel it) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  it.voluntarioNome,
                  style: AppTypography.h3.copyWith(color: AppColors.navy900),
                ),
              ),
              StatusChip(status: it.estadoRenovacao),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '${it.igrejaNome} • ${it.equipeNome}',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vence em: ${_formatarDataIso(it.vigenciaFim)}',
                style: AppTypography.caption,
              ),
              if (it.diasRestantes != null)
                Text(
                  it.diasRestantes! <= 0 ? 'Expirada' : '${it.diasRestantes} dias',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: it.diasRestantes! <= 30 ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
            ],
          ),
          if (it.estadoRenovacao == 'PENDENTE_PASTOR') ...[
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onAnalisarPastor?.call(it),
                icon: const Icon(Icons.check),
                label: const Text('Analisar Renovação'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Responsável de Equipe ---
  Widget _buildConteudoResponsavel(List<ItemRenovacaoResponsavelModel> itens, bool isDesktop) {
    if (itens.isEmpty) {
      return _buildVazio('Nenhuma renovação encontrada para a sua equipe.');
    }

    if (!isDesktop) {
      return Column(
        children: [
          ...itens.map((it) => _buildCardResponsavel(it)),
          _buildPaginacao(),
        ],
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Voluntário')),
                DataColumn(label: Text('Equipe')),
                DataColumn(label: Text('Igreja')),
                DataColumn(label: Text('Vencimento')),
                DataColumn(label: Text('Situação')),
                DataColumn(label: Text('Ações')),
              ],
              rows: itens.map((it) {
                return DataRow(cells: [
                  DataCell(Text(it.voluntarioNome)),
                  DataCell(Text(it.equipeNome)),
                  DataCell(Text(it.igrejaNome)),
                  DataCell(Text(_formatarDataIso(it.vigenciaFim))),
                  DataCell(StatusChip(status: it.estadoRenovacao)),
                  DataCell(
                    it.estadoRenovacao == 'PENDENTE_EQUIPE'
                        ? TextButton.icon(
                            onPressed: () => widget.onDeliberarResponsavel?.call(it),
                            icon: const Icon(Icons.how_to_reg, size: 16),
                            label: const Text('Deliberar'),
                          )
                        : const Text('-'),
                  ),
                ]);
              }).toList(),
            ),
          ),
          _buildPaginacao(),
        ],
      ),
    );
  }

  Widget _buildCardResponsavel(ItemRenovacaoResponsavelModel it) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  it.voluntarioNome,
                  style: AppTypography.h3.copyWith(color: AppColors.navy900),
                ),
              ),
              StatusChip(status: it.estadoRenovacao),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '${it.equipeNome} • ${it.igrejaNome}',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vence em: ${_formatarDataIso(it.vigenciaFim)}',
                style: AppTypography.caption,
              ),
              if (it.diasRestantes != null)
                Text(
                  it.diasRestantes! <= 0 ? 'Expirada' : '${it.diasRestantes} dias',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: it.diasRestantes! <= 30 ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
            ],
          ),
          if (it.estadoRenovacao == 'PENDENTE_EQUIPE') ...[
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onDeliberarResponsavel?.call(it),
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Deliberar Continuacão'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Coordenador Geral ---
  Widget _buildConteudoCoordenador(List<ItemRenovacaoCoordenadorModel> itens, bool isDesktop) {
    if (itens.isEmpty) {
      return _buildVazio('Nenhuma renovação encontrada para os filtros selecionados.');
    }

    if (!isDesktop) {
      return Column(
        children: [
          ...itens.map((it) => _buildCardCoordenador(it)),
          _buildPaginacao(),
        ],
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Voluntário')),
                DataColumn(label: Text('Igreja')),
                DataColumn(label: Text('Equipe')),
                DataColumn(label: Text('Vencimento')),
                DataColumn(label: Text('Situação')),
                DataColumn(label: Text('Ações')),
              ],
              rows: itens.map((it) {
                return DataRow(cells: [
                  DataCell(Text(it.voluntarioNome)),
                  DataCell(Text(it.igrejaNome)),
                  DataCell(Text(it.equipeNome)),
                  DataCell(Text(_formatarDataIso(it.vigenciaFim))),
                  DataCell(StatusChip(status: it.estadoRenovacao)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      tooltip: 'Detalhes',
                      onPressed: () => widget.onDetalhesCoordenador?.call(it),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
          _buildPaginacao(),
        ],
      ),
    );
  }

  Widget _buildCardCoordenador(ItemRenovacaoCoordenadorModel it) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  it.voluntarioNome,
                  style: AppTypography.h3.copyWith(color: AppColors.navy900),
                ),
              ),
              StatusChip(status: it.estadoRenovacao),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '${it.igrejaNome} • ${it.equipeNome}',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vence em: ${_formatarDataIso(it.vigenciaFim)}',
                style: AppTypography.caption,
              ),
              if (it.diasRestantes != null)
                Text(
                  it.diasRestantes! <= 0 ? 'Expirada' : '${it.diasRestantes} dias',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: it.diasRestantes! <= 30 ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginacao() {
    final dados = _dados!;
    if (dados.totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Página anterior',
            onPressed: _paginaAtual > 1
                ? () => _carregarDados(pagina: _paginaAtual - 1)
                : null,
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(
            'Página $_paginaAtual de ${dados.totalPaginas} (${dados.totalItens} registros)',
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: AppSpacing.s12),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próxima página',
            onPressed: _paginaAtual < dados.totalPaginas
                ? () => _carregarDados(pagina: _paginaAtual + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVazio(String mensagem) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.s12),
          Text(
            mensagem,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../ui/identidade.dart';
import 'auditoria_service.dart';

/// Superfície de Auditoria e Relatórios autorizados com mobile-first e acessibilidade WCAG 2.2 AA (AD-8, AD-9, AD-12).
class AuditoriaRelatoriosScreen extends StatefulWidget {
  const AuditoriaRelatoriosScreen({
    super.key,
    required this.gateway,
    this.onSair,
  });

  final AuditoriaRelatoriosGateway gateway;
  final VoidCallback? onSair;

  @override
  State<AuditoriaRelatoriosScreen> createState() => _AuditoriaRelatoriosScreenState();
}

class _AuditoriaRelatoriosScreenState extends State<AuditoriaRelatoriosScreen> {
  int _abaSelecionada = 0; // 0 = Auditoria, 1 = Relatório

  // Estado de Auditoria
  bool _carregandoAuditoria = false;
  String? _erroAuditoria;
  List<ItemAuditoria> _itensAuditoria = [];
  String? _proximoCursor;
  bool _temMaisAuditoria = false;
  String _filtroAcao = '';
  final TextEditingController _acaoController = TextEditingController();

  // Estado de Relatório
  bool _carregandoRelatorio = false;
  String? _erroRelatorio;
  ResultadoRelatorioOperacional? _relatorio;

  @override
  void initState() {
    super.initState();
    _carregarAuditoria();
    _carregarRelatorio();
  }

  @override
  void dispose() {
    _acaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarAuditoria({bool carregarMais = false}) async {
    setState(() {
      _carregandoAuditoria = true;
      if (!carregarMais) {
        _erroAuditoria = null;
      }
    });

    try {
      final res = await widget.gateway.consultarAuditoria(
        FiltrosAuditoria(
          acao: _filtroAcao.isNotEmpty ? _filtroAcao : null,
          limite: 20,
          cursor: carregarMais ? _proximoCursor : null,
        ),
      );

      if (!mounted) return;
      setState(() {
        if (carregarMais) {
          _itensAuditoria.addAll(res.itens);
        } else {
          _itensAuditoria = res.itens;
        }
        _proximoCursor = res.proximoCursor;
        _temMaisAuditoria = res.temMais;
        _carregandoAuditoria = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _erroAuditoria = 'Não foi possível carregar os registros de auditoria.';
        _carregandoAuditoria = false;
      });
    }
  }

  Future<void> _carregarRelatorio() async {
    setState(() {
      _carregandoRelatorio = true;
      _erroRelatorio = null;
    });

    try {
      final res = await widget.gateway.consultarRelatorio(const FiltrosRelatorio());
      if (!mounted) return;
      setState(() {
        _relatorio = res;
        _carregandoRelatorio = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _erroRelatorio = 'Não foi possível gerar o relatório operacional.';
        _carregandoRelatorio = false;
      });
    }
  }

  Widget _buildSeletorAbas() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildItemAba(
              indice: 0,
              titulo: 'Trilha de Auditoria',
              icone: Icons.history_edu_outlined,
              iconeAtivo: Icons.history_edu,
            ),
            _buildItemAba(
              indice: 1,
              titulo: 'Relatório Operacional',
              icone: Icons.analytics_outlined,
              iconeAtivo: Icons.analytics,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemAba({
    required int indice,
    required String titulo,
    required IconData icone,
    required IconData iconeAtivo,
  }) {
    final ativo = _abaSelecionada == indice;
    return InkWell(
      onTap: () => setState(() => _abaSelecionada = indice),
      borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ativo ? AppColors.blue600 : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              ativo ? iconeAtivo : icone,
              size: 20,
              color: ativo ? AppColors.blue600 : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              titulo,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                color: ativo ? AppColors.blue600 : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosAuditoria() {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Wrap(
        spacing: AppSpacing.s12,
        runSpacing: AppSpacing.s12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _acaoController,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Ação',
                hintText: 'Ex.: DECISAO_PASTOR_LOCAL',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onSubmitted: (val) {
                _filtroAcao = val.trim();
                _carregarAuditoria();
              },
            ),
          ),
          PrimaryButton(
            label: 'Filtrar',
            icon: Icons.filter_list,
            onPressed: () {
              _filtroAcao = _acaoController.text.trim();
              _carregarAuditoria();
            },
          ),
          if (_filtroAcao.isNotEmpty)
            SecondaryButton(
              label: 'Limpar Filtros',
              icon: Icons.clear,
              onPressed: () {
                _acaoController.clear();
                _filtroAcao = '';
                _carregarAuditoria();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildListaAuditoriaMobile(List<ItemAuditoria> itens) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, i) {
        final item = itens[i];
        return SectionCard(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  StatusChip(status: item.acao),
                  Text(
                    item.timestamp.length > 19
                        ? item.timestamp.substring(0, 19).replaceAll('T', ' ')
                        : item.timestamp,
                    style: AppTypography.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Comando: ${item.commandId}',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Ator: ${item.atorUid}', style: AppTypography.caption),
              if (item.entidades.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s4,
                  runSpacing: AppSpacing.s4,
                  children: item.entidades.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${e['tipo']}: ${e['id']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabelaAuditoriaDesktop(List<ItemAuditoria> itens) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          columns: const [
            DataColumn(label: Text('Data / Hora (UTC)', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Ação', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Ator', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Command ID', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Entidades Referenciadas', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: itens.map((item) {
            final dataFormatada = item.timestamp.length > 19
                ? item.timestamp.substring(0, 19).replaceAll('T', ' ')
                : item.timestamp;
            final entidadesFormatadas = item.entidades
                .map((e) => '${e['tipo']}: ${e['id']}')
                .join(', ');

            return DataRow(
              cells: [
                DataCell(Text(dataFormatada, style: AppTypography.caption)),
                DataCell(StatusChip(status: item.acao)),
                DataCell(Text(item.atorUid, style: AppTypography.caption)),
                DataCell(Text(item.commandId, style: AppTypography.caption)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      entidadesFormatadas.isEmpty ? '—' : entidadesFormatadas,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCorpoAuditoria(bool isMobile) {
    if (_carregandoAuditoria && _itensAuditoria.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            LoadingSkeleton(height: 50),
            SizedBox(height: AppSpacing.s12),
            LoadingSkeleton(height: 120),
            SizedBox(height: AppSpacing.s12),
            LoadingSkeleton(height: 120),
          ],
        ),
      );
    }

    if (_erroAuditoria != null && _itensAuditoria.isEmpty) {
      return ErrorState(
        title: 'Falha ao consultar auditoria',
        message: _erroAuditoria!,
        onRetry: () => _carregarAuditoria(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFiltrosAuditoria(),
        const SizedBox(height: AppSpacing.s16),
        if (_itensAuditoria.isEmpty)
          const EmptyState(
            title: 'Nenhum registro de auditoria encontrado',
            message: 'Tente ajustar os filtros ou selecionar outro período de pesquisa.',
            icon: Icons.history_edu_outlined,
          )
        else ...[
          isMobile
              ? _buildListaAuditoriaMobile(_itensAuditoria)
              : _buildTabelaAuditoriaDesktop(_itensAuditoria),
          const SizedBox(height: AppSpacing.s16),
          if (_temMaisAuditoria)
            Center(
              child: _carregandoAuditoria
                  ? const CircularProgressIndicator()
                  : PrimaryButton(
                      label: 'Carregar mais registros',
                      icon: Icons.expand_more,
                      onPressed: () => _carregarAuditoria(carregarMais: true),
                    ),
            ),
        ],
      ],
    );
  }

  Widget _buildMetricasRelatorio(MetricasRelatorio metricas, bool isMobile) {
    final cards = [
      MetricCard(
        title: 'Total de Voluntários',
        value: metricas.totalVoluntarios.toString(),
        icon: Icons.people_outline,
        variant: MetricVariant.primary,
      ),
      MetricCard(
        title: 'Fichas Ativas',
        value: metricas.totalFichasAtivas.toString(),
        icon: Icons.verified_outlined,
        variant: MetricVariant.success,
      ),
      MetricCard(
        title: 'Participações Ativas',
        value: metricas.totalParticipacoesAtivas.toString(),
        icon: Icons.groups_outlined,
        variant: MetricVariant.primary,
      ),
      MetricCard(
        title: 'Aguardando Aprovação',
        value: metricas.totalAguardandoAprovacao.toString(),
        icon: Icons.hourglass_top_outlined,
        variant: MetricVariant.warning,
      ),
      MetricCard(
        title: 'Canceladas / Inativas',
        value: metricas.totalCanceladasOuInativas.toString(),
        icon: Icons.cancel_outlined,
        variant: MetricVariant.neutral,
      ),
    ];

    if (isMobile) {
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
        final colunas = constraints.maxWidth > 1100 ? 5 : (constraints.maxWidth > 700 ? 3 : 2);
        final larguraCard = (constraints.maxWidth - ((colunas - 1) * AppSpacing.s16)) / colunas;

        return Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: cards.map((c) => SizedBox(width: larguraCard, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildListaVoluntariosMobile(List<VoluntarioRelatorioItem> voluntarios) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: voluntarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, i) {
        final v = voluntarios[i];
        return SectionCard(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  Text(
                    v.nomeCompleto,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  StatusChip(status: v.estadoFicha),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              CpfText(
                cpf: v.cpfMascarado,
                incluirRotuloVisual: true,
                destaqueMonospaced: true,
                style: AppTypography.caption,
              ),
              Text('Igreja: ${v.igrejaNome ?? v.igrejaId}', style: AppTypography.caption),
              if (v.equipes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s4,
                  runSpacing: AppSpacing.s4,
                  children: v.equipes.map((eq) {
                    final nome = eq['equipeNome'] ?? eq['equipeId'] ?? '';
                    final st = eq['estado'] ?? '';
                    return Chip(
                      label: Text('$nome ($st)', style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFF0F4F8),
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabelaVoluntariosDesktop(List<VoluntarioRelatorioItem> voluntarios) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          columns: const [
            DataColumn(label: Text('Nome do Voluntário', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('CPF Mascarado', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Igreja', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Situação Ficha', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Equipes', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: voluntarios.map((v) {
            final equipesStr = v.equipes
                .map((eq) => '${eq['equipeNome'] ?? eq['equipeId']} (${eq['estado']})')
                .join(', ');

            return DataRow(
              cells: [
                DataCell(Text(v.nomeCompleto, style: AppTypography.body)),
                DataCell(CpfText(
                  cpf: v.cpfMascarado,
                  destaqueMonospaced: true,
                  style: AppTypography.caption,
                )),
                DataCell(Text(v.igrejaNome ?? v.igrejaId, style: AppTypography.caption)),
                DataCell(StatusChip(status: v.estadoFicha)),
                DataCell(Text(equipesStr.isEmpty ? '—' : equipesStr, style: AppTypography.caption)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCorpoRelatorio(bool isMobile) {
    if (_carregandoRelatorio && _relatorio == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            LoadingSkeleton(height: 60),
            SizedBox(height: AppSpacing.s12),
            LoadingSkeleton(height: 140),
          ],
        ),
      );
    }

    if (_erroRelatorio != null && _relatorio == null) {
      return ErrorState(
        title: 'Falha ao gerar relatório operacional',
        message: _erroRelatorio!,
        onRetry: () => _carregarRelatorio(),
      );
    }

    final rel = _relatorio!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricasRelatorio(rel.metricas, isMobile),
        const SizedBox(height: AppSpacing.s24),
        Text('Voluntários sob Escopo Autorizado', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.s12),
        if (rel.voluntarios.isEmpty)
          const EmptyState(
            title: 'Nenhum voluntário encontrado para o escopo',
            message: 'Não há registros de voluntários associados ao seu escopo vigente.',
          )
        else
          isMobile
              ? _buildListaVoluntariosMobile(rel.voluntarios)
              : _buildTabelaVoluntariosDesktop(rel.voluntarios),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(
              isMobile ? AppSpacing.pagePaddingMobile : AppSpacing.pagePaddingDesktop,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'Auditoria & Relatórios',
                  subtitle:
                      'Rastreabilidade probatória imutável e consolidação operacional (AD-8, AD-9, AD-12).',
                  actions: [
                    SecondaryButton(
                      label: 'Atualizar',
                      icon: Icons.refresh,
                      onPressed: () {
                        if (_abaSelecionada == 0) {
                          _carregarAuditoria();
                        } else {
                          _carregarRelatorio();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                _buildSeletorAbas(),
                const SizedBox(height: AppSpacing.s20),
                _abaSelecionada == 0 ? _buildCorpoAuditoria(isMobile) : _buildCorpoRelatorio(isMobile),
              ],
            ),
          ),
        );
      },
    );
  }
}

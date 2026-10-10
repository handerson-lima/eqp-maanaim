import 'package:flutter/material.dart';

import '../../ui/identidade.dart';
import 'auditoria_service.dart';

/// Superfície de Auditoria e Relatórios autorizados com mobile-first e acessibilidade WCAG 2.2 AA (AD-8, AD-9, AD-12, UI-CONTRACTS §3).
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
  String? _proximoCursorAuditoria;
  bool _temMaisAuditoria = false;

  // Filtros de Auditoria
  final TextEditingController _acaoController = TextEditingController();
  final TextEditingController _atorController = TextEditingController();
  final TextEditingController _entidadeTipoController = TextEditingController();
  final TextEditingController _entidadeIdController = TextEditingController();
  final TextEditingController _voluntarioController = TextEditingController();
  final TextEditingController _periodoInicioController = TextEditingController();
  final TextEditingController _periodoFimController = TextEditingController();
  bool _mostrarFiltrosAvancadosAuditoria = false;

  // Estado de Relatório
  bool _carregandoRelatorio = false;
  String? _erroRelatorio;
  ResultadoRelatorioOperacional? _relatorio;
  List<VoluntarioRelatorioItem> _voluntariosRelatorio = [];
  String? _proximoCursorRelatorio;
  bool _temMaisRelatorio = false;

  // Filtros de Relatório
  final TextEditingController _relIgrejaController = TextEditingController();
  final TextEditingController _relEquipeController = TextEditingController();
  final TextEditingController _relEstadoController = TextEditingController();
  final TextEditingController _relAnoController = TextEditingController();
  final TextEditingController _relPastorController = TextEditingController();
  final TextEditingController _relVoluntarioController = TextEditingController();
  bool _mostrarFiltrosRelatorio = false;

  @override
  void initState() {
    super.initState();
    _carregarAuditoria();
    _carregarRelatorio();
  }

  @override
  void dispose() {
    _acaoController.dispose();
    _atorController.dispose();
    _entidadeTipoController.dispose();
    _entidadeIdController.dispose();
    _voluntarioController.dispose();
    _periodoInicioController.dispose();
    _periodoFimController.dispose();

    _relIgrejaController.dispose();
    _relEquipeController.dispose();
    _relEstadoController.dispose();
    _relAnoController.dispose();
    _relPastorController.dispose();
    _relVoluntarioController.dispose();
    super.dispose();
  }

  bool get _temFiltrosAuditoriaAtivos =>
      _acaoController.text.trim().isNotEmpty ||
      _atorController.text.trim().isNotEmpty ||
      _entidadeTipoController.text.trim().isNotEmpty ||
      _entidadeIdController.text.trim().isNotEmpty ||
      _voluntarioController.text.trim().isNotEmpty ||
      _periodoInicioController.text.trim().isNotEmpty ||
      _periodoFimController.text.trim().isNotEmpty;

  bool get _temFiltrosRelatorioAtivos =>
      _relIgrejaController.text.trim().isNotEmpty ||
      _relEquipeController.text.trim().isNotEmpty ||
      _relEstadoController.text.trim().isNotEmpty ||
      _relAnoController.text.trim().isNotEmpty ||
      _relPastorController.text.trim().isNotEmpty ||
      _relVoluntarioController.text.trim().isNotEmpty;

  Future<void> _carregarAuditoria({bool carregarMais = false}) async {
    setState(() {
      _carregandoAuditoria = true;
      if (!carregarMais) {
        _erroAuditoria = null;
        _proximoCursorAuditoria = null;
      }
    });

    try {
      final res = await widget.gateway.consultarAuditoria(
        FiltrosAuditoria(
          acao: _acaoController.text.trim().isNotEmpty ? _acaoController.text.trim() : null,
          atorUid: _atorController.text.trim().isNotEmpty ? _atorController.text.trim() : null,
          entidadeTipo: _entidadeTipoController.text.trim().isNotEmpty
              ? _entidadeTipoController.text.trim()
              : null,
          entidadeId: _entidadeIdController.text.trim().isNotEmpty
              ? _entidadeIdController.text.trim()
              : null,
          voluntarioId: _voluntarioController.text.trim().isNotEmpty
              ? _voluntarioController.text.trim()
              : null,
          periodoInicio: _periodoInicioController.text.trim().isNotEmpty
              ? _periodoInicioController.text.trim()
              : null,
          periodoFim: _periodoFimController.text.trim().isNotEmpty
              ? _periodoFimController.text.trim()
              : null,
          limite: 20,
          cursor: carregarMais ? _proximoCursorAuditoria : null,
        ),
      );

      if (!mounted) return;
      setState(() {
        if (carregarMais) {
          _itensAuditoria.addAll(res.itens);
        } else {
          _itensAuditoria = res.itens;
        }
        _proximoCursorAuditoria = res.proximoCursor;
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

  void _limparFiltrosAuditoria() {
    _acaoController.clear();
    _atorController.clear();
    _entidadeTipoController.clear();
    _entidadeIdController.clear();
    _voluntarioController.clear();
    _periodoInicioController.clear();
    _periodoFimController.clear();
    _carregarAuditoria();
  }

  Future<void> _carregarRelatorio({bool carregarMais = false}) async {
    setState(() {
      _carregandoRelatorio = true;
      if (!carregarMais) {
        _erroRelatorio = null;
        _proximoCursorRelatorio = null;
      }
    });

    try {
      final parsedAno = int.tryParse(_relAnoController.text.trim());
      final res = await widget.gateway.consultarRelatorio(
        FiltrosRelatorio(
          igrejaId: _relIgrejaController.text.trim().isNotEmpty
              ? _relIgrejaController.text.trim()
              : null,
          equipeId: _relEquipeController.text.trim().isNotEmpty
              ? _relEquipeController.text.trim()
              : null,
          estado: _relEstadoController.text.trim().isNotEmpty
              ? _relEstadoController.text.trim()
              : null,
          ano: parsedAno,
          pastorId: _relPastorController.text.trim().isNotEmpty
              ? _relPastorController.text.trim()
              : null,
          voluntarioId: _relVoluntarioController.text.trim().isNotEmpty
              ? _relVoluntarioController.text.trim()
              : null,
          limite: 20,
          cursor: carregarMais ? _proximoCursorRelatorio : null,
        ),
      );

      if (!mounted) return;
      setState(() {
        _relatorio = res;
        if (carregarMais) {
          _voluntariosRelatorio.addAll(res.voluntarios);
        } else {
          _voluntariosRelatorio = res.voluntarios;
        }
        _proximoCursorRelatorio = res.proximoCursor;
        _temMaisRelatorio = res.temMais;
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

  void _limparFiltrosRelatorio() {
    _relIgrejaController.clear();
    _relEquipeController.clear();
    _relEstadoController.clear();
    _relAnoController.clear();
    _relPastorController.clear();
    _relVoluntarioController.clear();
    _carregarRelatorio();
  }

  void _mostrarDetalhesAuditoria(ItemAuditoria item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final dataFormatada = item.timestamp.length > 19
            ? item.timestamp.substring(0, 19).replaceAll('T', ' ')
            : item.timestamp;

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.navy900),
              SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text('Detalhe Probatório de Auditoria', style: AppTypography.h3),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(status: item.acao),
                      Text('Data/Hora: $dataFormatada (UTC)', style: AppTypography.caption),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text('Comando ID: ${item.commandId}', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  Text('Correlation ID: ${item.correlationId}', style: AppTypography.caption),
                  Text('Ator UID: ${item.atorUid}', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.s12),
                  const Text('Entidades Referenciadas:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: AppSpacing.s4),
                  if (item.entidades.isEmpty)
                    const Text('Nenhuma entidade declarada.', style: AppTypography.caption)
                  else
                    Wrap(
                      spacing: AppSpacing.s4,
                      runSpacing: AppSpacing.s4,
                      children: item.entidades.map((e) {
                        return Chip(
                          label: Text('${e['tipo']}: ${e['id']}', style: const TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFFF0F4F8),
                        );
                      }).toList(),
                    ),
                  if (item.antes != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    const Text('Estado Anterior (Sanitizado):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: AppSpacing.s4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(4)),
                      child: Text(item.antes.toString(), style: AppTypography.caption),
                    ),
                  ],
                  if (item.depois != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    const Text('Estado Posterior (Sanitizado):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: AppSpacing.s4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(4)),
                      child: Text(item.depois.toString(), style: AppTypography.caption),
                    ),
                  ],
                  if (item.metadados != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    const Text('Metadados:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: AppSpacing.s4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(4)),
                      child: Text(item.metadados.toString(), style: AppTypography.caption),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            PrimaryButton(
              label: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
                  onSubmitted: (_) => _carregarAuditoria(),
                ),
              ),
              PrimaryButton(
                label: 'Filtrar',
                icon: Icons.filter_list,
                onPressed: () => _carregarAuditoria(),
              ),
              SecondaryButton(
                label: _mostrarFiltrosAvancadosAuditoria ? 'Ocultar Filtros' : 'Filtros Avançados',
                icon: _mostrarFiltrosAvancadosAuditoria ? Icons.expand_less : Icons.tune,
                onPressed: () {
                  setState(() {
                    _mostrarFiltrosAvancadosAuditoria = !_mostrarFiltrosAvancadosAuditoria;
                  });
                },
              ),
              if (_temFiltrosAuditoriaAtivos)
                SecondaryButton(
                  label: 'Limpar Filtros',
                  icon: Icons.clear,
                  onPressed: _limparFiltrosAuditoria,
                ),
            ],
          ),
          if (_mostrarFiltrosAvancadosAuditoria) ...[
            const SizedBox(height: AppSpacing.s16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s16),
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _atorController,
                    decoration: const InputDecoration(
                      labelText: 'Ator (UID)',
                      hintText: 'UID do responsável',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarAuditoria(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _entidadeTipoController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Entidade',
                      hintText: 'Ex.: IGREJA, EQUIPE',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarAuditoria(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _entidadeIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID da Entidade',
                      hintText: 'ID do alvo',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarAuditoria(),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _voluntarioController,
                    decoration: const InputDecoration(
                      labelText: 'Voluntário-Alvo (ID)',
                      hintText: 'ID da entidade VOLUNTARIO',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarAuditoria(),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _periodoInicioController,
                    decoration: const InputDecoration(
                      labelText: 'Início (ISO)',
                      hintText: 'AAAA-MM-DD',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarAuditoria(),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _periodoFimController,
                    decoration: const InputDecoration(
                      labelText: 'Fim (ISO)',
                      hintText: 'AAAA-MM-DD',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarAuditoria(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltrosRelatorio() {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filtros do Relatório', style: AppTypography.h3),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarFiltrosRelatorio = !_mostrarFiltrosRelatorio;
                  });
                },
                icon: Icon(_mostrarFiltrosRelatorio ? Icons.expand_less : Icons.tune),
                label: Text(_mostrarFiltrosRelatorio ? 'Recolher' : 'Expandir Filtros'),
              ),
            ],
          ),
          if (_mostrarFiltrosRelatorio) ...[
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s12,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _relIgrejaController,
                    decoration: const InputDecoration(
                      labelText: 'Igreja ID',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarRelatorio(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _relEquipeController,
                    decoration: const InputDecoration(
                      labelText: 'Equipe ID',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarRelatorio(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _relEstadoController,
                    decoration: const InputDecoration(
                      labelText: 'Situação Ficha',
                      hintText: 'Ex.: ATIVA',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarRelatorio(),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _relAnoController,
                    decoration: const InputDecoration(
                      labelText: 'Ano Vigência',
                      hintText: 'Ex.: 2026',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _carregarRelatorio(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _relPastorController,
                    decoration: const InputDecoration(
                      labelText: 'Pastor ID',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarRelatorio(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _relVoluntarioController,
                    decoration: const InputDecoration(
                      labelText: 'Voluntário ID',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _carregarRelatorio(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s12,
              children: [
                PrimaryButton(
                  label: 'Aplicar Filtros',
                  icon: Icons.filter_list,
                  onPressed: () => _carregarRelatorio(),
                ),
                if (_temFiltrosRelatorioAtivos)
                  SecondaryButton(
                    label: 'Limpar Filtros',
                    icon: Icons.clear,
                    onPressed: _limparFiltrosRelatorio,
                  ),
              ],
            ),
          ],
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
        final dataFormatada = item.timestamp.length > 19
            ? item.timestamp.substring(0, 19).replaceAll('T', ' ')
            : item.timestamp;

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
                  Text(dataFormatada, style: AppTypography.caption),
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
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Ver Detalhes',
                icon: Icons.visibility_outlined,
                onPressed: () => _mostrarDetalhesAuditoria(item),
              ),
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
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.w600))),
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
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20, color: AppColors.blue600),
                    tooltip: 'Ver detalhes probatórios',
                    onPressed: () => _mostrarDetalhesAuditoria(item),
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
        title: 'Fichas canceladas, inativas ou expiradas',
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
    final voluntarios = _voluntariosRelatorio.isNotEmpty ? _voluntariosRelatorio : rel.voluntarios;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFiltrosRelatorio(),
        const SizedBox(height: AppSpacing.s16),
        _buildMetricasRelatorio(rel.metricas, isMobile),
        const SizedBox(height: AppSpacing.s24),
        Text('Voluntários sob Escopo Autorizado', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.s12),
        if (voluntarios.isEmpty)
          const EmptyState(
            title: 'Nenhum voluntário encontrado para o escopo',
            message: 'Não há registros de voluntários associados ao seu escopo vigente com os filtros aplicados.',
          )
        else ...[
          isMobile
              ? _buildListaVoluntariosMobile(voluntarios)
              : _buildTabelaVoluntariosDesktop(voluntarios),
          const SizedBox(height: AppSpacing.s16),
          if (_temMaisRelatorio)
            Center(
              child: _carregandoRelatorio
                  ? const CircularProgressIndicator()
                  : PrimaryButton(
                      label: 'Carregar mais voluntários',
                      icon: Icons.expand_more,
                      onPressed: () => _carregarRelatorio(carregarMais: true),
                    ),
            ),
        ],
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

import 'package:flutter/material.dart';

import '../../ui/identidade.dart';
import 'auditoria_presentation_helper.dart';
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
                  Text(
                    AuditoriaPresentationHelper.obterTituloAcao(item.acao),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.s8),
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

  Widget _buildChipCategoriaFiltro({required String label, required String? prefixoAcao}) {
    final selecionado = (prefixoAcao == null && _acaoController.text.trim().isEmpty) ||
        (prefixoAcao != null && _acaoController.text.trim().toUpperCase().contains(prefixoAcao));

    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (_) {
        setState(() {
          if (prefixoAcao == null) {
            _acaoController.clear();
          } else {
            _acaoController.text = prefixoAcao;
          }
        });
        _carregarAuditoria();
      },
      selectedColor: const Color(0xFFE0F2FE),
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 12,
        fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
        color: selecionado ? AppColors.blue600 : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildFiltrosAuditoria() {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipCategoriaFiltro(label: 'Todas as Ações', prefixoAcao: null),
                const SizedBox(width: AppSpacing.s8),
                _buildChipCategoriaFiltro(label: 'Consultas & Acessos', prefixoAcao: 'CONSULTA'),
                const SizedBox(width: AppSpacing.s8),
                _buildChipCategoriaFiltro(label: 'Avaliações & Decisões', prefixoAcao: 'DECIS'),
                const SizedBox(width: AppSpacing.s8),
                _buildChipCategoriaFiltro(label: 'Termos & Governança', prefixoAcao: 'TERMO'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
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
        final tituloAmigavel = AuditoriaPresentationHelper.obterTituloAcao(item.acao);
        final categoria = AuditoriaPresentationHelper.obterCategoria(item.acao);
        final configCat = AuditoriaPresentationHelper.obterConfigCategoria(categoria);
        final dataAmigavel = AuditoriaPresentationHelper.formatarDataHoraAmigavel(item.timestamp);
        final atorLegivel = AuditoriaPresentationHelper.obterRotuloAtor(item.atorUid);

        return SectionCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: Categoria Badge + Data Amigável
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: configCat.corFundo,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: configCat.corTexto.withAlpha(50),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(configCat.icone, size: 14, color: configCat.corTexto),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          configCat.rotulo,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: configCat.corTexto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dataAmigavel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),

              // Linha 2: TÍTULO HUMANO DA AÇÃO (Destaque Principal)
              Text(
                tituloAmigavel,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),

              // Linha 3: Quem realizou (Ator com contexto humanizado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 16, color: AppColors.navy900),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Ator: ${item.atorUid}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      atorLegivel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Linha 4: Entidades afetadas (se houver)
              if (item.entidades.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s4,
                  children: item.entidades.map((e) {
                    final tipo = e['tipo'] ?? '';
                    final id = e['id'] ?? '';
                    final icone = AuditoriaPresentationHelper.obterIconeEntidade(tipo);
                    final labelFormatado = AuditoriaPresentationHelper.formatarEntidade(tipo, id);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icone, size: 13, color: AppColors.blue600),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            labelFormatado,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: AppSpacing.s8),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),

              // Linha 5: Rodapé com metadados técnicos discretos + Botão Ver Detalhes
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Identificador único imutável do comando',
                      child: Text(
                        'Comando: ${item.commandId}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  SecondaryButton(
                    label: 'Ver Detalhes',
                    icon: Icons.visibility_outlined,
                    onPressed: () => _mostrarDetalhesAuditoria(item),
                  ),
                ],
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
            DataColumn(label: Text('Data / Hora', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Ação / Evento', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Ator Responsável', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Command ID', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Entidades Referenciadas', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: itens.map((item) {
            final dataFormatada = AuditoriaPresentationHelper.formatarDataHoraAmigavel(item.timestamp);
            final tituloAcao = AuditoriaPresentationHelper.obterTituloAcao(item.acao);
            final atorLegivel = AuditoriaPresentationHelper.obterRotuloAtor(item.atorUid);
            final entidadesFormatadas = item.entidades
                .map((e) => AuditoriaPresentationHelper.formatarEntidade(e['tipo'] ?? '', e['id'] ?? ''))
                .join(', ');

            return DataRow(
              cells: [
                DataCell(Text(dataFormatada, style: AppTypography.caption)),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tituloAcao, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      StatusChip(status: item.acao),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.atorUid, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                      Text(atorLegivel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                DataCell(Text(item.commandId, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
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
                      'Rastreabilidade probatória imutável e consolidação operacional.',
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

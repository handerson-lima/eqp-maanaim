import 'dart:math';
import 'package:flutter/material.dart';
import '../../ui/tokens.dart';
import '../../ui/components/cpf_formatter.dart';
import '../../ui/components/metrics.dart';
import '../analise/detalhe_solicitacao_model.dart';
import '../analise/detalhe_solicitacao_screen.dart';
import '../analise/detalhe_solicitacao_service.dart';
import '../renovacao/dashboard_renovacao_service.dart';
import 'coordenador_service.dart';

class FilaCoordenadorScreen extends StatefulWidget {
  const FilaCoordenadorScreen({
    super.key,
    required this.gateway,
    this.detalheGateway,
    this.dashboardRenovacaoGateway,
    this.onSair,
    this.dentroDeShell = false,
  });

  final CoordenadorGateway gateway;
  final DetalheSolicitacaoGateway? detalheGateway;
  final DashboardRenovacaoGateway? dashboardRenovacaoGateway;
  final VoidCallback? onSair;
  final bool dentroDeShell;

  @override
  State<FilaCoordenadorScreen> createState() => _FilaCoordenadorScreenState();
}

class _ParecerParticipacao {
  const _ParecerParticipacao(this.texto, this.icone, this.cor, this.fundo);
  final String texto;
  final IconData icone;
  final Color cor;
  final Color fundo;
}

class _FilaCoordenadorScreenState extends State<FilaCoordenadorScreen> {
  bool _carregando = true;
  String? _erro;
  List<ItemFilaCoordenador> _pendencias = [];
  String? _processandoFichaId;
  final List<TextEditingController> _controllersModal = [];
  int? _anoFiltro; // null = todos os anos
  String? _filtroKpi; // null = todas; 'RENOVACOES' = apenas renovações
  int? _metricasAtivos;
  int? _metricasExpirados;

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  @override
  void dispose() {
    for (final controller in _controllersModal) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarFila() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final pendencias = await widget.gateway.obterFila();

      if (widget.dashboardRenovacaoGateway != null) {
        try {
          final resDashboard = await widget.dashboardRenovacaoGateway!.obterDashboardRenovacao(
            papelDesejado: PapelDashboard.coordenador,
            anoVigencia: _anoFiltro,
          );
          if (resDashboard.metricasCoordenador != null) {
            _metricasAtivos = resDashboard.metricasCoordenador!.totalAtivos;
            _metricasExpirados = resDashboard.metricasCoordenador!.expirados;
          }
        } catch (_) {
          // Fallback gracioso
        }
      }

      if (!mounted) return;
      setState(() {
        _pendencias = pendencias;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar a fila do coordenador.';
        _carregando = false;
      });
    }
  }

  List<ItemFilaCoordenador> get _pendenciasNoEscopoAno {
    if (_anoFiltro == null) {
      return _pendencias;
    }
    return _pendencias.where((p) {
      if (p.isRenovacaoAnual && p.anoVigencia != null) {
        return p.anoVigencia == _anoFiltro;
      }
      if (p.enviadoEm.isNotEmpty) {
        final dt = DateTime.tryParse(p.enviadoEm);
        if (dt != null) {
          return dt.year == _anoFiltro;
        }
      }
      return false;
    }).toList();
  }

  List<ItemFilaCoordenador> get _pendenciasFiltradas {
    final base = _pendenciasNoEscopoAno;
    if (_filtroKpi == 'RENOVACOES') {
      return base.where((p) => p.isRenovacaoAnual).toList();
    }
    return base;
  }

  int get _countAguardando => _pendenciasNoEscopoAno.length;
  int get _countRenovacoes => _pendenciasNoEscopoAno.where((p) => p.isRenovacaoAnual).length;

  List<int> get _anosDisponiveis {
    final anos = <int>{DateTime.now().year, 2026};
    for (final p in _pendencias) {
      if (p.anoVigencia != null) {
        anos.add(p.anoVigencia!);
      } else if (p.enviadoEm.isNotEmpty) {
        final dt = DateTime.tryParse(p.enviadoEm);
        if (dt != null) anos.add(dt.year);
      }
    }
    final lista = anos.toList()..sort((a, b) => b.compareTo(a));
    return lista;
  }

  String _obterProporcaoEquipes(ItemFilaCoordenador item) {
    if (item.participacoes.isEmpty) return 'Proporção indisponível';
    final totalSolicitadas = item.participacoes.length;
    final totalAprovadas = item.participacoes.where((p) => p.elegivelAtivacao).length;
    return '$totalAprovadas/$totalSolicitadas equipes aprovadas';
  }

  String _gerarCommandId(String prefixo) {
    final rand = Random().nextInt(99999999).toString().padLeft(8, '0');
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'cmd_coord_${prefixo}_${ts}_$rand';
  }

  String _formatarData(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final data = DateTime.tryParse(iso);
    if (data == null) return '';
    final local = data.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }

  _ParecerParticipacao _parecerDe(ParticipacaoItemCoordenador part) {
    switch (part.estado) {
      case 'AGUARDANDO_COORDENADOR':
      case 'ATIVA':
        final data = _formatarData(part.responsavelDecididoEm);
        final rotulo = part.responsavelNome != null
            ? 'Aprovada por ${part.responsavelNome}'
            : 'Aprovada pela Equipe';
        return _ParecerParticipacao(
          data.isNotEmpty ? '$rotulo · $data' : rotulo,
          Icons.how_to_reg,
          AppColors.blue600,
          AppColors.blue50,
        );
      case 'REJEITADA':
        return const _ParecerParticipacao(
          'Recusada',
          Icons.cancel_outlined,
          AppColors.danger,
          AppColors.surface,
        );
      default:
        return const _ParecerParticipacao(
          'Aguardando etapa anterior',
          Icons.hourglass_empty,
          AppColors.warning,
          AppColors.warningBg,
        );
    }
  }

  Future<void> _abrirModalAprovacao(ItemFilaCoordenador item) async {
    final observacaoController = TextEditingController();
    _controllersModal.add(observacaoController);
    bool confirmouReuniao = false;

    final confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppGeometry.cardBorderRadius,
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Text(
                'Homologar e Ativar Voluntariado',
                style: TextStyle(
                  color: AppColors.navy900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voluntário: ${item.voluntarioNome}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Igreja: ${item.nomeIgreja}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Equipes a ativar no ciclo de 1 ano:',
                        style: TextStyle(
                          color: AppColors.navy900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.participacoesElegiveis.map((p) {
                          return Chip(
                            label: Text(p.nomeEquipe),
                            backgroundColor: AppColors.blue50,
                            labelStyle: const TextStyle(
                              color: AppColors.blue600,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: AppColors.blue50,
                          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                          border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              key: const Key('chkConfirmarReuniao'),
                              value: confirmouReuniao,
                              activeColor: AppColors.blue600,
                              onChanged: (val) {
                                setDialogState(() {
                                  confirmouReuniao = val ?? false;
                                });
                              },
                            ),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Confirmo a verificação e deliberação favorável na Reunião de Pastores.',
                                  style: TextStyle(
                                    color: AppColors.navy900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('campoObservacaoAprovacao'),
                        controller: observacaoController,
                        maxLines: 2,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Observação interna (opcional)',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: AppGeometry.inputBorderRadius,
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppGeometry.inputBorderRadius,
                            borderSide: const BorderSide(color: AppColors.blue600, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  key: const Key('btnConfirmarAtivacaoModal'),
                  onPressed: confirmouReuniao ? () => Navigator.of(ctx).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    minimumSize: const Size(120, AppGeometry.minTouchTarget),
                  ),
                  child: const Text('Confirmar Ativação'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmou != true) return;

    await _executarDecisao(
      item: item,
      commandId: _gerarCommandId('apr'),
      fichaId: item.fichaId,
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      observacao: observacaoController.text.trim().isNotEmpty
          ? observacaoController.text.trim()
          : null,
      expectedVersion: item.versaoFicha,
    );
  }

  Future<void> _abrirModalRecusa(ItemFilaCoordenador item) async {
    final justificativaController = TextEditingController();
    _controllersModal.add(justificativaController);
    String? erroJustificativa;

    final confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppGeometry.cardBorderRadius,
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Text(
                'Decisão Desfavorável',
                style: TextStyle(
                  color: AppColors.navy900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voluntário: ${item.voluntarioNome}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'A justificativa interna será gravada como evidência restrita da decisão (não vai para a auditoria geral). Ao voluntário será exibido exclusivamente: "Procure o Pastor da igreja local para mais informações".',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('campoJustificativaRecusa'),
                        controller: justificativaController,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Justificativa interna obrigatória *',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          errorText: erroJustificativa,
                          border: OutlineInputBorder(
                            borderRadius: AppGeometry.inputBorderRadius,
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppGeometry.inputBorderRadius,
                            borderSide: const BorderSide(color: AppColors.danger, width: 2),
                          ),
                        ),
                        onChanged: (texto) {
                          if (erroJustificativa != null && texto.trim().length >= 5) {
                            setDialogState(() => erroJustificativa = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  key: const Key('btnConfirmarRecusaModal'),
                  onPressed: () {
                    final texto = justificativaController.text.trim();
                    if (texto.length < 5) {
                      setDialogState(() {
                        erroJustificativa = 'Mínimo de 5 caracteres obrigatório.';
                      });
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, AppGeometry.minTouchTarget),
                  ),
                  child: const Text('Confirmar Recusa'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmou != true) return;

    await _executarDecisao(
      item: item,
      commandId: _gerarCommandId('rec'),
      fichaId: item.fichaId,
      decisao: 'DESFAVORAVEL',
      confirmouReuniaoPastores: false,
      observacao: justificativaController.text.trim(),
      expectedVersion: item.versaoFicha,
    );
  }

  Future<void> _executarDecisao({
    required ItemFilaCoordenador item,
    required String commandId,
    required String fichaId,
    required String decisao,
    required bool confirmouReuniaoPastores,
    String? observacao,
    required int expectedVersion,
  }) async {
    setState(() => _processandoFichaId = fichaId);

    try {
      if (item.isRenovacaoAnual && item.cicloId != null) {
        final resultado = await widget.gateway.concluirCicloAnual(
          commandId: commandId,
          cicloId: item.cicloId!,
          decisao: decisao,
          confirmouReuniaoPastores: confirmouReuniaoPastores,
          observacao: observacao,
          expectedVersion: expectedVersion,
        );

        if (!mounted) return;

        final msg = resultado.decisao == 'APROVADO'
            ? 'Renovação anual concluída com sucesso!'
            : 'Decisão desfavorável da renovação anual registrada.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: resultado.decisao == 'APROVADO'
                ? AppColors.success
                : AppColors.navy900,
          ),
        );
      } else {
        final resultado = await widget.gateway.decidir(
          commandId: commandId,
          fichaId: fichaId,
          decisao: decisao,
          confirmouReuniaoPastores: confirmouReuniaoPastores,
          observacao: observacao,
          expectedVersion: expectedVersion,
        );

        if (!mounted) return;

        final msg = resultado.decisao == 'APROVADO'
            ? 'Voluntariado ativado com sucesso!'
            : 'Decisão desfavorável registrada com sucesso.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: resultado.decisao == 'APROVADO'
                ? AppColors.success
                : AppColors.navy900,
          ),
        );
      }

      await _carregarFila();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao registrar decisão do coordenador. Tente novamente.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processandoFichaId = null);
      }
    }
  }

  Widget _badgeAguardando() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.blue50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Aguardando Coordenação',
          style: TextStyle(
            color: AppColors.blue600,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _badgeRenovacaoAnual(int? ano) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.navy900.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.navy900.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_outlined, size: 12, color: AppColors.navy900),
            const SizedBox(width: 4),
            Text(
              ano != null ? 'Ciclo Anual $ano' : 'Ciclo Anual',
              style: const TextStyle(
                color: AppColors.navy900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Future<void> _abrirDetalheSolicitacao(ItemFilaCoordenador item) async {
    final resultado = await Navigator.of(context).push<ResultadoDecisaoContextual>(
      MaterialPageRoute(
        builder: (_) => DetalheSolicitacaoScreen(
          fichaId: item.fichaId,
          nomeVoluntarioInicial: item.voluntarioNome,
          papel: PapelContextualAnalise.coordenadorGeral,
          isRenovacaoAnual: item.isRenovacaoAnual,
          cicloId: item.cicloId,
          versaoInicial: item.versaoFicha,
          gateway: widget.detalheGateway ??
              CompostoDetalheSolicitacaoGateway(coordenadorGateway: widget.gateway),
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

  Widget _acoesDaFicha(ItemFilaCoordenador item, {bool compact = true}) {
    final processando = _processandoFichaId == item.fichaId;
    if (processando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final botoes = <Widget>[
      ElevatedButton.icon(
        key: Key('btnAnalisar_${item.fichaId}'),
        onPressed: () => _abrirDetalheSolicitacao(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy900,
          foregroundColor: Colors.white,
          minimumSize: const Size(100, AppGeometry.minTouchTarget),
        ),
        icon: const Icon(Icons.assignment_outlined, size: 16),
        label: const Text('Analisar'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        key: Key('btnRecusar_${item.fichaId}'),
        onPressed: () => _abrirModalRecusa(item),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          minimumSize: const Size(100, AppGeometry.minTouchTarget),
        ),
        icon: const Icon(Icons.close, size: 16),
        label: const Text('Recusar'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        key: Key('btnAprovar_${item.fichaId}'),
        onPressed: () => _abrirModalAprovacao(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue600,
          foregroundColor: Colors.white,
          minimumSize: const Size(170, AppGeometry.minTouchTarget),
        ),
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Homologar e Ativar'),
      ),
    ];
    if (!compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: botoes);
    }
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: botoes,
    );
  }

  Widget _buildCardPendencia(ItemFilaCoordenador item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppGeometry.cardBorderRadius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.voluntarioNome,
                    style: AppTypography.label.copyWith(
                      color: AppColors.navy900,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (item.isRenovacaoAnual) _badgeRenovacaoAnual(item.anoVigencia),
                    _badgeAguardando(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Igreja: ${item.nomeIgreja}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  'Profissão: ${item.profissao.isNotEmpty ? item.profissao : "Não informada"}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                CpfText(
                  cpf: item.cpfMascarado,
                  incluirRotuloVisual: true,
                  destaqueMonospaced: true,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 12, color: AppColors.blue600),
                      const SizedBox(width: 4),
                      Text(
                        _obterProporcaoEquipes(item),
                        key: Key('proporcaoEquipes_${item.fichaId}'),
                        style: const TextStyle(
                          color: AppColors.blue600,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.pastorLocalNome != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _rotuloPastorLocal(item),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 12, color: AppColors.border),
            const Text(
              'Avaliação das Equipes Solicitadas:',
              style: TextStyle(
                color: AppColors.navy900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Column(
              children: item.participacoes.map((part) {
                final parecer = _parecerDe(part);
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: parecer.fundo,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: parecer.cor == AppColors.danger
                          ? AppColors.border
                          : parecer.cor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(parecer.icone, size: 14, color: parecer.cor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          part.nomeEquipe,
                          style: TextStyle(
                            color: AppColors.navy900,
                            fontSize: 12,
                            fontWeight: part.elegivelAtivacao
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          parecer.texto,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: parecer.cor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _acoesDaFicha(item),
            ),
          ],
        ),
      ),
    );
  }

  String _rotuloPastorLocal(ItemFilaCoordenador item) {
    final data = _formatarData(item.pastorLocalDecididoEm);
    final base = 'Aprovado pelo Pastor Local: ${item.pastorLocalNome}';
    return data.isNotEmpty ? '$base · $data' : base;
  }

  Widget _buildTabelaDesktop() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 960),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.blue50),
          dataRowMinHeight: 64,
          dataRowMaxHeight: 88,
          columns: const [
            DataColumn(label: Text('Voluntário', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Igreja', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('CPF', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data de Envio', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Proporção de Equipes', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Equipes', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _pendenciasFiltradas.map((item) {
            return DataRow(
              key: ValueKey('linhaCoordenador_${item.fichaId}'),
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.voluntarioNome,
                        key: Key('tabelaVoluntario_${item.fichaId}'),
                        style: AppTypography.label.copyWith(color: AppColors.navy900),
                      ),
                      if (item.isRenovacaoAnual)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _badgeRenovacaoAnual(item.anoVigencia),
                        ),
                    ],
                  ),
                ),
                DataCell(Text(item.nomeIgreja, style: AppTypography.caption)),
                DataCell(CpfText(
                  cpf: item.cpfMascarado,
                  destaqueMonospaced: true,
                  style: AppTypography.caption,
                )),
                DataCell(Text(_formatarData(item.enviadoEm), style: AppTypography.caption)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                      border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _obterProporcaoEquipes(item),
                      key: Key('proporcaoEquipes_${item.fichaId}'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.blue600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: AppSpacing.s4,
                    runSpacing: AppSpacing.s4,
                    children: item.participacoes.map((part) {
                      final parecer = _parecerDe(part);
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: parecer.fundo,
                        avatar: Icon(parecer.icone, size: 14, color: parecer.cor),
                        label: Text(
                          '${part.nomeEquipe}: ${parecer.texto}',
                          style: AppTypography.caption.copyWith(color: parecer.cor),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                DataCell(_acoesDaFicha(item, compact: false)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 56,
              color: AppColors.success.withValues(alpha: 0.8),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Nenhuma solicitação pendente!',
              style: AppTypography.h2.copyWith(color: AppColors.navy900),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _filtroKpi != null
                  ? 'Nenhuma solicitação de renovação anual pendente para o coordenador.'
                  : _anoFiltro != null
                      ? 'Nenhuma solicitação pendente para o ano $_anoFiltro.'
                      : 'Não há solicitações com todas as equipes resolvidas aguardando conclusão do Coordenador.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalhoFiltros(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.dentroDeShell)
            Text(
              'Fila de Conclusão do Coordenador',
              style: AppTypography.h3.copyWith(color: AppColors.navy900),
            )
          else
            const SizedBox.shrink(),
          SizedBox(
            width: 170,
            height: 38,
            child: DropdownButtonFormField<int?>(
              key: const Key('dropdownFiltroAno'),
              initialValue: _anoFiltro,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                labelText: 'Ano',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todos os anos', style: TextStyle(fontSize: 12)),
                ),
                ..._anosDisponiveis.map(
                  (ano) => DropdownMenuItem<int?>(
                    value: ano,
                    child: Text('Ano $ano', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _anoFiltro = val);
                if (widget.dashboardRenovacaoGateway != null) {
                  _carregarFila();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis(double maxWidth) {
    final kpiAguardando = MetricCard(
      title: 'Aguardando aprovação',
      value: '$_countAguardando',
      icon: Icons.hourglass_top_outlined,
      variant: MetricVariant.primary,
      badge: _filtroKpi == null && _countAguardando > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Fila', style: TextStyle(fontSize: 10, color: AppColors.blue600, fontWeight: FontWeight.bold)),
            )
          : null,
      onTap: () {
        setState(() {
          _filtroKpi = null;
        });
      },
    );

    final kpiRenovacoes = MetricCard(
      title: 'Renovações',
      value: '$_countRenovacoes',
      icon: Icons.sync_outlined,
      variant: MetricVariant.warning,
      badge: _filtroKpi == 'RENOVACOES'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Filtro ativo', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold)),
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
    );

    final kpiExpirados = MetricCard(
      title: 'Expirados',
      value: _metricasExpirados != null ? '$_metricasExpirados' : '--',
      icon: Icons.event_busy_outlined,
      variant: MetricVariant.danger,
    );

    if (maxWidth >= 600) {
      return Row(
        children: [
          Expanded(child: kpiAguardando),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: kpiRenovacoes),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: kpiAtivos),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: kpiExpirados),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: kpiAguardando),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: kpiRenovacoes),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(child: kpiAtivos),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: kpiExpirados),
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

  Widget _buildConteudo() {
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
                    const SizedBox(height: 4),
                    _buildKpis(constraints.maxWidth),
                    const SizedBox(height: 6),
                    if (_filtroKpi != null) ...[
                      _buildBannerFiltroAtivo(),
                      const SizedBox(height: 6),
                    ],
                    if (_pendenciasFiltradas.isEmpty)
                      _buildVazio()
                    else if (isDesktop)
                      _buildTabelaDesktop()
                    else
                      ..._pendenciasFiltradas.map(_buildCardPendencia),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final corpo = SafeArea(
      child: _carregando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.s12),
                  Text(
                    'Carregando fila do coordenador...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : _erro != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        _erro!,
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      ElevatedButton(
                        onPressed: _carregarFila,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
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
        title: const Text('Fila de Conclusão do Coordenador'),
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _carregarFila,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
          if (widget.onSair != null)
            IconButton(
              onPressed: widget.onSair,
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
            ),
        ],
      ),
      body: corpo,
    );
  }
}

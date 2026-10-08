import 'dart:math';
import 'package:flutter/material.dart';
import '../../ui/tokens.dart';
import '../../ui/components/cpf_formatter.dart';
import 'coordenador_service.dart';

class FilaCoordenadorScreen extends StatefulWidget {
  const FilaCoordenadorScreen({
    super.key,
    required this.gateway,
    this.onSair,
  });

  final CoordenadorGateway gateway;
  final VoidCallback? onSair;

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.blue50,
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.navy900.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
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
      OutlinedButton.icon(
        key: Key('btnRecusar_${item.fichaId}'),
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
        key: Key('btnAprovar_${item.fichaId}'),
        onPressed: () => _abrirModalAprovacao(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue600,
          foregroundColor: Colors.white,
          minimumSize: const Size(180, AppGeometry.minTouchTarget),
        ),
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Homologar e Ativar'),
      ),
    ];
    if (!compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: botoes);
    }
    return OverflowBar(
      spacing: AppSpacing.s12,
      overflowSpacing: AppSpacing.s8,
      alignment: MainAxisAlignment.end,
      children: botoes,
    );
  }

  Widget _buildCardPendencia(ItemFilaCoordenador item, bool isCompact) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppGeometry.cardBorderRadius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          isCompact ? AppSpacing.cardPadding : AppSpacing.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.voluntarioNome,
                    style: AppTypography.h3.copyWith(color: AppColors.navy900),
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
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s4,
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
              ],
            ),
            if (item.pastorLocalNome != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                  const SizedBox(width: AppSpacing.s4),
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
            const Divider(height: AppSpacing.s24, color: AppColors.border),
            Text(
              'Avaliação das Equipes Solicitadas:',
              style: AppTypography.label.copyWith(color: AppColors.navy900),
            ),
            const SizedBox(height: AppSpacing.s8),
            Column(
              children: item.participacoes.map((part) {
                final parecer = _parecerDe(part);
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: parecer.fundo,
                    borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                    border: Border.all(
                      color: parecer.cor == AppColors.danger
                          ? AppColors.border
                          : parecer.cor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(parecer.icone, size: 18, color: parecer.cor),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          part.nomeEquipe,
                          style: AppTypography.label.copyWith(
                            color: AppColors.navy900,
                            fontWeight: part.elegivelAtivacao
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          parecer.texto,
                          textAlign: TextAlign.end,
                          style: AppTypography.caption.copyWith(
                            color: parecer.cor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s16),
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
      padding: const EdgeInsets.all(AppSpacing.pagePaddingDesktop),
      child: Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.cardBorderRadius,
          side: const BorderSide(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.blue50),
            columns: const [
              DataColumn(label: Text('Voluntário')),
              DataColumn(label: Text('Igreja')),
              DataColumn(label: Text('CPF')),
              DataColumn(label: Text('Pastor Local')),
              DataColumn(label: Text('Equipes')),
              DataColumn(label: Text('Ações')),
            ],
            rows: _pendencias.map((item) {
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
                  DataCell(Text(_rotuloPastorLocal(item), style: AppTypography.caption)),
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
              'Não há solicitações com todas as equipes resolvidas aguardando conclusão do Coordenador.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final isDesktop = largura >= 1024;
    final isCompact = largura < 600;

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
      body: SafeArea(
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
                : _pendencias.isEmpty
                    ? _buildVazio()
                    : isDesktop
                        ? _buildTabelaDesktop()
                        : ListView.builder(
                            padding: EdgeInsets.all(
                              isCompact
                                  ? AppSpacing.pagePaddingMobile
                                  : AppSpacing.pagePaddingDesktop,
                            ),
                            itemCount: _pendencias.length,
                            itemBuilder: (ctx, idx) => _buildCardPendencia(
                              _pendencias[idx],
                              isCompact,
                            ),
                          ),
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import '../../ui/tokens.dart';
import 'responsavel_equipe_service.dart';

class FilaResponsavelEquipeScreen extends StatefulWidget {
  const FilaResponsavelEquipeScreen({
    super.key,
    required this.gateway,
    this.onSair,
  });

  final ResponsavelEquipeGateway gateway;
  final VoidCallback? onSair;

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

  List<ItemFilaResponsavelEquipe> get _pendenciasFiltradas {
    if (_equipeFiltroId == null || _equipeFiltroId!.isEmpty) {
      return _pendencias;
    }
    return _pendencias.where((p) => p.equipeId == _equipeFiltroId).toList();
  }

  String _gerarCommandId() {
    final rand = Random().nextInt(99999999).toString().padLeft(8, '0');
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'cmd_resp_${ts}_$rand';
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
    setState(() {
      _acaoEmProgressoId = item.participacaoId;
    });

    final commandId = _gerarCommandId();

    try {
      final entrada = EntradaDecidirParticipacaoResponsavel(
        commandId: commandId,
        participacaoId: item.participacaoId,
        cicloId: item.cicloId,
        decisao: decisao,
        justificativa: justificativa,
        expectedVersion: item.versao,
      );

      final res = item.isRenovacaoAnual
          ? await widget.gateway.decidirCicloAnual(entrada)
          : await widget.gateway.decidirParticipacao(entrada);

      if (!mounted) return;

      setState(() {
        _pendencias.removeWhere((p) => p.participacaoId == item.participacaoId);
        _acaoEmProgressoId = null;
      });

      final msg = res.decisao == 'APROVADO'
          ? 'Participação na equipe ${item.nomeEquipe} aprovada com sucesso!'
          : 'Participação recusada. Mensagem padrão enviada ao voluntário.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              res.decisao == 'APROVADO' ? AppColors.success : AppColors.navy900,
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ERROR: $e');
      if (!mounted) return;
      setState(() {
        _acaoEmProgressoId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao processar decisão: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      _carregarFila();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

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
      body: SafeArea(
        child: _buildConteudo(isDesktop),
      ),
    );
  }

  Widget _buildConteudo(bool isDesktop) {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('progressoCarregamentoFilaEquipe'),
        ),
      );
    }

    if (_erro != null) {
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

    final filtradas = _pendenciasFiltradas;

    return RefreshIndicator(
      onRefresh: _carregarFila,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? AppSpacing.s32 : AppSpacing.cardPadding,
          vertical: AppSpacing.s16,
        ),
        children: [
          _buildCabecalhoFiltros(isDesktop),
          const SizedBox(height: AppSpacing.s16),
          if (filtradas.isEmpty)
            _buildVazio()
          else
            ...filtradas.map((item) => _buildCardPendencia(item, isDesktop)),
        ],
      ),
    );
  }

  Widget _buildCabecalhoFiltros(bool isDesktop) {
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
              const Icon(Icons.groups, color: AppColors.navy900),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Participações Pendentes de Avaliação',
                  style: AppTypography.h2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendenciasFiltradas.length} pendência(s)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.blue600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_equipes.length > 1) ...[
            const SizedBox(height: AppSpacing.s16),
            DropdownButtonFormField<String>(
              key: const Key('dropdownFiltroEquipe'),
              isExpanded: true,
              initialValue: _equipeFiltroId,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Equipe',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todas as equipes'),
                ),
                ..._equipes.map(
                  (eq) => DropdownMenuItem<String>(
                    value: eq.id,
                    child: Text(eq.nome),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _equipeFiltroId = val);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
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

  Widget _buildCardPendencia(ItemFilaResponsavelEquipe item, bool isDesktop) {
    final emProgresso = _acaoEmProgressoId == item.participacaoId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
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
          const Divider(height: 24),
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
          const SizedBox(height: AppSpacing.s16),
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

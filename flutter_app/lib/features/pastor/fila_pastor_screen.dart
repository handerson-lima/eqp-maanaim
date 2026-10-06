import 'package:flutter/material.dart';
import '../../comando.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import 'pastor_service.dart';

class FilaPastorScreen extends StatefulWidget {
  const FilaPastorScreen({
    super.key,
    required this.gateway,
    this.onSair,
    this.userName,
  });

  final PastorLocalGateway gateway;
  final VoidCallback? onSair;
  final String? userName;

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

  List<ItemFilaPastor> get _pendenciasFiltradas {
    if (_igrejaFiltroId == null || _igrejaFiltroId!.isEmpty) {
      return _pendencias;
    }
    return _pendencias.where((p) => p.igrejaId == _igrejaFiltroId).toList();
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
      await widget.gateway.decidirFicha(
        EntradaDecisaoPastor(
          commandId: commandId,
          fichaId: item.fichaId,
          decisao: decisao,
          justificativa: justificativa,
          expectedVersion: item.versao,
        ),
      );

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

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
                ? _buildErro()
                : _buildConteudo(),
      ),
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
        final isDesktop = constraints.maxWidth >= 768;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.s32 : AppSpacing.pagePaddingMobile,
            vertical: AppSpacing.s16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCabecalho(isDesktop),
                  const SizedBox(height: AppSpacing.s16),
                  if (_pendenciasFiltradas.isEmpty)
                    _buildListaVazia()
                  else
                    ..._pendenciasFiltradas.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: _buildCardPendencia(item, isDesktop),
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitações de Voluntariado',
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Avalie as fichas pendentes das igrejas sob sua responsabilidade.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (_igrejas.length > 1) ...[
          const SizedBox(width: AppSpacing.s16),
          DropdownButton<String?>(
            key: const Key('dropdownFiltroIgreja'),
            value: _igrejaFiltroId,
            hint: const Text('Todas as igrejas'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as igrejas'),
              ),
              ..._igrejas.map(
                (igreja) => DropdownMenuItem<String?>(
                  value: igreja.id,
                  child: Text(igreja.nome),
                ),
              ),
            ],
            onChanged: (novo) {
              setState(() => _igrejaFiltroId = novo);
            },
          ),
        ],
      ],
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

  Widget _buildCardPendencia(ItemFilaPastor item, bool isDesktop) {
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
                          const Icon(Icons.church_outlined,
                              size: 16, color: AppColors.blue600),
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
              const SizedBox(width: AppSpacing.s8),
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
          const Divider(height: AppSpacing.s24),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
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

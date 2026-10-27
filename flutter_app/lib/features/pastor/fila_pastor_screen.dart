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
  List<ItemFilaPastor> _rejeitadas = [];
  List<IgrejaEscopoPastor> _igrejas = [];
  String? _igrejaFiltroId;
  String? _processandoFichaId;
  String? _filtroKpi; // null = todas; 'RENOVACOES' = apenas renovações
  String _abaAtiva = 'PENDENTES'; // 'PENDENTES' ou 'REJEITADAS'
  int? _metricasAtivos;
  int? _metricasProximosVencimento;
  final ScrollController _scrollControllerTabelaPendencias = ScrollController();
  final ScrollController _scrollControllerTabelaRejeitadas = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  @override
  void dispose() {
    _scrollControllerTabelaPendencias.dispose();
    _scrollControllerTabelaRejeitadas.dispose();
    super.dispose();
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
        _rejeitadas = List.of(resultado.rejeitadas);
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

  List<ItemFilaPastor> get _rejeitadasNoEscopoIgreja {
    if (_igrejaFiltroId == null || _igrejaFiltroId!.isEmpty) {
      final idsAutorizados = _igrejas.map((i) => i.id).toSet();
      return _rejeitadas.where((p) => idsAutorizados.contains(p.igrejaId) || idsAutorizados.isEmpty).toList();
    }
    return _rejeitadas.where((p) => p.igrejaId == _igrejaFiltroId).toList();
  }

  int get _countPendencias => _pendenciasNoEscopoIgreja.length;
  int get _countRenovacoes => _pendenciasNoEscopoIgreja.where((p) => p.isRenovacaoAnual).length;
  int get _countRejeitadas => _rejeitadasNoEscopoIgreja.length;

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
        actionsOverflowButtonSpacing: AppSpacing.s8,
        title: const Text('Confirmar Aprovação da Ficha'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
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
        justificativa: null,
      );
    }
  }

  Future<void> _abrirModalRecusa(ItemFilaPastor item) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    final temMultiplasEquipes = item.equipes.length > 1;
    final equipesRecusadasIds = item.equipes.map((e) => e.equipeId).toSet();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final todasRecusadas = equipesRecusadasIds.length == item.equipes.length;
          final nenhumaRecusada = equipesRecusadasIds.isEmpty;

          return AlertDialog(
            actionsOverflowButtonSpacing: AppSpacing.s8,
            title: const Text('Decisão Pastoral Desfavorável'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voluntário: ${item.voluntarioNome}',
                        style: AppTypography.h3,
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
                      if (temMultiplasEquipes) ...[
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          'Equipes a recusar:',
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Selecione quais equipes devem ser recusadas. As equipes não marcadas serão aprovadas e avançarão para os respectivos responsáveis.',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        ...item.equipes.map((eq) {
                          final isRecusada = equipesRecusadasIds.contains(eq.equipeId);
                          return CheckboxListTile(
                            key: Key('checkRecusaEquipe_${eq.equipeId}'),
                            title: Text(eq.nomeEquipe, style: AppTypography.body),
                            subtitle: Text(
                              isRecusada ? 'Será recusada nesta etapa' : 'Será aprovada para o Responsável',
                              style: TextStyle(
                                fontSize: 12,
                                color: isRecusada ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: isRecusada,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.danger,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  equipesRecusadasIds.add(eq.equipeId);
                                } else {
                                  equipesRecusadasIds.remove(eq.equipeId);
                                }
                              });
                            },
                          );
                        }),
                        if (nenhumaRecusada)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Selecione ao menos 1 equipe para recusa, ou cancele para aprovar todas.',
                              style: AppTypography.caption.copyWith(color: AppColors.danger),
                            ),
                          ),
                      ],
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                key: const Key('btnConfirmarRecusaModal'),
                onPressed: nenhumaRecusada
                    ? null
                    : () {
                        if (formKey.currentState?.validate() == true) {
                          Navigator.of(ctx).pop(true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, AppGeometry.minTouchTarget),
                ),
                child: Text(
                  todasRecusadas || !temMultiplasEquipes
                      ? 'Confirmar Recusa'
                      : 'Confirmar Decisões',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == true) {
      final justificativa = controller.text.trim();
      List<DecisaoItemEquipePastor>? decisoesPorEquipe;
      final todasRecusadas = equipesRecusadasIds.length == item.equipes.length;

      if (temMultiplasEquipes) {
        decisoesPorEquipe = item.equipes.map((eq) {
          final recusada = equipesRecusadasIds.contains(eq.equipeId);
          return DecisaoItemEquipePastor(
            participacaoId: eq.participacaoId,
            equipeId: eq.equipeId,
            decisao: recusada ? 'DESFAVORAVEL' : 'APROVADO',
            justificativa: recusada ? justificativa : null,
          );
        }).toList();
      }

      await _executarDecisao(
        item: item,
        decisao: todasRecusadas ? 'DESFAVORAVEL' : 'APROVADO',
        justificativa: justificativa,
        decisoesPorEquipe: decisoesPorEquipe,
      );
    }
  }

  Future<void> _executarDecisao({
    required ItemFilaPastor item,
    required String decisao,
    String? justificativa,
    List<DecisaoItemEquipePastor>? decisoesPorEquipe,
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
        decisoesPorEquipe: decisoesPorEquipe,
      );

      if (item.isRenovacaoAnual) {
        await widget.gateway.decidirCicloAnual(entrada);
      } else {
        await widget.gateway.decidirFicha(entrada);
      }

      if (!mounted) return;

      final todasRecusadas = decisao == 'DESFAVORAVEL' &&
          (decisoesPorEquipe == null ||
              decisoesPorEquipe.every((d) => d.decisao == 'DESFAVORAVEL'));

      setState(() {
        _pendencias.removeWhere((p) => p.fichaId == item.fichaId);
        if (todasRecusadas) {
          final itemRejeitado = ItemFilaPastor(
            id: item.id,
            fichaId: item.fichaId,
            voluntarioUid: item.voluntarioUid,
            voluntarioNome: item.voluntarioNome,
            igrejaId: item.igrejaId,
            nomeIgreja: item.nomeIgreja,
            estado: 'REJEITADA',
            proximaAcao: 'PASTOR_LOCAL_CONSULTA',
            enviadoEm: item.enviadoEm,
            decididoEm: DateTime.now().toIso8601String(),
            justificativaPastoral: justificativa,
            equipes: item.equipes,
            isRenovacaoAnual: item.isRenovacaoAnual,
            ano: item.ano,
            cicloId: item.cicloId,
            versao: item.versao + 1,
          );
          _rejeitadas.insert(0, itemRejeitado);
        }
        _processandoFichaId = null;
      });

      final String mensagemFeedback;
      if (decisao == 'APROVADO' && decisoesPorEquipe == null) {
        mensagemFeedback = 'Ficha de ${item.voluntarioNome} aprovada com sucesso!';
      } else if (todasRecusadas) {
        mensagemFeedback = 'Decisão desfavorável registrada com sucesso.';
      } else {
        final aprovadas = decisoesPorEquipe!.where((d) => d.decisao == 'APROVADO').length;
        final recusadas = decisoesPorEquipe.where((d) => d.decisao == 'DESFAVORAVEL').length;
        mensagemFeedback = 'Decisão registrada: $aprovadas equipe(s) aprovada(s) e $recusadas recusada(s).';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemFeedback),
          backgroundColor: todasRecusadas ? AppColors.danger : AppColors.success,
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
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isDesktop = constraints.maxWidth >= 900 || screenWidth >= 1024;

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
                  if (_filtroKpi != null && _abaAtiva == 'PENDENTES') ...[
                    _buildBannerFiltroAtivo(),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                  _buildTituloSecaoPendencias(),
                  const SizedBox(height: AppSpacing.s8),
                  _buildAbasFila(),
                  const SizedBox(height: AppSpacing.s12),
                  if (_abaAtiva == 'PENDENTES') ...[
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
                  ] else ...[
                    if (_rejeitadasNoEscopoIgreja.isEmpty)
                      _buildListaVaziaRejeitadas()
                    else if (isDesktop)
                      _buildTabelaRejeitadasDesktop()
                    else
                      ..._rejeitadasNoEscopoIgreja.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                          child: _buildCardRejeitada(item),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTituloSecaoPendencias() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Pendências recentes',
              style: AppTypography.h3.copyWith(color: AppColors.navy900),
            ),
          ),
          TextButton(
            key: const Key('linkVerTodas'),
            onPressed: () {
              setState(() => _filtroKpi = null);
            },
            child: Text(
              'Ver todas',
              style: AppTypography.label.copyWith(
                color: AppColors.blue600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbasFila() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: SegmentedButton<String>(
          key: const Key('segmentedButtonAbasFila'),
          segments: [
            ButtonSegment<String>(
              value: 'PENDENTES',
              label: Text('Pendências ($_countPendencias)'),
              icon: const Icon(Icons.assignment_outlined, size: 18),
            ),
            ButtonSegment<String>(
              value: 'REJEITADAS',
              label: Text('Fichas Rejeitadas ($_countRejeitadas)'),
              icon: const Icon(Icons.cancel_outlined, size: 18),
            ),
          ],
          selected: {_abaAtiva},
          onSelectionChanged: (novaSelecao) {
            setState(() {
              _abaAtiva = novaSelecao.first;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCabecalho(bool isDesktop) {
    final nomePastor = (widget.userName != null && widget.userName!.trim().isNotEmpty)
        ? widget.userName!.trim()
        : 'Pastor Local';
    final formatado = (nomePastor == 'Pastor Local' || nomePastor.startsWith('Pr.'))
        ? nomePastor
        : 'Pr. $nomePastor';
    final saudacao = 'Olá, $formatado';

    final infoPastor = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            Text(
              saudacao,
              style: AppTypography.h2.copyWith(color: AppColors.navy900),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Pastor Local',
                style: AppTypography.caption.copyWith(
                  color: AppColors.blue600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Avalie as fichas pendentes das igrejas sob sua responsabilidade.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );

    Widget? seletorIgreja;
    if (_igrejas.isNotEmpty) {
      seletorIgreja = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: isDesktop ? 180 : 0,
          maxWidth: isDesktop ? 240 : double.infinity,
        ),
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
      );
    }

    if (!isDesktop && seletorIgreja != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            infoPastor,
            const SizedBox(height: AppSpacing.s8),
            seletorIgreja,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: infoPastor),
          if (seletorIgreja != null) ...[
            const SizedBox(width: AppSpacing.s12),
            seletorIgreja,
          ],
        ],
      ),
    );
  }

  Widget _buildKpis(double maxWidth) {
    final kpiPendencias = MetricCard(
      title: 'Pendências',
      value: '$_countPendencias',
      icon: Icons.assignment_outlined,
      variant: MetricVariant.danger,
      subtitle: 'aguardando análise',
      subtitleColor: AppColors.danger,
      isSelected: _filtroKpi == null,
      badge: _filtroKpi == null && _countPendencias > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Fila', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          : null,
      onTap: () {
        setState(() => _filtroKpi = null);
      },
    );

    final kpiRenovacoes = MetricCard(
      title: 'Renovações',
      value: '$_countRenovacoes',
      icon: Icons.sync,
      variant: MetricVariant.primary,
      subtitle: 'neste ano',
      subtitleColor: AppColors.blue600,
      isSelected: _filtroKpi == 'RENOVACOES',
      badge: _filtroKpi == 'RENOVACOES'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Ativo', style: TextStyle(color: AppColors.blue600, fontSize: 11, fontWeight: FontWeight.bold)),
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
      icon: Icons.people_outline,
      variant: MetricVariant.success,
      subtitle: 'em todas as igrejas',
      subtitleColor: AppColors.success,
    );

    final kpiProximosVencimento = MetricCard(
      title: 'Próximos do vencimento',
      value: _metricasProximosVencimento != null ? '$_metricasProximosVencimento' : '--',
      icon: Icons.schedule_outlined,
      variant: MetricVariant.warning,
      subtitle: 'até 60 dias',
      subtitleColor: AppColors.warning,
    );

    if (maxWidth >= 1024) {
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
    } else if (maxWidth >= 600) {
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
    return const SectionCard(
      padding: EdgeInsets.zero,
      child: EmptyState(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        title: 'Nenhuma solicitação pendente',
        message: 'Todas as fichas de voluntários nas suas igrejas foram avaliadas.',
      ),
    );
  }

  Widget _buildTabelaDesktop() {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _scrollControllerTabelaPendencias,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollControllerTabelaPendencias,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: AppSpacing.s16,
                  horizontalMargin: AppSpacing.s16,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 80,
                  columns: const [
                    DataColumn(label: Text('Voluntário', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Igreja', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Equipes', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Enviado em', style: TextStyle(fontWeight: FontWeight.bold))),
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
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: item.equipes.map((e) {
                                return Chip(
                                  label: Text(e.nomeEquipe, style: const TextStyle(fontSize: 12)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
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
                                  backgroundColor: AppColors.blue600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
                                ),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                key: Key('btnRecusar_${item.fichaId}'),
                                onPressed: processando ? null : () => _abrirModalRecusa(item),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
                                ),
                                child: const Text('Recusar'),
                              ),
                              const SizedBox(width: 6),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
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
        },
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
          Column(
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
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.isRenovacaoAnual)
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
                    backgroundColor: AppColors.blue600,
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

  Widget _buildListaVaziaRejeitadas() {
    return const SectionCard(
      padding: EdgeInsets.zero,
      child: EmptyState(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.textSecondary,
        title: 'Nenhuma ficha rejeitada',
        message: 'Não há solicitações com decisão desfavorável nas suas igrejas.',
      ),
    );
  }

  Widget _buildTabelaRejeitadasDesktop() {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _scrollControllerTabelaRejeitadas,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollControllerTabelaRejeitadas,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: AppSpacing.s16,
                  horizontalMargin: AppSpacing.s16,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 96,
                  columns: const [
                    DataColumn(label: Text('Voluntário', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Igreja', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Equipes', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Decidido em', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Justificativa Pastoral Interna', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
            rows: _rejeitadasNoEscopoIgreja.map((item) {
              return DataRow(
                key: ValueKey('rowFichaRejeitada_${item.fichaId}'),
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
                    Text(_formatarData(item.decididoEm ?? item.enviadoEm), style: AppTypography.body),
                  ),
                  const DataCell(
                    StatusChip(
                      status: 'DESFAVORAVEL',
                      label: 'DESFAVORÁVEL',
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          (item.justificativaPastoral != null && item.justificativaPastoral!.isNotEmpty)
                              ? item.justificativaPastoral!
                              : 'Decisão desfavorável registrada pelo Pastor da igreja local.',
                          style: AppTypography.caption.copyWith(color: AppColors.navy900),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardRejeitada(ItemFilaPastor item) {
    return SectionCard(
      key: Key('cardFichaRejeitada_${item.fichaId}'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
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
              const StatusChip(
                status: 'DESFAVORAVEL',
                label: 'DESFAVORÁVEL',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Equipes solicitadas:',
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
          const SizedBox(height: AppSpacing.s12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Justificativa Pastoral Interna (Decidido em ${_formatarData(item.decididoEm ?? item.enviadoEm)}):',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (item.justificativaPastoral != null && item.justificativaPastoral!.isNotEmpty)
                      ? item.justificativaPastoral!
                      : 'Decisão desfavorável registrada pelo Pastor da igreja local.',
                  style: AppTypography.body.copyWith(color: AppColors.navy900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

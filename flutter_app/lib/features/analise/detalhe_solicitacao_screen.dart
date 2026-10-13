import 'package:flutter/material.dart';
import '../../comando.dart';
import '../../ui/components/cpf_formatter.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../pastor/pastor_service.dart';
import '../responsavel_equipe/responsavel_equipe_service.dart';
import 'detalhe_solicitacao_model.dart';
import 'detalhe_solicitacao_service.dart';

/// Tela S05 — Detalhe da Solicitação e Decisão Contextual.
/// Apresenta visão profunda dos dados autorizados, documentos, lista de equipes independentes
/// e painel de decisão com escopo estrito por papel.
class DetalheSolicitacaoScreen extends StatefulWidget {
  const DetalheSolicitacaoScreen({
    super.key,
    required this.fichaId,
    required this.papel,
    required this.gateway,
    this.equipeEscopoId,
    this.nomeVoluntarioInicial,
    this.isRenovacaoAnual = false,
    this.cicloId,
    this.versaoInicial,
    this.onDecisaoConcluida,
    this.onVoltar,
    this.dentroDeShell = false,
  });

  final String fichaId;
  final PapelContextualAnalise papel;
  final DetalheSolicitacaoGateway gateway;
  final String? equipeEscopoId;
  final String? nomeVoluntarioInicial;
  final bool isRenovacaoAnual;
  final String? cicloId;
  final int? versaoInicial;
  final void Function(ResultadoDecisaoContextual resultado)? onDecisaoConcluida;
  final VoidCallback? onVoltar;
  final bool dentroDeShell;

  @override
  State<DetalheSolicitacaoScreen> createState() => _DetalheSolicitacaoScreenState();
}

class _DetalheSolicitacaoScreenState extends State<DetalheSolicitacaoScreen> {
  bool _carregando = true;
  String? _erroCarregamento;
  bool _conflitoConcorrencia = false;
  bool _processandoDecisao = false;
  DetalheSolicitacaoDados? _dados;

  // Estado contextual do Coordenador Geral
  bool _confirmacaoReuniaoPastores = false;
  final TextEditingController _observacaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DetalheSolicitacaoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fichaId != widget.fichaId || oldWidget.gateway != widget.gateway) {
      _carregarDados();
    }
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
      _conflitoConcorrencia = false;
    });

    try {
      final res = await widget.gateway.obterDetalhe(
        fichaId: widget.fichaId,
        cicloId: widget.cicloId,
      );
      if (!mounted) return;
      setState(() {
        _dados = res;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroCarregamento =
            'Não foi possível carregar os detalhes da solicitação. Verifique sua conexão e autorização.';
        _carregando = false;
      });
    }
  }

  // --- Fluxos de Decisão Contextual ---

  Future<void> _executarAprovacaoPastor() async {
    final dados = _dados;
    if (dados == null || _processandoDecisao) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Aprovação Pastoral'),
        content: Text(
          'Deseja aprovar a solicitação de ${dados.voluntarioNome}?\n\n'
          'Consequência: A solicitação será encaminhada para avaliação dos responsáveis das equipes solicitadas.',
        ),
        actions: [
          TextButton(
            key: const Key('btnCancelarModalAprovacaoPastor'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('btnConfirmarModalAprovacaoPastor'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Aprovação'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _processandoDecisao = true);

    try {
      final entrada = EntradaDecisaoPastor(
        commandId: comandoOpaco(),
        fichaId: dados.fichaId,
        cicloId: dados.cicloId,
        decisao: 'APROVADO',
        expectedVersion: dados.versao,
      );

      await widget.gateway.decidirPastor(
        entrada,
        isRenovacao: dados.isRenovacaoAnual,
      );

      if (!mounted) return;
      _notificarSucesso(
        'Solicitação aprovada com sucesso!',
        'APROVADO',
      );
    } catch (e) {
      _tratarErroDecisao(e);
    } finally {
      if (mounted) setState(() => _processandoDecisao = false);
    }
  }

  Future<void> _executarRecusaPastor() async {
    final dados = _dados;
    if (dados == null || _processandoDecisao) return;

    final justificativa = await _abrirModalJustificativa(
      titulo: 'Registrar Decisão Desfavorável',
      descricaoConsequencia:
          'A ficha de ${dados.voluntarioNome} será encerrada nesta etapa pastoral.',
    );

    if (justificativa == null || justificativa.trim().isEmpty) return;

    setState(() => _processandoDecisao = true);

    try {
      final entrada = EntradaDecisaoPastor(
        commandId: comandoOpaco(),
        fichaId: dados.fichaId,
        cicloId: dados.cicloId,
        decisao: 'DESFAVORAVEL',
        justificativa: justificativa.trim(),
        expectedVersion: dados.versao,
      );

      await widget.gateway.decidirPastor(
        entrada,
        isRenovacao: dados.isRenovacaoAnual,
      );

      if (!mounted) return;
      _notificarSucesso(
        'Decisão desfavorável registrada com sucesso.',
        'DESFAVORAVEL',
      );
    } catch (e) {
      _tratarErroDecisao(e);
    } finally {
      if (mounted) setState(() => _processandoDecisao = false);
    }
  }

  Future<void> _executarAprovacaoResponsavel(ItemParticipacaoDetalhe participacao) async {
    final dados = _dados;
    if (dados == null || _processandoDecisao) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aprovar Participação: ${participacao.nomeEquipe}'),
        content: Text(
          'Confirma a aprovação de ${dados.voluntarioNome} para atuar na equipe ${participacao.nomeEquipe}?\n\n'
          'Consequência: A participação avançará para homologação da Coordenação Geral.',
        ),
        actions: [
          TextButton(
            key: const Key('btnCancelarModalAprovacaoResp'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('btnConfirmarModalAprovacaoResp'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Aprovação'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _processandoDecisao = true);

    try {
      final entrada = EntradaDecidirParticipacaoResponsavel(
        commandId: comandoOpaco(),
        participacaoId: participacao.id,
        cicloId: dados.cicloId,
        decisao: 'APROVADO',
        expectedVersion: dados.versao,
      );

      await widget.gateway.decidirResponsavel(
        entrada,
        isRenovacao: dados.isRenovacaoAnual,
      );

      if (!mounted) return;
      _notificarSucesso(
        'Participação na equipe ${participacao.nomeEquipe} aprovada com sucesso!',
        'APROVADO',
        equipeId: participacao.equipeId,
      );
    } catch (e) {
      _tratarErroDecisao(e);
    } finally {
      if (mounted) setState(() => _processandoDecisao = false);
    }
  }

  Future<void> _executarRecusaResponsavel(ItemParticipacaoDetalhe participacao) async {
    final dados = _dados;
    if (dados == null || _processandoDecisao) return;

    final justificativa = await _abrirModalJustificativa(
      titulo: 'Recusar Participação: ${participacao.nomeEquipe}',
      descricaoConsequencia:
          'A participação em ${participacao.nomeEquipe} não será aceita. As demais equipes solicitadas permanecem independentes.',
    );

    if (justificativa == null || justificativa.trim().isEmpty) return;

    setState(() => _processandoDecisao = true);

    try {
      final entrada = EntradaDecidirParticipacaoResponsavel(
        commandId: comandoOpaco(),
        participacaoId: participacao.id,
        cicloId: dados.cicloId,
        decisao: 'DESFAVORAVEL',
        justificativa: justificativa.trim(),
        expectedVersion: dados.versao,
      );

      await widget.gateway.decidirResponsavel(
        entrada,
        isRenovacao: dados.isRenovacaoAnual,
      );

      if (!mounted) return;
      _notificarSucesso(
        'Participação em ${participacao.nomeEquipe} não aprovada.',
        'DESFAVORAVEL',
        equipeId: participacao.equipeId,
      );
    } catch (e) {
      _tratarErroDecisao(e);
    } finally {
      if (mounted) setState(() => _processandoDecisao = false);
    }
  }

  Future<void> _executarHomologacaoCoordenador() async {
    final dados = _dados;
    if (dados == null || _processandoDecisao) return;

    if (!_confirmacaoReuniaoPastores) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É obrigatório confirmar a deliberação na Reunião de Pastores.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Homologação e Ativação'),
        content: Text(
          'Confirma a homologação da solicitação de ${dados.voluntarioNome}?\n\n'
          'Consequência: A ficha e as participações aprovadas serão ativadas com emissão de documentos.',
        ),
        actions: [
          TextButton(
            key: const Key('btnCancelarModalHomologacaoCoord'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('btnConfirmarModalHomologacaoCoord'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue600),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Homologação'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _processandoDecisao = true);

    try {
      final entrada = EntradaDecisaoCoordenadorContextual(
        commandId: comandoOpaco(),
        fichaId: dados.fichaId,
        cicloId: dados.cicloId,
        decisao: 'APROVADO',
        confirmacaoReuniaoPastores: true,
        expectedVersion: dados.versao,
      );

      await widget.gateway.decidirCoordenador(
        entrada: entrada,
        isRenovacao: dados.isRenovacaoAnual,
      );

      if (!mounted) return;
      _notificarSucesso(
        'Solicitação homologada e ativada com sucesso!',
        'HOMOLOGADO',
      );
    } catch (e) {
      _tratarErroDecisao(e);
    } finally {
      if (mounted) setState(() => _processandoDecisao = false);
    }
  }

  Future<void> _executarRecusaCoordenador() async {
    final dados = _dados;
    if (dados == null || _processandoDecisao) return;

    final justificativa = await _abrirModalJustificativa(
      titulo: 'Recusar Homologação da Solicitação',
      descricaoConsequencia:
          'A solicitação de ${dados.voluntarioNome} será encerrada sem ativação.',
    );

    if (justificativa == null || justificativa.trim().isEmpty) return;

    setState(() => _processandoDecisao = true);

    try {
      final entrada = EntradaDecisaoCoordenadorContextual(
        commandId: comandoOpaco(),
        fichaId: dados.fichaId,
        cicloId: dados.cicloId,
        decisao: 'DESFAVORAVEL',
        confirmacaoReuniaoPastores: _confirmacaoReuniaoPastores,
        justificativa: justificativa.trim(),
        expectedVersion: dados.versao,
      );

      await widget.gateway.decidirCoordenador(
        entrada: entrada,
        isRenovacao: dados.isRenovacaoAnual,
      );

      if (!mounted) return;
      _notificarSucesso(
        'Recusa registrada com sucesso.',
        'DESFAVORAVEL',
      );
    } catch (e) {
      _tratarErroDecisao(e);
    } finally {
      if (mounted) setState(() => _processandoDecisao = false);
    }
  }

  Future<String?> _abrirModalJustificativa({
    required String titulo,
    required String descricaoConsequencia,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(titulo),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descricaoConsequencia,
                      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        borderRadius: AppGeometry.cardBorderRadius,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              'Mensagem canônica ao voluntário:\n'
                              '"Procure o Pastor da igreja local para mais informações".\n'
                              'A justificativa abaixo é estritamente confidencial para auditoria interna.',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.navy900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    TextFormField(
                      key: const Key('inputJustificativaDecisao'),
                      controller: controller,
                      maxLines: 3,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Justificativa Interna Obrigatória *',
                        hintText: 'Descreva o motivo desta deliberação...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'A justificativa é obrigatória para decisões desfavoráveis.';
                        }
                        if (val.trim().length < 5) {
                          return 'Forneça ao menos 5 caracteres de justificativa.';
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
              key: const Key('btnCancelarModalJustificativa'),
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('btnConfirmarModalJustificativa'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('Confirmar Decisão Desfavorável'),
            ),
          ],
        );
      },
    );
  }

  void _tratarErroDecisao(Object error) {
    if (error is ConflitoConcorrenciaException) {
      setState(() => _conflitoConcorrencia = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao registrar decisão: ${error.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _notificarSucesso(String mensagem, String decisao, {String? equipeId}) {
    final dados = _dados;
    final resultado = ResultadoDecisaoContextual(
      fichaId: dados?.fichaId ?? widget.fichaId,
      equipeId: equipeId ?? widget.equipeEscopoId,
      decisao: decisao,
      sucesso: true,
      mensagem: mensagem,
    );

    if (widget.onDecisaoConcluida != null) {
      widget.onDecisaoConcluida!(resultado);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: decisao == 'DESFAVORAVEL' ? AppColors.danger : AppColors.success,
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(resultado);
    } else if (widget.onVoltar != null) {
      widget.onVoltar!();
    }
  }

  // --- Widgets de Renderização ---

  @override
  Widget build(BuildContext context) {
    final corpo = SafeArea(
      child: _carregando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.s16),
                  Text('Carregando detalhes autorizados...'),
                ],
              ),
            )
          : _erroCarregamento != null
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
        title: Text(
          widget.nomeVoluntarioInicial != null
              ? 'Análise: ${widget.nomeVoluntarioInicial}'
              : 'Detalhe da Solicitação',
          style: AppTypography.h3.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.navy900,
        leading: IconButton(
          key: const Key('btnVoltarDetalhe'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Voltar para a fila',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (widget.onVoltar != null) {
              widget.onVoltar!();
            }
          },
        ),
      ),
      body: corpo,
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: SectionCard(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.s16),
              Text('Erro de Carregamento', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _erroCarregamento ?? 'Falha ao obter dados da solicitação.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s24),
              ElevatedButton(
                key: const Key('btnTentarNovamenteDetalhe'),
                onPressed: _carregarDados,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, AppGeometry.minTouchTarget),
                ),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    final dados = _dados;
    if (dados == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        return RefreshIndicator(
          onRefresh: _carregarDados,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              isDesktop ? AppSpacing.pagePaddingDesktop : AppSpacing.pagePaddingMobile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderS05(dados, isDesktop),
                const SizedBox(height: AppSpacing.s16),
                if (_conflitoConcorrencia) ...[
                  _buildAlertaConcorrencia(),
                  const SizedBox(height: AppSpacing.s16),
                ],
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coluna 1 (Esquerda ~1/3): Resumo Autorizado do Voluntário e Ficha
                      SizedBox(
                        width: 360,
                        child: _buildResumoVoluntario(dados),
                      ),
                      const SizedBox(width: AppSpacing.s24),
                      // Coluna 2 (Direita ~2/3): Equipes, Documentos e Painel de Decisão
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSecaoEquipes(dados),
                            const SizedBox(height: AppSpacing.s20),
                            _buildSecaoDocumentosEvidencias(dados),
                            const SizedBox(height: AppSpacing.s20),
                            _buildPainelDecisao(dados),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Mobile (<720px): Empilhamento vertical estrito
                  _buildResumoVoluntario(dados),
                  const SizedBox(height: AppSpacing.s16),
                  _buildSecaoEquipes(dados),
                  const SizedBox(height: AppSpacing.s16),
                  _buildSecaoDocumentosEvidencias(dados),
                  const SizedBox(height: AppSpacing.s16),
                  _buildPainelDecisao(dados),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChipStatusAguardando() {
    return Container(
      key: const Key('chipStatusAguardandoAprovacao'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Aguardando sua aprovação',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.navy900,
            ),
          ),
        ],
      ),
    );
  }

  String _obterRotuloPapelContextual() {
    switch (widget.papel) {
      case PapelContextualAnalise.pastorLocal:
        return 'Pastor Local';
      case PapelContextualAnalise.responsavelEquipe:
        return 'Responsável de Equipe';
      case PapelContextualAnalise.coordenadorGeral:
        return 'Coordenador Geral';
    }
  }

  IconData _obterIconePapelContextual() {
    switch (widget.papel) {
      case PapelContextualAnalise.pastorLocal:
        return Icons.how_to_reg_outlined;
      case PapelContextualAnalise.responsavelEquipe:
        return Icons.groups_outlined;
      case PapelContextualAnalise.coordenadorGeral:
        return Icons.verified_outlined;
    }
  }

  Widget _buildBadgePapelContextual() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_obterIconePapelContextual(), size: 14, color: AppColors.blue600),
          const SizedBox(width: 4),
          Text(
            _obterRotuloPapelContextual(),
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.blue600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderS05(DetalheSolicitacaoDados dados, bool isDesktop) {
    final botoesStatus = Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildBadgePapelContextual(),
        _buildChipStatusAguardando(),
      ],
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                key: const Key('btnVoltarDetalheInPage'),
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (widget.onVoltar != null) {
                    widget.onVoltar!();
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 20, color: AppColors.navy900),
                      SizedBox(width: 4),
                      Text(
                        'Voltar',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Análise da Ficha',
                  style: AppTypography.h2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          botoesStatus,
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: const Key('btnVoltarDetalheInPage'),
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else if (widget.onVoltar != null) {
                  widget.onVoltar!();
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 20, color: AppColors.navy900),
                    SizedBox(width: 4),
                    Text(
                      'Voltar',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text('Análise da Ficha', style: AppTypography.h2),
          ],
        ),
        botoesStatus,
      ],
    );
  }

  Widget _buildAlertaConcorrencia() {
    return Container(
      key: const Key('alertaConcorrencia'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conflito Concorrente Detectado',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy900,
                  ),
                ),
                Text(
                  'Esta solicitação foi alterada por outro usuário ou versão concorrente. É necessário recarregar os dados para reanalisar antes de submeter.',
                  style: AppTypography.caption.copyWith(color: AppColors.navy900),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          ElevatedButton.icon(
            key: const Key('btnRecarregarAposConflito'),
            onPressed: _carregarDados,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Recarregar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoVoluntario(DetalheSolicitacaoDados dados) {
    return SectionCard(
      key: const Key('cardResumoVoluntario'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.blue600.withValues(alpha: 0.1),
                child: Text(
                  dados.voluntarioNome.isNotEmpty
                      ? dados.voluntarioNome.substring(0, 1).toUpperCase()
                      : 'V',
                  style: AppTypography.h2.copyWith(color: AppColors.blue600),
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dados.voluntarioNome,
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.blue50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dados.codigoFormatado,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    StatusChip(
                      status: dados.estadoFicha,
                      label: dados.estadoFicha.replaceAll('_', ' '),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.s24),
          Text('Dados Cadastrais Autorizados', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.s12),
          _buildInfoLinha(
            'Tipo de solicitação',
            dados.isRenovacaoAnual
                ? (dados.anoCiclo != null ? 'Renovação Anual (Ciclo ${dados.anoCiclo})' : 'Renovação Anual')
                : 'Primeira Solicitação / Adesão',
            dados.isRenovacaoAnual ? Icons.autorenew : Icons.person_add_alt_outlined,
          ),
          const SizedBox(height: AppSpacing.s8),
          if (dados.idade != null) ...[
            _buildInfoLinha('Idade', '${dados.idade} anos', Icons.cake_outlined),
            const SizedBox(height: AppSpacing.s8),
          ],
          if (dados.telefone != null && dados.telefone!.isNotEmpty) ...[
            _buildInfoLinha('Telefone', dados.telefone!, Icons.phone_outlined),
            const SizedBox(height: AppSpacing.s8),
          ],
          if (dados.email != null && dados.email!.isNotEmpty) ...[
            _buildInfoLinha('E-mail', dados.email!, Icons.email_outlined),
            const SizedBox(height: AppSpacing.s8),
          ],
          _buildInfoLinha(
            'Igreja Local',
            dados.nomeIgreja ?? (dados.igrejaId.isNotEmpty ? dados.igrejaId : 'Não informada'),
            Icons.church_outlined,
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildInfoLinha(
            'Data de envio',
            dados.dataEnvioFormatada,
            Icons.calendar_today_outlined,
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildInfoLinha(
            'CPF',
            dados.cpfMascarado != null && dados.cpfMascarado!.isNotEmpty
                ? CpfFormatter.formatar(dados.cpfMascarado!)
                : 'Protegido por LGPD',
            Icons.badge_outlined,
          ),
          if (dados.profissao != null && dados.profissao!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            _buildInfoLinha('Profissão', dados.profissao!, Icons.work_outline),
          ],
          const SizedBox(height: AppSpacing.s8),
          _buildInfoLinha(
            'Versão do Agregado',
            'v${dados.versao}',
            Icons.history_outlined,
          ),
          if (dados.isRenovacaoAnual) ...[
            const SizedBox(height: AppSpacing.s8),
            _buildInfoLinha(
              'Ciclo Anual',
              dados.anoCiclo != null ? 'Ano ${dados.anoCiclo}' : 'Renovação Vigente',
              Icons.autorenew_outlined,
            ),
          ],
          const SizedBox(height: AppSpacing.s20),
          OutlinedButton.icon(
            key: const Key('btnVerFichaPdf'),
            icon: const Icon(Icons.description_outlined, size: 18, color: AppColors.blue600),
            label: const Text('Ver ficha completa (PDF)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue600,
              side: const BorderSide(color: AppColors.blue600),
              minimumSize: const Size(double.infinity, AppGeometry.minTouchTarget),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Abrindo ficha completa (PDF)...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLinha(String label, String valor, IconData icone) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
              Text(
                valor,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoEquipes(DetalheSolicitacaoDados dados) {
    return SectionCard(
      key: const Key('cardSecaoEquipes'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Equipes solicitadas', style: AppTypography.h3),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '${dados.participacoes.length} equipe(s)',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (dados.participacoes.isEmpty)
            Text(
              'Nenhuma participação associada a esta solicitação.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            )
          else
            ...dados.participacoes.map((p) => _buildCardParticipacao(p, dados)),
        ],
      ),
    );
  }

  Widget _buildCardParticipacao(ItemParticipacaoDetalhe p, DetalheSolicitacaoDados dados) {
    final ehEscopoDoUsuario = widget.papel == PapelContextualAnalise.responsavelEquipe &&
        (widget.equipeEscopoId == p.equipeId || widget.equipeEscopoId == null);

    final ehAguardando = p.estado.startsWith('AGUARDANDO');

    return Container(
      key: Key('cardParticipacao_${p.equipeId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: ehEscopoDoUsuario ? AppColors.blue50.withValues(alpha: 0.3) : AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: ehEscopoDoUsuario ? AppColors.blue600 : AppColors.border,
          width: ehEscopoDoUsuario ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ehEscopoDoUsuario) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue600,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Sua equipe sob avaliação',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 20,
                      color: ehEscopoDoUsuario ? AppColors.blue600 : AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Flexible(
                      child: Text(
                        p.nomeEquipe,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ehEscopoDoUsuario ? AppColors.blue600 : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                status: p.estado,
                label: ehAguardando ? 'AGUARDANDO' : p.estado.replaceAll('_', ' '),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Text('Ciclo: ${p.ciclo}', style: AppTypography.caption),
              if (p.decisao != null) ...[
                const SizedBox(width: AppSpacing.s12),
                Text('Parecer: ${p.decisao}', style: AppTypography.caption),
              ],
            ],
          ),
          if (widget.papel == PapelContextualAnalise.responsavelEquipe && !ehEscopoDoUsuario) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Outra equipe independente (somente leitura para o seu perfil)',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecaoDocumentosEvidencias(DetalheSolicitacaoDados dados) {
    final docs = List<DocumentoEvidenciaModel>.from(dados.documentos);
    // Assegura exibição da Ficha do voluntário se não presente
    if (!docs.any((d) => d.tipo == 'FICHA_CADASTRAL' || d.titulo.contains('Ficha do voluntário'))) {
      docs.insert(
        0,
        const DocumentoEvidenciaModel(
          tipo: 'FICHA_CADASTRAL',
          titulo: 'Ficha do voluntário',
          descricao: 'Cadastro e dados declarados pelo voluntário',
          disponivel: true,
        ),
      );
    }

    return SectionCard(
      key: const Key('cardSecaoDocumentos'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documentos e Evidências', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.s12),
          ...docs.map((doc) => _buildItemDocumento(doc)),
        ],
      ),
    );
  }

  Widget _buildItemDocumento(DocumentoEvidenciaModel doc) {
    return Container(
      key: Key('itemDoc_${doc.tipo}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            doc.tipo == 'PDF_APROVACAO' ? Icons.picture_as_pdf : Icons.description_outlined,
            color: doc.disponivel ? AppColors.blue600 : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.titulo,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: doc.disponivel ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                Text(
                  doc.descricao,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (doc.disponivel)
            TextButton.icon(
              key: Key('btnVisualizarDoc_${doc.tipo}'),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.blue600),
              label: const Text(
                'Ver documento',
                style: TextStyle(
                  color: AppColors.blue600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Visualizando ${doc.titulo}')),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Indisponível',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPainelDecisao(DetalheSolicitacaoDados dados) {
    return SectionCard(
      key: const Key('cardPainelDecisao'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, size: 22, color: AppColors.navy900),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text('Sua decisão', style: AppTypography.h3),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            _obterTextoOrientacaoPapel(),
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextFormField(
            key: const Key('inputObservacaoDecisao'),
            controller: _observacaoController,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              hintText: 'Adicione notas sobre a decisão...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (widget.papel == PapelContextualAnalise.pastorLocal)
            _buildAcoesPastor()
          else if (widget.papel == PapelContextualAnalise.responsavelEquipe)
            _buildAcoesResponsavel(dados)
          else if (widget.papel == PapelContextualAnalise.coordenadorGeral)
            _buildAcoesCoordenador(),
        ],
      ),
    );
  }

  String _obterTextoOrientacaoPapel() {
    switch (widget.papel) {
      case PapelContextualAnalise.pastorLocal:
        return 'Como Pastor Local, delibere sobre o encaminhamento da ficha cadastral desta solicitação para as equipes.';
      case PapelContextualAnalise.responsavelEquipe:
        return 'Como Responsável de Equipe, aprove ou recuse estritamente a participação referente à sua equipe vigente.';
      case PapelContextualAnalise.coordenadorGeral:
        return 'Como Coordenador Geral, confirme a deliberação na Reunião de Pastores antes de homologar e ativar.';
    }
  }

  Widget _buildAcoesPastor() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('btnRecusarPastorDetalhe'),
            onPressed: _processandoDecisao ? null : _executarRecusaPastor,
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            label: const Text('✕ Rejeitar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, AppGeometry.minTouchTarget),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s16),
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('btnAprovarPastorDetalhe'),
            onPressed: _processandoDecisao ? null : _executarAprovacaoPastor,
            icon: _processandoDecisao
                ? const SizedBox.shrink()
                : const Icon(Icons.check, color: Colors.white, size: 18),
            label: _processandoDecisao
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('✓ Aprovar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, AppGeometry.minTouchTarget),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcoesResponsavel(DetalheSolicitacaoDados dados) {
    // Localiza a participação do escopo do responsável
    final participacaoEscopo = dados.participacoes.firstWhere(
      (p) => p.equipeId == widget.equipeEscopoId,
      orElse: () => dados.participacoes.isNotEmpty
          ? dados.participacoes.first
          : const ItemParticipacaoDetalhe(
              id: '',
              equipeId: '',
              nomeEquipe: 'Equipe',
              estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
              ciclo: 'INICIAL',
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: AppGeometry.cardBorderRadius,
            border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.blue600),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Deliberação para: ${participacaoEscopo.nomeEquipe} (as outras equipes solicitadas não sofrem alteração)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.navy900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('btnRecusarResponsavelDetalhe'),
                onPressed: _processandoDecisao
                    ? null
                    : () => _executarRecusaResponsavel(participacaoEscopo),
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                label: const Text('✕ Rejeitar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('btnAprovarResponsavelDetalhe'),
                onPressed: _processandoDecisao
                    ? null
                    : () => _executarAprovacaoResponsavel(participacaoEscopo),
                icon: _processandoDecisao
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check, color: Colors.white, size: 18),
                label: _processandoDecisao
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('✓ Aprovar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcoesCoordenador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: AppGeometry.cardBorderRadius,
            border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const Key('checkConfirmacaoReuniaoPastores'),
                value: _confirmacaoReuniaoPastores,
                onChanged: _processandoDecisao
                    ? null
                    : (val) {
                        setState(() => _confirmacaoReuniaoPastores = val ?? false);
                      },
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: GestureDetector(
                  onTap: _processandoDecisao
                      ? null
                      : () {
                          setState(() {
                            _confirmacaoReuniaoPastores = !_confirmacaoReuniaoPastores;
                          });
                        },
                  child: Text(
                    'Confirmo que a solicitação foi deliberada e homologada na Reunião de Pastores.',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('btnRecusarCoordenadorDetalhe'),
                onPressed: _processandoDecisao ? null : _executarRecusaCoordenador,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                label: const Text('✕ Rejeitar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('btnHomologarCoordenadorDetalhe'),
                onPressed: (_processandoDecisao || !_confirmacaoReuniaoPastores)
                    ? null
                    : _executarHomologacaoCoordenador,
                icon: _processandoDecisao
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check, color: Colors.white, size: 18),
                label: _processandoDecisao
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('✓ Homologar e Ativar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, AppGeometry.minTouchTarget),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

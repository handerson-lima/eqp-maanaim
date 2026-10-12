import 'package:flutter/material.dart';

import '../../ui/components/buttons.dart';
import '../../ui/components/feedback_orientacao_card.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/components/vigencia_badge.dart';
import '../../ui/tokens.dart';
import '../admin/catalogo_service.dart';
import '../termo/pdf_termo_service.dart';
import '../termo/termo_pdf_launcher.dart';
import '../termo/termo_service.dart';
import 'ficha_service.dart';
import 'manifestar_renovacao_dialog.dart';
import 'participacao_service.dart';
import 'solicitar_equipe_modal.dart';

/// Tela S02: Início do Voluntário.
/// Dashboard inicial com visão geral, KPIs por participação, contagem de vigência real,
/// lista "Minhas Equipes", cartões de ação rápida e resposta neutra em decisões negativas.
class InicioVoluntarioScreen extends StatefulWidget {
  const InicioVoluntarioScreen({
    super.key,
    required this.fichaGateway,
    required this.participacaoGateway,
    required this.catalogoGateway,
    this.termoGateway,
    this.pdfTermoGateway,
    this.onNavegarMinhaFicha,
    this.onNavegarRenovacao,
    this.onNavegarSolicitarEquipe,
    this.userName,
    this.dentroDeShell = false,
  });

  final FichaGateway fichaGateway;
  final ParticipacaoGateway participacaoGateway;
  final CatalogoGateway catalogoGateway;
  final TermoGateway? termoGateway;
  final PdfTermoGateway? pdfTermoGateway;
  final VoidCallback? onNavegarMinhaFicha;
  final VoidCallback? onNavegarRenovacao;
  final VoidCallback? onNavegarSolicitarEquipe;
  final String? userName;
  final bool dentroDeShell;

  @override
  State<InicioVoluntarioScreen> createState() => _InicioVoluntarioScreenState();
}

class _InicioVoluntarioScreenState extends State<InicioVoluntarioScreen> {
  bool _carregando = true;
  String? _erroCarregamento;

  FichaModel? _ficha;
  List<ParticipacaoModel> _participacoes = const [];
  List<EquipeCatalogo> _equipesCatalogo = const [];
  String? _baixandoPdfParticipacaoId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });

    try {
      final fichaResp = await widget.fichaGateway.obterMinhaFicha();
      final participacoes = await widget.participacaoGateway.obterMinhasParticipacoes();

      List<EquipeCatalogo> catalogo = const [];
      try {
        final resp = await widget.catalogoGateway.consultar();
        catalogo = resp.equipes;
      } catch (_) {
        catalogo = const [];
      }

      if (!mounted) return;
      setState(() {
        _ficha = fichaResp.existe ? fichaResp.ficha : null;
        _participacoes = participacoes;
        _equipesCatalogo = catalogo;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroCarregamento = 'Não foi possível carregar os dados do início. Tente novamente.';
        _carregando = false;
      });
    }
  }

  ParticipacaoModel? _obterEquipeMaisProximaDoVencimento() {
    final ativas = _participacoes.where((p) => p.isAtiva).toList();
    if (ativas.isEmpty) return null;

    ativas.sort((a, b) {
      final diasA = a.diasParaVencimento ?? 9999;
      final diasB = b.diasParaVencimento ?? 9999;
      return diasA.compareTo(diasB);
    });

    return ativas.first;
  }

  void _abrirModalSolicitacao() {
    if (widget.onNavegarSolicitarEquipe != null) {
      widget.onNavegarSolicitarEquipe!();
      return;
    }
    SolicitarEquipeModal.exibir(
      context: context,
      equipesCatalogo: _equipesCatalogo,
      participacoesAtuais: _participacoes,
      participacaoGateway: widget.participacaoGateway,
      onSucesso: (nova) {
        _carregarDados();
      },
    );
  }

  Future<void> _baixarComprovantePdf(ParticipacaoModel participacao) async {
    final fichaId = _ficha?.id;
    if (fichaId == null || fichaId.isEmpty) return;

    setState(() => _baixandoPdfParticipacaoId = participacao.id);

    try {
      final gateway = widget.pdfTermoGateway ?? FirebasePdfTermoGateway();
      final resultado = await gateway.obterUrlDownloadPdf(
        fichaId: fichaId,
        participacaoId: participacao.id,
      );

      if (!mounted) return;
      baixarOuAbrirPdf(resultado.urlDownload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Comprovante digital indisponível no momento. Tente novamente mais tarde.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _baixandoPdfParticipacaoId = null);
      }
    }
  }

  Future<void> _abrirManifestacaoRenovacao(ParticipacaoModel participacao) async {
    if (widget.onNavegarRenovacao != null) {
      widget.onNavegarRenovacao!();
      return;
    }
    final sucesso = await ManifestarRenovacaoDialog.show(
      context,
      participacoesElegiveis: [participacao],
      participacaoPreSelecionadaId: participacao.id,
      onConfirmar: (manifestacoes) async {
        await widget.participacaoGateway.manifestarRenovacao(manifestacoes: manifestacoes);
      },
    );

    if (sucesso == true && mounted) {
      _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_erroCarregamento != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: FeedbackOrientacaoCard.erro(
            titulo: 'Erro ao carregar dados',
            mensagem: _erroCarregamento!,
            acao: PrimaryButton(
              label: 'Tentar Novamente',
              onPressed: _carregarDados,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.maxWidth;
        final ehDesktop = largura >= 1024;
        final ehTablet = largura >= 600 && largura < 1024;

        final paddingHorizontal = ehDesktop
            ? AppSpacing.s32
            : (ehTablet ? AppSpacing.s24 : AppSpacing.s16);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: paddingHorizontal,
            vertical: AppSpacing.s24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _construirCardEstadoVoluntario(),
                  _construirTopCards(ehDesktop),
                  const SizedBox(height: AppSpacing.s24),
                  _construirSecaoMinhasEquipes(ehDesktop),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirCardEstadoVoluntario() {
    final temRejeitada = _participacoes.any((p) => p.isRejeitada);
    if (temRejeitada) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s24),
        child: FeedbackOrientacaoCard.decisaoDesfavoravel(),
      );
    }

    if (_ficha == null || _ficha!.isRascunho) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s24),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: AppGeometry.cardBorderRadius,
            border: Border.all(
              color: const Color(0xFFBFDBFE),
              width: AppGeometry.borderWidth,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.assignment_ind_outlined,
                color: AppColors.blue600,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      children: const [
                        Text(
                          'Complete seu Cadastro',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy900,
                          ),
                        ),
                        StatusChip(
                          status: 'RASCUNHO',
                          label: 'RASCUNHO',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    const Text(
                      'Sua ficha está em modo rascunho. Para participar das equipes do Maanaim, finalize o preenchimento de seus dados cadastrais, selecione as equipes e confirme o aceite do termo.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    PrimaryButton(
                      label: 'Continuar Cadastro',
                      onPressed: widget.onNavegarMinhaFicha,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_ficha!.estado.contains('AGUARDANDO')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s24),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: AppGeometry.cardBorderRadius,
            border: Border.all(
              color: const Color(0xFFFEDF89),
              width: AppGeometry.borderWidth,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.pending_actions_outlined,
                color: AppColors.warning,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      children: const [
                        Text(
                          'Ficha em Análise e Tramitação',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy900,
                          ),
                        ),
                        StatusChip(
                          status: 'AGUARDANDO',
                          label: 'EM APROVAÇÃO',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Sua ficha foi enviada e está aguardando homologação pelas lideranças responsáveis (${_ficha!.estado.replaceAll('_', ' ')}). Você pode acompanhar o andamento em Minha Ficha.',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    SecondaryButton(
                      label: 'Acompanhar em Minha Ficha',
                      onPressed: widget.onNavegarMinhaFicha,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _construirTopCards(bool ehDesktop) {
    final cardEquipes = _construirCardMinhasEquipesContadores();
    final cardValidade = _construirCardValidadeFicha();

    if (ehDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cardEquipes),
          const SizedBox(width: AppSpacing.s16),
          Expanded(child: cardValidade),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cardEquipes,
        const SizedBox(height: AppSpacing.s12),
        cardValidade,
      ],
    );
  }

  Widget _construirCardMinhasEquipesContadores() {
    final totalAtivas = _participacoes.where((p) => p.isAtiva).length;
    final totalEmAprovacao = _participacoes
        .where((p) => !p.isAtiva && !p.isRejeitada && !p.isRascunho)
        .length;
    final totalRejeitadas = _participacoes.where((p) => p.isRejeitada).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Minhas Equipes',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              _construirIndicadorCol(
                icon: Icons.people_alt_outlined,
                count: totalAtivas,
                label: 'Ativas',
                color: AppColors.success,
                bg: AppColors.successBg,
              ),
              const SizedBox(width: AppSpacing.s8),
              _construirIndicadorCol(
                icon: Icons.access_time,
                count: totalEmAprovacao,
                label: 'Em aprovação',
                color: AppColors.warning,
                bg: AppColors.warningBg,
              ),
              const SizedBox(width: AppSpacing.s8),
              _construirIndicadorCol(
                icon: Icons.cancel_outlined,
                count: totalRejeitadas,
                label: 'Pendentes / Rejeitadas',
                color: const Color(0xFFD32F2F),
                bg: AppColors.dangerBg,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirIndicadorCol({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCardValidadeFicha() {
    final equipeProxima = _obterEquipeMaisProximaDoVencimento();

    String dataVigencia = '31/12/2026';
    String subtituloVigencia = 'Sem equipes ativas';
    double progresso = 0.0;
    Color corSubtitulo = AppColors.textSecondary;

    if (equipeProxima != null) {
      if (equipeProxima.vigenciaFim != null) {
        dataVigencia = VigenciaBadge.formatarData(equipeProxima.vigenciaFim);
      }
      final dias = equipeProxima.diasParaVencimento;
      if (dias != null) {
        subtituloVigencia = dias > 0
            ? 'Faltam $dias ${dias == 1 ? "dia" : "dias"}'
            : (dias == 0 ? 'Vence hoje' : 'Vencida há ${-dias} dias');
        progresso = (dias / 365.0).clamp(0.0, 1.0);
        corSubtitulo = dias <= 30 ? AppColors.warning : AppColors.success;
      } else {
        subtituloVigencia = 'Vigente';
        progresso = 1.0;
        corSubtitulo = AppColors.success;
      }
    } else if (_participacoes.isNotEmpty) {
      subtituloVigencia = 'Em aprovação';
      corSubtitulo = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Validade da Ficha',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.blue600,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dataVigencia,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtituloVigencia,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: corSubtitulo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSecaoMinhasEquipes(bool ehDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            Text(
              'Minhas Equipes',
              style: AppTypography.h3.copyWith(
                color: AppColors.navy900,
                fontWeight: FontWeight.w700,
              ),
            ),
            SecondaryButton(
              label: 'Solicitar Equipe',
              icon: Icons.add,
              onPressed: _abrirModalSolicitacao,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        if (_participacoes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s40,
              horizontal: AppSpacing.s24,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppGeometry.cardBorderRadius,
              border: Border.all(
                color: AppColors.border,
                width: AppGeometry.borderWidth,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.s12),
                const Text(
                  'Você ainda não possui equipes vinculadas.',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(
                  label: 'Escolher Equipes',
                  onPressed: _abrirModalSolicitacao,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _participacoes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, index) {
              final p = _participacoes[index];
              return _construirItemEquipeCard(p, ehDesktop);
            },
          ),
      ],
    );
  }

  Widget _construirItemEquipeCard(ParticipacaoModel p, bool ehDesktop) {
    final emJanela = p.isEmJanelaRenovacao;
    final baixando = _baixandoPdfParticipacaoId == p.id;
    final isAtiva = p.isAtiva;

    final String dataContextual;
    if (isAtiva && p.vigenciaInicio != null) {
      dataContextual =
          'Aprovada em ${VigenciaBadge.formatarData(p.vigenciaInicio)}';
    } else if (p.vigenciaInicio != null) {
      dataContextual =
          'Enviada em ${VigenciaBadge.formatarData(p.vigenciaInicio)}';
    } else {
      dataContextual = isAtiva ? 'Participação ativa' : 'Em tramitação';
    }

    final Widget chipStatus;
    if (isAtiva) {
      chipStatus = const StatusChip(status: 'ATIVA', label: 'ATIVA');
    } else if (p.isRascunho) {
      chipStatus = const StatusChip(status: 'RASCUNHO', label: 'RASCUNHO');
    } else if (p.isRejeitada) {
      chipStatus = const StatusChip(status: 'INATIVA', label: 'FINALIZADA');
    } else {
      chipStatus =
          const StatusChip(status: 'AGUARDANDO', label: 'EM APROVAÇÃO');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAtiva ? AppColors.blue50 : AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAtiva
                      ? Icons.description_outlined
                      : Icons.hourglass_top_outlined,
                  color: isAtiva ? AppColors.blue600 : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.nomeEquipe,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (!ehDesktop) ...[
                      const SizedBox(height: 2),
                      Text(
                        dataContextual,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              chipStatus,
              if (ehDesktop) ...[
                const SizedBox(width: AppSpacing.s24),
                Text(
                  dataContextual,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.s12),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
          if (emJanela || isAtiva) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (emJanela)
                  PrimaryButton(
                    label: 'Renovar Equipe',
                    onPressed: () => _abrirManifestacaoRenovacao(p),
                  ),
                if (emJanela && isAtiva) const SizedBox(width: AppSpacing.s8),
                if (isAtiva)
                  SecondaryButton(
                    label: baixando ? 'Baixando...' : 'Comprovante / PDF',
                    icon: Icons.description_outlined,
                    onPressed: baixando ? null : () => _baixarComprovantePdf(p),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

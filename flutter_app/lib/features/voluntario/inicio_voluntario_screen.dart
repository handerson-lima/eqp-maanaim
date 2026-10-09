import 'package:flutter/material.dart';

import '../../ui/components/buttons.dart';
import '../../ui/components/feedback_orientacao_card.dart';
import '../../ui/components/metrics.dart';
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

  String _obterNomeExibicao() {
    final nomeAuth = widget.userName?.trim();
    if (nomeAuth != null && nomeAuth.isNotEmpty) return nomeAuth;
    final nomeFicha = _ficha?.nomeCompleto.trim();
    if (nomeFicha != null && nomeFicha.isNotEmpty) return nomeFicha;
    return 'Voluntário';
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
      return LayoutBuilder(
        builder: (context, constraints) {
          final largura = constraints.maxWidth;
          final ehDesktop = largura >= 1024;
          final ehTablet = largura >= 600 && largura < 1024;
          final ehMobile = largura < 600;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construirCabecalhoSaudacao(ehMobile),
                    const SizedBox(height: AppSpacing.s32),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.s32),
                        child: CircularProgressIndicator(),
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
        final ehMobile = largura < 600;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _construirCabecalhoSaudacao(ehMobile),
                  const SizedBox(height: AppSpacing.s24),
                  _construirCardEstadoVoluntario(),
                  const SizedBox(height: AppSpacing.s24),
                  _construirKpis(ehDesktop),
                  const SizedBox(height: AppSpacing.s24),
                  if (ehDesktop)
                    _construirLayoutDesktop()
                  else
                    _construirLayoutMobile(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirCabecalhoSaudacao(bool ehMobile) {
    final nome = _obterNomeExibicao();
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : 'V';

    String estadoFicha = 'INATIVA';
    String rotuloEstado = 'NÃO INICIADA';

    if (_ficha != null) {
      if (_ficha!.isAtiva) {
        estadoFicha = 'ATIVA';
        rotuloEstado = 'ATIVA';
      } else if (_ficha!.isRascunho) {
        estadoFicha = 'RASCUNHO';
        rotuloEstado = 'RASCUNHO';
      } else if (_ficha!.estado.contains('AGUARDANDO')) {
        estadoFicha = 'EM_APROVACAO';
        rotuloEstado = 'EM APROVAÇÃO';
      } else {
        estadoFicha = _ficha!.estado;
        rotuloEstado = _ficha!.estado.replaceAll('_', ' ');
      }
    }

    final subtitulo = _ficha?.isAtiva == true
        ? 'Voluntariado ativo no Maanaim'
        : (_ficha == null || _ficha!.isRascunho
            ? 'Ficha em modo rascunho: complete seus dados para atuar'
            : (_ficha?.estado.contains('AGUARDANDO') == true
                ? 'Sua solicitação de voluntariado está em tramitação'
                : 'Portal de Gestão de Voluntários do Maanaim'));

    if (ehMobile) {
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
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.blue50,
                  child: Text(
                    inicial,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    'Olá, $nome',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                StatusChip(
                  status: estadoFicha,
                  label: rotuloEstado,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              subtitulo,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.blue50,
            child: Text(
              inicial,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.blue600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $nome',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  subtitulo,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          StatusChip(
            status: estadoFicha,
            label: rotuloEstado,
          ),
        ],
      ),
    );
  }

  Widget _construirCardEstadoVoluntario() {
    final temRejeitada = _participacoes.any((p) => p.isRejeitada);
    if (temRejeitada) {
      return FeedbackOrientacaoCard.decisaoDesfavoravel();
    }

    if (_ficha == null || _ficha!.isRascunho) {
      return Container(
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
                  const Text(
                    'Complete seu Cadastro',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy900,
                    ),
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
      );
    }

    if (_ficha!.estado.contains('AGUARDANDO')) {
      return Container(
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
                  const Text(
                    'Ficha em Análise e Tramitação',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy900,
                    ),
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
      );
    }

    return const SizedBox.shrink();
  }

  Widget _construirKpis(bool ehDesktop) {
    final totalAtivas = _participacoes.where((p) => p.isAtiva).length;
    final equipeProxima = _obterEquipeMaisProximaDoVencimento();

    String proxVencimentoValor = '-';
    String proxVencimentoSub = 'Nenhuma equipe ativa';
    MetricVariant proxVencimentoVariant = MetricVariant.neutral;

    if (equipeProxima != null) {
      final dias = equipeProxima.diasParaVencimento;
      if (dias != null) {
        proxVencimentoValor = '$dias ${dias == 1 ? "dia" : "dias"}';
        proxVencimentoSub = 'Equipe: ${equipeProxima.nomeEquipe}';
        proxVencimentoVariant = dias <= 30
            ? MetricVariant.warning
            : (dias <= 0 ? MetricVariant.danger : MetricVariant.primary);
      } else if (equipeProxima.vigenciaFim != null) {
        proxVencimentoValor = VigenciaBadge.formatarData(equipeProxima.vigenciaFim);
        proxVencimentoSub = 'Equipe: ${equipeProxima.nomeEquipe}';
        proxVencimentoVariant = MetricVariant.primary;
      }
    }

    final termoAceito = _ficha?.termoAceito != null;
    final kpiTermoValor = termoAceito ? 'Vigente' : 'Pendente';
    final kpiTermoSub = termoAceito ? 'Aceite registrado' : 'Necessário para ativação';
    final kpiTermoVariant = termoAceito ? MetricVariant.success : MetricVariant.warning;

    final cards = [
      MetricCard(
        title: 'Equipes Ativas',
        value: '$totalAtivas',
        icon: Icons.groups_outlined,
        variant: MetricVariant.primary,
        subtitle: totalAtivas > 0 ? 'Participações vigentes' : 'Sem equipes no momento',
      ),
      MetricCard(
        title: 'Próxima Renovação',
        value: proxVencimentoValor,
        icon: Icons.event_outlined,
        variant: proxVencimentoVariant,
        subtitle: proxVencimentoSub,
      ),
      MetricCard(
        title: 'Termo de Adesão',
        value: kpiTermoValor,
        icon: termoAceito ? Icons.verified_outlined : Icons.pending_actions_outlined,
        variant: kpiTermoVariant,
        subtitle: kpiTermoSub,
      ),
    ];

    if (ehDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: AppSpacing.s16),
          Expanded(child: cards[1]),
          const SizedBox(width: AppSpacing.s16),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: AppSpacing.s12),
        cards[1],
        const SizedBox(height: AppSpacing.s12),
        cards[2],
      ],
    );
  }

  Widget _construirLayoutDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 65,
          child: _construirSecaoMinhasEquipes(),
        ),
        const SizedBox(width: AppSpacing.s24),
        Expanded(
          flex: 35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _construirCardValidadeDestaque(),
              const SizedBox(height: AppSpacing.s24),
              _construirSecaoAcoesRapidas(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirLayoutMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _construirCardValidadeDestaque(),
        const SizedBox(height: AppSpacing.s24),
        _construirSecaoMinhasEquipes(),
        const SizedBox(height: AppSpacing.s24),
        _construirSecaoAcoesRapidas(),
      ],
    );
  }

  Widget _construirCardValidadeDestaque() {
    final equipeProxima = _obterEquipeMaisProximaDoVencimento();
    if (equipeProxima == null || equipeProxima.vigenciaFim == null) {
      return const SizedBox.shrink();
    }

    final dias = equipeProxima.diasParaVencimento ?? 365;
    final double progresso = (dias / 365.0).clamp(0.0, 1.0);

    return ProgressValidityCard(
      title: 'Vigência - ${equipeProxima.nomeEquipe}',
      expirationDateText: 'Vencimento: ${VigenciaBadge.formatarData(equipeProxima.vigenciaFim)}',
      daysRemaining: dias,
      progress: progresso,
      action: equipeProxima.isEmJanelaRenovacao
          ? PrimaryButton(
              label: 'Renovar',
              onPressed: () => _abrirManifestacaoRenovacao(equipeProxima),
            )
          : null,
    );
  }

  Widget _construirSecaoMinhasEquipes() {
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
                vertical: AppSpacing.s32,
                horizontal: AppSpacing.s16,
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
              separatorBuilder: (_, __) => const Divider(
                color: AppColors.border,
                height: AppSpacing.s24,
              ),
              itemBuilder: (context, index) {
                final p = _participacoes[index];
                return _construirItemEquipe(p);
              },
            ),
        ],
      ),
    );
  }

  Widget _construirItemEquipe(ParticipacaoModel p) {
    final emJanela = p.isEmJanelaRenovacao;
    final baixando = _baixandoPdfParticipacaoId == p.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nomeEquipe,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (p.ciclo.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Ciclo: ${p.ciclo}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (p.isAtiva)
              VigenciaBadge(
                vigenciaInicio: p.vigenciaInicio,
                vigenciaFim: p.vigenciaFim,
                situacaoVigencia: p.situacaoVigencia,
                diasParaVencimento: p.diasParaVencimento,
                alertaVigencia: p.alertaVigencia,
                compact: true,
              )
            else if (p.isRascunho)
              const StatusChip(
                status: 'RASCUNHO',
                label: 'RASCUNHO',
              )
            else if (p.isRejeitada)
              const StatusChip(
                status: 'INATIVA',
                label: 'FINALIZADA',
              )
            else
              const StatusChip(
                status: 'AGUARDANDO',
                label: 'EM APROVAÇÃO',
              ),
          ],
        ),
        if (p.isAtiva && (p.vigenciaInicio != null || p.vigenciaFim != null)) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Período: ${VigenciaBadge.formatarData(p.vigenciaInicio)} até ${VigenciaBadge.formatarData(p.vigenciaFim)}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            if (emJanela)
              PrimaryButton(
                label: 'Renovar Equipe',
                onPressed: () => _abrirManifestacaoRenovacao(p),
              ),
            if (p.isAtiva)
              SecondaryButton(
                label: baixando ? 'Baixando...' : 'Comprovante / PDF',
                icon: Icons.description_outlined,
                onPressed: baixando ? null : () => _baixarComprovantePdf(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _construirSecaoAcoesRapidas() {
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
        children: [
          Text(
            'Ações Rápidas',
            style: AppTypography.h3.copyWith(
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          _construirCardAcao(
            icon: Icons.person_outline,
            titulo: 'Minha Ficha',
            descricao: 'Consulte ou altere dados cadastrais e aceite do termo',
            onTap: widget.onNavegarMinhaFicha,
          ),
          const SizedBox(height: AppSpacing.s12),
          _construirCardAcao(
            icon: Icons.group_add_outlined,
            titulo: 'Solicitar Nova Equipe',
            descricao: 'Adicione participação em equipe do catálogo',
            onTap: _abrirModalSolicitacao,
          ),
          const SizedBox(height: AppSpacing.s12),
          _construirCardAcao(
            icon: Icons.sync_outlined,
            titulo: 'Renovação Anual',
            descricao: 'Acompanhe períodos e manifeste interesse',
            onTap: widget.onNavegarRenovacao ??
                () {
                  final ativas = _participacoes.where((p) => p.isAtiva).toList();
                  if (ativas.isNotEmpty) {
                    _abrirManifestacaoRenovacao(ativas.first);
                  } else {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Nenhuma participação ativa no momento para renovação.'),
                      ),
                    );
                  }
                },
          ),
        ],
      ),
    );
  }

  Widget _construirCardAcao({
    required IconData icon,
    required String titulo,
    required String descricao,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          border: Border.all(
            color: AppColors.border,
            width: AppGeometry.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.blue50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.blue600, size: 20),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

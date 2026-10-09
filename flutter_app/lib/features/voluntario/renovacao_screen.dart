import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/stepper.dart';
import '../../ui/components/vigencia_badge.dart';
import '../../ui/tokens.dart';
import 'participacao_service.dart';

/// Tela S10: Renovação de Participação em Superfície Única com Revisão (Story 8.9).
///
/// Substitui o antigo empilhamento de diálogos sobre diálogos (ManifestarRenovacaoDialog)
/// por um fluxo estruturado no Shell em 3 etapas com AppStepper:
/// 1. Escolhas por Equipe (escolha explícita CONTINUAR vs NAO_CONTINUAR, sem defaults silenciosos, com retomada)
/// 2. Revisão das Manifestações (resumo segregado de quem continua e quem encerra com avisos de consequência)
/// 3. Envio e Resultados (submissão atômica transacional com commandId idempotente, retry seguro e desfechos autorizados)
class RenovacaoScreen extends StatefulWidget {
  const RenovacaoScreen({
    super.key,
    this.participacaoGateway,
    this.participacoesIniciais,
    this.participacaoPreSelecionadaId,
    this.onVoltar,
    this.onIrParaInicio,
    this.onIrParaMinhaFicha,
    this.dentroDeShell = false,
  });

  final ParticipacaoGateway? participacaoGateway;
  final List<ParticipacaoModel>? participacoesIniciais;
  final String? participacaoPreSelecionadaId;
  final VoidCallback? onVoltar;
  final VoidCallback? onIrParaInicio;
  final VoidCallback? onIrParaMinhaFicha;
  final bool dentroDeShell;

  @override
  State<RenovacaoScreen> createState() => _RenovacaoScreenState();
}

class _RenovacaoScreenState extends State<RenovacaoScreen> {
  int _etapaAtual = 0;
  bool _carregandoInicial = true;
  String? _erroCarregamento;

  List<ParticipacaoModel> _participacoes = [];
  // Mapa de participacaoId -> 'CONTINUAR' | 'NAO_CONTINUAR' | null
  // Nenhuma ausência de escolha é tratada como "CONTINUAR" por padrão.
  final Map<String, String?> _decisoes = {};

  // Estado do envio (Etapa 2)
  bool _enviando = false;
  String? _erroEnvio;
  String? _ultimoCommandId;
  List<Map<String, dynamic>> _resultados = [];

  static const List<StepperEtapa> _etapas = [
    StepperEtapa(
      titulo: 'Escolhas por Equipe',
      subtitulo: 'Defina a continuidade',
      icone: Icons.how_to_vote_outlined,
    ),
    StepperEtapa(
      titulo: 'Revisão',
      subtitulo: 'Verifique consequências',
      icone: Icons.fact_check_outlined,
    ),
    StepperEtapa(
      titulo: 'Confirmação',
      subtitulo: 'Envio e desfechos',
      icone: Icons.verified_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  Future<void> _inicializarDados() async {
    setState(() {
      _carregandoInicial = true;
      _erroCarregamento = null;
    });

    try {
      List<ParticipacaoModel> lista = [];
      if (widget.participacoesIniciais != null) {
        lista = List.of(widget.participacoesIniciais!);
      } else if (widget.participacaoGateway != null) {
        lista = await widget.participacaoGateway!.obterMinhasParticipacoes();
      }

      // Filtra participações elegíveis à renovação: ativas em janela de renovação
      // ou aquelas que foram pré-selecionadas ou já manifestadas nesta vigência
      final elegiveis = lista.where((p) {
        if (!p.isAtiva) return false;
        if (p.id == widget.participacaoPreSelecionadaId) return true;
        return p.isEmJanelaRenovacao || p.isRenovacaoManifestada;
      }).toList();

      // Inicializa mapa de decisões respeitando retomadas persistidas (sem default silencioso)
      for (final p in elegiveis) {
        if (p.intencaoRenovacao != null && p.intencaoRenovacao!.isNotEmpty) {
          _decisoes[p.id] = p.intencaoRenovacao;
        } else {
          _decisoes[p.id] = null; // Decisão ainda não tomada
        }
      }

      if (mounted) {
        setState(() {
          _participacoes = elegiveis;
          _carregandoInicial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroCarregamento = 'Não foi possível carregar as equipes para renovação. Tente novamente.';
          _carregandoInicial = false;
        });
      }
    }
  }

  bool get _todasEscolhasPreenchidas {
    if (_participacoes.isEmpty) return false;
    return _participacoes.every((p) => _decisoes[p.id] != null);
  }

  List<ParticipacaoModel> get _equipesContinuam =>
      _participacoes.where((p) => _decisoes[p.id] == 'CONTINUAR').toList();

  List<ParticipacaoModel> get _equipesEncerram =>
      _participacoes.where((p) => _decisoes[p.id] == 'NAO_CONTINUAR').toList();

  void _avancarParaRevisao() {
    if (!_todasEscolhasPreenchidas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecione sua escolha (Continuar ou Não continuar) para todas as equipes listadas.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _etapaAtual = 1;
    });
  }

  void _voltarParaEscolhas() {
    setState(() {
      _etapaAtual = 0;
    });
  }

  Future<void> _submeterManifestacao({bool retry = false}) async {
    if (_enviando) return;

    final commandId = (retry && _ultimoCommandId != null)
        ? _ultimoCommandId!
        : comandoOpaco();

    setState(() {
      _etapaAtual = 2;
      _enviando = true;
      _erroEnvio = null;
      _ultimoCommandId = commandId;
    });

    final manifestacoes = _participacoes.map((p) {
      final dec = _decisoes[p.id] ?? 'CONTINUAR';
      return ManifestacaoEquipeInput(
        participacaoId: p.id,
        decisao: dec,
      );
    }).toList();

    try {
      if (widget.participacaoGateway == null) {
        throw Exception('Gateway de participações não disponível.');
      }

      final resposta = await widget.participacaoGateway!.manifestarRenovacao(
        manifestacoes: manifestacoes,
        commandId: commandId,
      );

      if (mounted) {
        setState(() {
          _enviando = false;
          _resultados = resposta;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('janela')
            ? 'A janela de renovação para uma ou mais equipes foi encerrada.'
            : 'Ocorreu um erro ao processar a manifestação de renovação. Você pode tentar novamente com segurança.';
        setState(() {
          _enviando = false;
          _erroEnvio = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.maxWidth;
        final ehDesktop = largura >= 1024;
        final ehTablet = largura >= 600 && largura < 1024;
        final paddingHorizontal = ehDesktop
            ? AppSpacing.s32
            : (ehTablet ? AppSpacing.s24 : AppSpacing.s16);

        Widget conteudo;
        if (_carregandoInicial) {
          conteudo = _buildCarregando();
        } else if (_erroCarregamento != null) {
          conteudo = _buildErroCarregamento();
        } else if (_participacoes.isEmpty) {
          conteudo = _buildNenhumaElegivel();
        } else {
          conteudo = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stepper guiado responsivo
              AppStepper(
                etapas: _etapas,
                etapaAtual: _etapaAtual,
                onEtapaTap: (etapa) {
                  // Só permite voltar para etapa anterior pelo stepper
                  if (etapa < _etapaAtual && !_enviando && _resultados.isEmpty) {
                    setState(() => _etapaAtual = etapa);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s24),

              // Conteúdo da etapa
              if (_etapaAtual == 0)
                _buildEtapaEscolhas(ehDesktop)
              else if (_etapaAtual == 1)
                _buildEtapaRevisao(ehDesktop)
              else
                _buildEtapaEnvioResultados(ehDesktop),
            ],
          );
        }

        final corpo = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: paddingHorizontal,
            vertical: AppSpacing.s24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCabecalho(context),
                  const SizedBox(height: AppSpacing.s24),
                  conteudo,
                ],
              ),
            ),
          ),
        );

        if (widget.dentroDeShell) {
          return corpo;
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Renovação de Ciclo Anual'),
            backgroundColor: AppColors.navy900,
            foregroundColor: Colors.white,
            leading: widget.onVoltar != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar',
                    onPressed: widget.onVoltar,
                  )
                : null,
          ),
          body: corpo,
        );
      },
    );
  }

  Widget _buildCabecalho(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.onVoltar != null && widget.dentroDeShell)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.navy900),
                  tooltip: 'Voltar ao Início',
                  onPressed: widget.onVoltar,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Renovação de Participação',
                    style: AppTypography.h1.copyWith(
                      color: AppColors.navy900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Manifeste seu interesse de continuidade no próximo ciclo anual de forma individual e inequívoca por equipe.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.s32),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.blue600),
            SizedBox(height: AppSpacing.s16),
            Text(
              'Carregando suas equipes e janelas de renovação...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErroCarregamento() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: AppSpacing.s16),
          Text(
            _erroCarregamento ?? 'Erro ao carregar equipes.',
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            label: 'Tentar Novamente',
            icon: Icons.refresh,
            onPressed: _inicializarDados,
          ),
        ],
      ),
    );
  }

  Widget _buildNenhumaElegivel() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48, color: AppColors.blue600),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Nenhuma equipe elegível para renovação no momento',
            style: AppTypography.h2.copyWith(
              color: AppColors.navy900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'A janela de renovação de ciclo anual é aberta para equipes ativas a partir de 60 dias antes do término de sua vigência. Quando o período chegar, você poderá manifestar seu interesse aqui.',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          PrimaryButton(
            label: 'Voltar ao Início',
            icon: Icons.home_outlined,
            onPressed: widget.onIrParaInicio ??
                widget.onVoltar ??
                () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
          ),
        ],
      ),
    );
  }

  // --- ETAPA 0: ESCOLHAS POR EQUIPE ---
  Widget _buildEtapaEscolhas(bool ehDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instrução e aviso de escolha obrigatória
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info, color: AppColors.blue600, size: 22),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  'A renovação deve ser manifestada individualmente para cada equipe. '
                  'Escolha se deseja continuar ou encerrar ao término da vigência. '
                  'Nenhuma decisão é assumida automaticamente.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.navy900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),

        // Lista de cards das equipes
        ..._participacoes.map((p) => _buildCardEscolhaEquipe(p, ehDesktop)),

        const SizedBox(height: AppSpacing.s24),

        // Barra de Ações inferior
        _buildBarraAcoesEscolhas(),
      ],
    );
  }

  Widget _buildCardEscolhaEquipe(ParticipacaoModel p, bool ehDesktop) {
    final decisaoAtual = _decisoes[p.id];
    final temDecisaoPersistida = p.intencaoRenovacao != null && p.intencaoRenovacao!.isNotEmpty;

    return Container(
      key: Key('card_renovacao_${p.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(
          color: decisaoAtual != null ? AppColors.blue600 : AppColors.border,
          width: decisaoAtual != null ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Topo do Card: Nome da Equipe e Badge de Vigência
            ehDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nomeEquipe,
                              style: AppTypography.h3.copyWith(
                                color: AppColors.navy900,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Vigência atual: ${VigenciaBadge.formatarData(p.vigenciaInicio)} até ${VigenciaBadge.formatarData(p.vigenciaFim)}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      VigenciaBadge(
                        vigenciaInicio: p.vigenciaInicio,
                        vigenciaFim: p.vigenciaFim,
                        situacaoVigencia: p.situacaoVigencia,
                        diasParaVencimento: p.diasParaVencimento,
                        alertaVigencia: p.alertaVigencia,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nomeEquipe,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.navy900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Vigência atual: ${VigenciaBadge.formatarData(p.vigenciaInicio)} até ${VigenciaBadge.formatarData(p.vigenciaFim)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      VigenciaBadge(
                        vigenciaInicio: p.vigenciaInicio,
                        vigenciaFim: p.vigenciaFim,
                        situacaoVigencia: p.situacaoVigencia,
                        diasParaVencimento: p.diasParaVencimento,
                        alertaVigencia: p.alertaVigencia,
                        compact: true,
                      ),
                    ],
                  ),

            if (temDecisaoPersistida) ...[
              const SizedBox(height: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Registro anterior: ${p.intencaoRenovacao == 'CONTINUAR' ? 'Continuar' : 'Não continuar'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const Divider(height: AppSpacing.s24, color: AppColors.border),

            // Pergunta de escolha explícita
            Semantics(
              label: 'Opções de renovação para ${p.nomeEquipe}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sua intenção para o próximo ciclo:',
                    style: AppTypography.label.copyWith(
                      color: AppColors.navy900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // Botões de Rádio / Opções de Decisão Acessíveis (>= 44px)
                  ehDesktop
                      ? Row(
                          children: [
                            Expanded(
                              child: _buildBotaoEscolha(
                                participacaoId: p.id,
                                valor: 'CONTINUAR',
                                label: 'Continuar no próximo ciclo',
                                icone: Icons.check_circle_outline,
                                selecionado: decisaoAtual == 'CONTINUAR',
                                corAtiva: AppColors.blue600,
                                bgAtivo: AppColors.blue50,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(
                              child: _buildBotaoEscolha(
                                participacaoId: p.id,
                                valor: 'NAO_CONTINUAR',
                                label: 'Não continuar (encerrar vigência)',
                                icone: Icons.highlight_off,
                                selecionado: decisaoAtual == 'NAO_CONTINUAR',
                                corAtiva: AppColors.danger,
                                bgAtivo: AppColors.dangerBg,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildBotaoEscolha(
                              participacaoId: p.id,
                              valor: 'CONTINUAR',
                              label: 'Continuar no próximo ciclo',
                              icone: Icons.check_circle_outline,
                              selecionado: decisaoAtual == 'CONTINUAR',
                              corAtiva: AppColors.blue600,
                              bgAtivo: AppColors.blue50,
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            _buildBotaoEscolha(
                              participacaoId: p.id,
                              valor: 'NAO_CONTINUAR',
                              label: 'Não continuar (encerrar vigência)',
                              icone: Icons.highlight_off,
                              selecionado: decisaoAtual == 'NAO_CONTINUAR',
                              corAtiva: AppColors.danger,
                              bgAtivo: AppColors.dangerBg,
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoEscolha({
    required String participacaoId,
    required String valor,
    required String label,
    required IconData icone,
    required bool selecionado,
    required Color corAtiva,
    required Color bgAtivo,
  }) {
    final keySuffix = valor == 'CONTINUAR' ? 'continuar' : 'nao_continuar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('btn_${keySuffix}_$participacaoId'),
        borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
        onTap: () {
          setState(() {
            _decisoes[participacaoId] = valor;
          });
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: AppGeometry.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: selecionado ? bgAtivo : AppColors.surface,
            borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            border: Border.all(
              color: selecionado ? corAtiva : AppColors.borderInteractive,
              width: selecionado ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selecionado ? (valor == 'CONTINUAR' ? Icons.check_circle : Icons.cancel) : icone,
                color: selecionado ? corAtiva : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: selecionado ? AppColors.navy900 : AppColors.textPrimary,
                    fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarraAcoesEscolhas() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.onVoltar != null || widget.onIrParaInicio != null)
          SecondaryButton(
            key: const Key('btn_cancelar_renovacao'),
            label: 'Voltar ao Início',
            icon: Icons.arrow_back,
            onPressed: widget.onVoltar ?? widget.onIrParaInicio,
          )
        else
          const SizedBox.shrink(),
        PrimaryButton(
          key: const Key('btn_avancar_revisao'),
          label: 'Avançar para Revisão',
          icon: Icons.arrow_forward,
          onPressed: _todasEscolhasPreenchidas ? _avancarParaRevisao : null,
        ),
      ],
    );
  }

  // --- ETAPA 1: REVISÃO DAS DECISÕES ---
  Widget _buildEtapaRevisao(bool ehDesktop) {
    final continuam = _equipesContinuam;
    final encerram = _equipesEncerram;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card de introdução da revisão
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revise suas manifestações antes de confirmar',
                style: AppTypography.h2.copyWith(
                  color: AppColors.navy900,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Confira abaixo o resumo de cada equipe e as consequências correspondentes.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),

        // BLOCO 1: CONTINUAM
        if (continuam.isNotEmpty) ...[
          _buildBlocoRevisaoContinuam(continuam),
          const SizedBox(height: AppSpacing.s20),
        ],

        // BLOCO 2: ENCERRAM
        if (encerram.isNotEmpty) ...[
          _buildBlocoRevisaoEncerram(encerram),
          const SizedBox(height: AppSpacing.s20),
        ],

        // Ações de Revisão: Voltar para Escolhas ou Confirmar Envio
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SecondaryButton(
              key: const Key('btn_voltar_escolhas'),
              label: 'Voltar para Escolhas',
              icon: Icons.arrow_back,
              onPressed: _voltarParaEscolhas,
            ),
            PrimaryButton(
              key: const Key('btn_confirmar_envio_manifestacao'),
              label: 'Confirmar e Enviar',
              icon: Icons.send,
              onPressed: () => _submeterManifestacao(retry: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlocoRevisaoContinuam(List<ParticipacaoModel> equipes) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.blue600, size: 24),
              const SizedBox(width: AppSpacing.s12),
              Text(
                'Equipes para Renovação (${equipes.length})',
                style: AppTypography.h3.copyWith(
                  color: AppColors.navy900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Você manifestou interesse em continuar servindo nas seguintes equipes no próximo ciclo:',
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s12),
          ...equipes.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.nomeEquipe,
                    style: AppTypography.body.copyWith(
                      color: AppColors.navy900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Continuar',
                    style: TextStyle(
                      color: AppColors.blue600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.blue600),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Consequência: A participação ingressará no processo de aprovação de ciclo anual e aguardará parecer do Pastor Local.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.navy900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocoRevisaoEncerram(List<ParticipacaoModel> equipes) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.danger),
      ),
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
              const SizedBox(width: AppSpacing.s12),
              Text(
                'Equipes para Encerramento (${equipes.length})',
                style: AppTypography.h3.copyWith(
                  color: AppColors.navy900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Você optou por não renovar as seguintes participações:',
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s12),
          ...equipes.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.nomeEquipe,
                    style: AppTypography.body.copyWith(
                      color: AppColors.navy900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Encerra em ${VigenciaBadge.formatarData(p.vigenciaFim)}',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Consequência: Você continuará servindo até o final da vigência atual. Após o vencimento, sua participação será concluída. Nenhuma de suas demais equipes será afetada.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.navy900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ETAPA 2: ENVIO E RESULTADOS ---
  Widget _buildEtapaEnvioResultados(bool ehDesktop) {
    if (_enviando) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppColors.blue600),
              const SizedBox(height: AppSpacing.s20),
              Text(
                'Registrando sua manifestação de renovação...',
                style: AppTypography.h2.copyWith(
                  color: AppColors.navy900,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Processamento atômico seguro em andamento.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_erroEnvio != null) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Falha no envio da manifestação',
              style: AppTypography.h2.copyWith(
                color: AppColors.navy900,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _erroEnvio!,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SecondaryButton(
                  label: 'Voltar para Revisão',
                  onPressed: () => setState(() => _etapaAtual = 1),
                ),
                const SizedBox(width: AppSpacing.s16),
                PrimaryButton(
                  key: const Key('btn_tentar_novamente_envio'),
                  label: 'Tentar Novamente',
                  icon: Icons.refresh,
                  onPressed: () => _submeterManifestacao(retry: true),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Sucesso / Apresentação dos desfechos autorizados
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Manifestação Registrada com Sucesso!',
            style: AppTypography.h1.copyWith(
              color: AppColors.navy900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Sua manifestação foi processada de forma segura e atômica.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s24),

          // Lista de resultados autorizados por equipe
          ..._participacoes.map((p) {
            final decisao = _decisoes[p.id];
            final ehContinuar = decisao == 'CONTINUAR';

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s12),
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: ehContinuar ? AppColors.blue50 : AppColors.surface,
                borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                border: Border.all(
                  color: ehContinuar ? AppColors.blue600 : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    ehContinuar ? Icons.autorenew : Icons.schedule,
                    color: ehContinuar ? AppColors.blue600 : AppColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nomeEquipe,
                          style: AppTypography.body.copyWith(
                            color: AppColors.navy900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ehContinuar
                              ? 'Ingressou no ciclo anual: aguardando parecer do Pastor Local.'
                              : 'Encerramento programado para o término da vigência em ${VigenciaBadge.formatarData(p.vigenciaFim)}.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            ),
            child: Text(
              'A manifestação expressa o seu interesse e não promete renovação automática. Acompanhe a tramitação pelo Início ou por Minha Ficha.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          // Botões de conclusão e navegação autorizada
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.onIrParaMinhaFicha != null) ...[
                SecondaryButton(
                  key: const Key('btn_ver_minha_ficha'),
                  label: 'Ver Minha Ficha',
                  icon: Icons.person_outline,
                  onPressed: widget.onIrParaMinhaFicha,
                ),
                const SizedBox(width: AppSpacing.s16),
              ],
              PrimaryButton(
                key: const Key('btn_ir_para_inicio'),
                label: 'Ir para o Início',
                icon: Icons.home,
                onPressed: widget.onIrParaInicio ?? widget.onVoltar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/components/app_shell.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/components/vigencia_badge.dart';
import '../../ui/tokens.dart';
import '../../ui/components/cpf_formatter.dart';
import '../admin/catalogo_service.dart';
import '../auth/validadores.dart';
import '../termo/termo_service.dart';
import '../termo/pdf_termo_service.dart';
import '../termo/termo_pdf_launcher.dart';
import '../termo/pdf_preview_panel.dart';
import 'ficha_service.dart';
import 'consulta_ficha_screen.dart';
import 'historico_service.dart';
import 'linha_tempo_widget.dart';
import 'participacao_service.dart';
import 'solicitar_equipe_modal.dart';
import 'cancelar_participacao_dialog.dart';
import 'cancelar_voluntariado_dialog.dart';
import 'solicitar_reativacao_dialog.dart';
import 'manifestar_renovacao_dialog.dart';
import '../privacidade/politica_privacidade_card.dart';
import '../perfil/editar_perfil_screen.dart';

/// Tela responsiva mobile-first para o voluntário preencher e manter sua ficha cadastral permanente.
class MinhaFichaScreen extends StatefulWidget {
  const MinhaFichaScreen({
    super.key,
    required this.fichaGateway,
    required this.catalogoGateway,
    this.participacaoGateway,
    this.termoGateway,
    this.pdfTermoGateway,
    this.historicoService,
    this.onSair,
    this.userName,
    this.dentroDeShell = false,
  });

  final FichaGateway fichaGateway;
  final CatalogoGateway catalogoGateway;
  final ParticipacaoGateway? participacaoGateway;
  final TermoGateway? termoGateway;
  final PdfTermoGateway? pdfTermoGateway;
  final HistoricoService? historicoService;
  final VoidCallback? onSair;
  final String? userName;
  final bool dentroDeShell;

  @override
  State<MinhaFichaScreen> createState() => _MinhaFichaScreenState();
}

class _MinhaFichaScreenState extends State<MinhaFichaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _profissaoController = TextEditingController();
  final _cpfController = TextEditingController();
  final _buscaEquipeController = TextEditingController();

  String? _igrejaSelecionadaId;
  FichaModel? _ficha;
  List<IgrejaCatalogo> _igrejas = const [];
  List<EquipeCatalogo> _equipes = const [];
  List<ParticipacaoModel> _participacoes = const [];
  Set<String> _equipesSelecionadasIds = {};

  bool _carregando = true;
  bool _salvando = false;
  bool _salvandoEquipes = false;
  bool _salvandoTermo = false;
  bool _declaracaoConcordancia = false;
  TermoVigenteModel? _termoVigente;
  String? _erroCarregamento;
  String? _mensagemSucesso;
  String? _erroSalvar;
  String? _mensagemSucessoEquipes;
  String? _erroEquipes;
  String? _mensagemSucessoTermo;
  String? _erroTermo;
  bool _enviando = false;
  String? _mensagemSucessoEnvio;
  String? _erroEnvio;

  late final HistoricoService _historicoService;
  List<EventoLinhaDoTempoModel> _eventosHistorico = [];
  bool _carregandoEventos = false;
  String? _baixandoPdfParticipacaoId;
  bool _modoEdicao = false;
  ParticipacaoModel? _participacaoSelecionada;

  bool get _isRascunho => _ficha?.isRascunho ?? true;
  bool get _isAguardandoPastor => _ficha?.estado == 'AGUARDANDO_PASTOR_LOCAL';
  bool get _isBloqueadoParaEdicao => !_isRascunho;

  String _obterSubtituloHeader() {
    if (_ficha?.estado == 'ATIVA') {
      return 'Voluntariado homologado e ativo no Maanaim.';
    }
    if (_ficha?.estado == 'REJEITADA') {
      return _mensagemNegativaVoluntario;
    }
    if (_ficha?.estado == 'AGUARDANDO_COORDENADOR') {
      return 'Aguardando homologação final do Coordenador Geral.';
    }
    if (_ficha?.estado == 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
      return 'Em análise pelos Responsáveis de Equipe.';
    }
    if (_isAguardandoPastor) {
      return 'Ficha enviada para avaliação do Pastor Local.';
    }
    return 'Acesso realizado. Sua ficha pode continuar em rascunho.';
  }

  Widget _obterActionHeader() {
    if (_ficha?.estado == 'ATIVA') {
      return const StatusChip(status: 'ATIVA', label: 'Ativa');
    }
    if (_ficha?.estado == 'REJEITADA') {
      return const StatusChip(status: 'INATIVA', label: 'Consulte o Pastor');
    }
    if (_ficha?.estado == 'AGUARDANDO_COORDENADOR') {
      return const StatusChip(status: 'AGUARDANDO', label: 'Aguardando Coordenador');
    }
    if (_ficha?.estado == 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
      return const StatusChip(status: 'AGUARDANDO', label: 'Aguardando Equipes');
    }
    if (_isAguardandoPastor) {
      return const StatusChip(status: 'AGUARDANDO_PASTOR_LOCAL', label: 'Aguardando Pastor Local');
    }
    return StatusChip(status: _ficha?.estado ?? 'RASCUNHO');
  }

  /// Mensagem neutra canônica do voluntário. Prefere o valor projetado pelo
  /// servidor (`mensagemVoluntario`) e só recorre ao literal como fallback.
  String get _mensagemNegativaVoluntario =>
      _ficha?.mensagemVoluntario ?? mensagemNeutraCanonica;

  @override
  void initState() {
    super.initState();
    _historicoService = widget.historicoService ?? HistoricoService();
    _nomeController.addListener(_aoMudarCampos);
    _profissaoController.addListener(_aoMudarCampos);
    _cpfController.addListener(_aoMudarCampos);
    _buscaEquipeController.addListener(_aoMudarCampos);
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.removeListener(_aoMudarCampos);
    _profissaoController.removeListener(_aoMudarCampos);
    _cpfController.removeListener(_aoMudarCampos);
    _buscaEquipeController.removeListener(_aoMudarCampos);
    _nomeController.dispose();
    _profissaoController.dispose();
    _cpfController.dispose();
    _buscaEquipeController.dispose();
    super.dispose();
  }

  void _aoMudarCampos() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });

    try {
      final partGateway = widget.participacaoGateway;
      final termoGateway = widget.termoGateway;
      final resultados = await Future.wait([
        widget.fichaGateway.obterMinhaFicha(),
        widget.catalogoGateway.consultar(),
        if (partGateway != null)
          partGateway.obterMinhasParticipacoes()
        else
          Future.value(<ParticipacaoModel>[]),
        if (termoGateway != null)
          termoGateway.obterTermoVigente().catchError((_) => null)
        else
          Future.value(null),
      ]);

      final respostaFicha = resultados[0] as ObterFichaResposta;
      final respostaCatalogo = resultados[1] as CatalogoResposta;
      final participacoes = resultados[2] as List<ParticipacaoModel>;
      final termoVigente = resultados[3] as TermoVigenteModel?;

      final igrejasAtivas = respostaCatalogo.igrejas
          .where((i) => i.ativo)
          .toList(growable: false);
      final equipesAtivas = respostaCatalogo.equipes
          .where((e) => e.ativo)
          .toList(growable: false);

      if (mounted) {
        setState(() {
          _igrejas = igrejasAtivas;
          _equipes = equipesAtivas;
          _participacoes = participacoes;
          _equipesSelecionadasIds = participacoes
              .where((p) => p.isRascunho)
              .map((p) => p.equipeId)
              .toSet();
          _ficha = respostaFicha.ficha;
          _termoVigente = termoVigente;

          if (respostaFicha.ficha != null) {
            final f = respostaFicha.ficha!;
            _nomeController.text = f.nomeCompleto;
            _profissaoController.text = f.profissao;
            _cpfController.text = f.cpf;
            if (f.igrejaId.isNotEmpty &&
                igrejasAtivas.any((i) => i.id == f.igrejaId)) {
              _igrejaSelecionadaId = f.igrejaId;
            } else if (f.igrejaId.isNotEmpty) {
              _igrejaSelecionadaId = f.igrejaId;
            }
            _modoEdicao = f.nomeCompleto.isEmpty;
          } else {
            _modoEdicao = true;
          }

          if (participacoes.isNotEmpty) {
            if (_participacaoSelecionada == null ||
                !participacoes.any((p) => p.id == _participacaoSelecionada!.id)) {
              _participacaoSelecionada = participacoes.cast<ParticipacaoModel?>().firstWhere(
                (p) => p?.isAtiva == true,
                orElse: () => participacoes.first,
              );
            } else {
              _participacaoSelecionada = participacoes.firstWhere(
                (p) => p.id == _participacaoSelecionada!.id,
              );
            }
          } else {
            _participacaoSelecionada = null;
          }
          _carregando = false;
        });

        if (respostaFicha.ficha != null && !respostaFicha.ficha!.isRascunho) {
          try {
            setState(() {
              _carregandoEventos = true;
            });
            final ev = await _historicoService.consultarLinhaDoTempoAutorizada();
            if (mounted) {
              setState(() {
                _eventosHistorico = ev;
                _carregandoEventos = false;
              });
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _carregandoEventos = false;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erroCarregamento =
              'Não foi possível carregar os dados da ficha. Tente novamente.';
        });
      }
    }
  }

  Future<void> _salvarEquipes() async {
    setState(() {
      _salvandoEquipes = true;
      _erroEquipes = null;
      _mensagemSucessoEquipes = null;
    });

    try {
      final gateway = widget.participacaoGateway;
      if (gateway != null) {
        final novas = await gateway.salvarParticipacoesRascunho(
          _equipesSelecionadasIds.toList(),
        );
        if (mounted) {
          setState(() {
            _participacoes = novas;
            _equipesSelecionadasIds = novas
                .where((p) => p.isRascunho)
                .map((p) => p.equipeId)
                .toSet();
            _salvandoEquipes = false;
            _mensagemSucessoEquipes = 'Equipes de rascunho salvas com sucesso.';
          });
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Equipes de rascunho salvas com sucesso.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _salvandoEquipes = false;
            _mensagemSucessoEquipes = 'Equipes salvas em rascunho.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final erroMsg = e.toString().contains('Ficha permanente não encontrada')
            ? 'Preencha e salve a ficha antes de selecionar as equipes.'
            : e.toString().contains('Equipe inválida')
                ? 'Uma das equipes selecionadas é inválida ou está inativa.'
                : 'Não foi possível salvar as equipes. Tente novamente.';
        setState(() {
          _salvandoEquipes = false;
          _erroEquipes = erroMsg;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(erroMsg),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _salvarFicha() async {
    setState(() {
      _erroSalvar = null;
      _mensagemSucesso = null;
    });

    final nome = _nomeController.text.trim();
    final profissao = _profissaoController.text.trim();
    final cpf = _cpfController.text.trim();
    final igrejaId = _igrejaSelecionadaId?.trim() ?? '';

    // Validações básicas de cliente antes do envio
    if (nome.length < 3) {
      setState(() => _erroSalvar = 'Informe o nome completo (mínimo 3 caracteres).');
      return;
    }
    if (profissao.length < 2) {
      setState(() => _erroSalvar = 'Informe a profissão (mínimo 2 caracteres).');
      return;
    }
    final erroCpf = cpfValido(cpf);
    if (erroCpf != null) {
      setState(() => _erroSalvar = erroCpf);
      return;
    }
    if (igrejaId.isEmpty) {
      setState(() => _erroSalvar = 'Selecione a igreja local onde você congrega.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final commandId = comandoOpaco();
      final entrada = SalvarFichaEntrada(
        commandId: commandId,
        nomeCompleto: nome,
        profissao: profissao,
        cpf: cpf,
        igrejaId: igrejaId,
        expectedVersion: _ficha?.versao,
      );

      final resposta = await widget.fichaGateway.salvarMinhaFicha(entrada);

      if (mounted) {
        setState(() {
          _ficha = resposta.ficha;
          _salvando = false;
          _modoEdicao = false;
          _mensagemSucesso = 'Ficha salva com sucesso.';
        });

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Ficha salva com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final mensagem = e.toString().contains('CPF inválido')
            ? 'CPF inválido. Verifique os dígitos informados.'
            : e.toString().contains('Igreja inválida')
                ? 'Igreja inválida ou inativa.'
                : 'Não foi possível salvar a ficha. Verifique os dados e tente novamente.';

        setState(() {
          _salvando = false;
          _erroSalvar = mensagem;
        });

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = const [
      AppNavItem(
        label: 'Minha Ficha',
        icon: Icons.badge_outlined,
        selectedIcon: Icons.badge,
      ),
    ];

    final estadoExibicao = _ficha?.estado == 'REJEITADA'
        ? null
        : (_ficha?.estado ?? 'RASCUNHO');

    final String? nomeValidoFicha =
        (_ficha?.nomeCompleto.isNotEmpty == true &&
                !_ficha!.nomeCompleto.contains('@') &&
                _ficha!.nomeCompleto.toLowerCase() != 'voluntário')
            ? _ficha!.nomeCompleto
            : null;

    final String? nomeValidoWidget =
        (widget.userName != null &&
                widget.userName!.isNotEmpty &&
                !widget.userName!.contains('@') &&
                widget.userName!.toLowerCase() != 'voluntário')
            ? widget.userName
            : null;

    final String nomeExibicao =
        nomeValidoFicha ?? nomeValidoWidget ?? 'Voluntário';

    final corpo = _carregando
        ? SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: 'Minha Ficha',
                      subtitle:
                          'Acesso realizado. Sua ficha pode continuar em rascunho.',
                      action: _obterActionHeader(),
                    ),
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
          )
        : _erroCarregamento != null
            ? ErrorState(
                title: 'Erro ao carregar ficha',
                message: _erroCarregamento!,
                onRetry: _carregarDados,
              )
            : _buildConteudo();

    if (widget.dentroDeShell) {
      return Container(
        color: AppColors.background,
        child: corpo,
      );
    }

    return AppShell(
      items: navItems,
      selectedIndex: 0,
      onLogout: widget.onSair,
      userName: nomeExibicao,
      userRole: 'Voluntário',
      userStatus: estadoExibicao,
      topBarActions: [
        IconButton(
          tooltip: 'Editar Perfil',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EditarPerfilScreen(
                nomeInicial: nomeValidoFicha ?? nomeValidoWidget,
                telefoneInicial: _ficha?.telefone,
                onVoltar: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Consulta autorizada da ficha e histórico',
          icon: const Icon(Icons.manage_search_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConsultaFichaAutorizadaScreen(
                historicoService: _historicoService,
                userName: widget.userName,
                onVoltar: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
      ],
      body: corpo,
    );
  }

  Widget _buildConteudo() {
    final pendencias = calcularPendenciasFicha(
      nomeCompleto: _nomeController.text,
      profissao: _profissaoController.text,
      cpf: _cpfController.text,
      igrejaId: _igrejaSelecionadaId ?? '',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da página
              PageHeader(
                title: 'Minha Ficha',
                subtitle: _obterSubtituloHeader(),
                action: _obterActionHeader(),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Banner de pendências ou status de aprovação
              _buildBannerStatus(pendencias),
              const SizedBox(height: AppSpacing.s20),

              // Mensagens de sucesso ou erro
              if (_mensagemSucesso != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _mensagemSucesso!,
                          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              if (_erroSalvar != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _erroSalvar!,
                          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 1024;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCardDadosCadastrais(),
                              if (_participacoes.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.s24),
                                _buildCardSeletorParticipacao(),
                              ],
                              const SizedBox(height: AppSpacing.s24),
                              _buildSecaoEquipes(),
                              const SizedBox(height: AppSpacing.s24),
                              _buildSecaoTermo(),
                              const SizedBox(height: AppSpacing.s24),
                              _buildSecaoEnvioAprovacao(pendencias),
                              if (!_isRascunho || _eventosHistorico.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.s24),
                                _buildSecaoHistorico(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s24),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_participacoes.isNotEmpty)
                                PdfPreviewPanel(
                                  key: Key('preview_pdf_desktop_${_participacaoSelecionada?.id}'),
                                  fichaId: _ficha?.id ?? '',
                                  participacao: _participacaoSelecionada,
                                  pdfTermoGateway: widget.pdfTermoGateway,
                                  nomeVoluntario: _ficha?.nomeCompleto,
                                  alturaMinima: 480,
                                )
                              else
                                _buildPreviewPlaceholderVazio(),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCardDadosCadastrais(),
                      if (_participacoes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s20),
                        _buildCardSeletorParticipacao(),
                        const SizedBox(height: AppSpacing.s20),
                        PdfPreviewPanel(
                          key: Key('preview_pdf_mobile_${_participacaoSelecionada?.id}'),
                          fichaId: _ficha?.id ?? '',
                          participacao: _participacaoSelecionada,
                          pdfTermoGateway: widget.pdfTermoGateway,
                          nomeVoluntario: _ficha?.nomeCompleto,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s24),
                      _buildSecaoEquipes(),
                      const SizedBox(height: AppSpacing.s24),
                      _buildSecaoTermo(),
                      const SizedBox(height: AppSpacing.s24),
                      _buildSecaoEnvioAprovacao(pendencias),
                      if (!_isRascunho || _eventosHistorico.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s24),
                        _buildSecaoHistorico(),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardDadosCadastrais() {
    if (_ficha != null && !_modoEdicao) {
      return _buildResumoDadosCadastrais();
    }
    return _buildFormularioDadosCadastrais();
  }

  Widget _buildResumoDadosCadastrais() {
    final nomeIgreja = _obterNomeIgreja(_ficha!.igrejaId);

    return SectionCard(
      title: 'Dados Cadastrais',
      subtitle: _isBloqueadoParaEdicao
          ? 'Dados cadastrais bloqueados para edição durante o processo de avaliação.'
          : 'Consulte seus dados cadastrais permanentes no Maanaim.',
      headerAction: _isBloqueadoParaEdicao
          ? null
          : OutlinedButton.icon(
              key: const Key('btn_editar_dados'),
              onPressed: () => setState(() => _modoEdicao = true),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar dados'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: AppColors.navy900,
                side: const BorderSide(color: AppColors.navy900),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLinhaInfo('Nome Completo', _ficha!.nomeCompleto),
          _buildLinhaInfo('Profissão', _ficha!.profissao),
          _buildLinhaInfo(
            'CPF',
            _ficha!.cpf,
            destaqueMonospaced: true,
          ),
          if (nomeIgreja != null)
            _buildLinhaInfo('Igreja Local', nomeIgreja),
          _buildLinhaInfo('Versão da Ficha', 'v${_ficha!.versao}'),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Versão: ${_ficha!.versao}',
                style: AppTypography.caption,
              ),
              if (_ficha!.atualizadoEm != null)
                Flexible(
                  child: Text(
                    'Última alteração: ${_formatarData(_ficha!.atualizadoEm!)}',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioDadosCadastrais() {
    return SectionCard(
      title: 'Dados Cadastrais',
      subtitle: _isBloqueadoParaEdicao
          ? 'Dados cadastrais bloqueados para edição durante o processo de avaliação.'
          : 'Campos marcados são obrigatórios para emissão do termo e aprovação.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nome Completo', style: AppTypography.label),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              key: const Key('campo_nome_completo'),
              controller: _nomeController,
              readOnly: _isBloqueadoParaEdicao,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Seu nome completo',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            Text('Profissão', style: AppTypography.label),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              key: const Key('campo_profissao'),
              controller: _profissaoController,
              readOnly: _isBloqueadoParaEdicao,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Sua ocupação principal (ex: Marceneiro, Advogado)',
                prefixIcon: Icon(Icons.work_outline, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            Text('CPF', style: AppTypography.label),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              key: const Key('campo_cpf'),
              controller: _cpfController,
              readOnly: _isBloqueadoParaEdicao,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [CpfInputFormatter()],
              decoration: const InputDecoration(
                hintText: '000.000.000-00',
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            Text('Igreja Local', style: AppTypography.label),
            const SizedBox(height: AppSpacing.s4),
            DropdownButtonFormField<String>(
              key: const Key('campo_igreja'),
              initialValue: _igrejaSelecionadaId,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Selecione a sua igreja',
                prefixIcon: Icon(Icons.church_outlined, size: 20),
              ),
              items: _igrejas
                  .map(
                    (igreja) => DropdownMenuItem(
                      value: igreja.id,
                      child: Text(
                        igreja.rotulo,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isBloqueadoParaEdicao
                  ? null
                  : (novoId) {
                      setState(() {
                        _igrejaSelecionadaId = novoId;
                      });
                    },
            ),
            const SizedBox(height: AppSpacing.s24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_ficha != null) ...[
                  OutlinedButton(
                    key: const Key('btn_cancelar_edicao'),
                    onPressed: () {
                      setState(() {
                        _modoEdicao = false;
                        _nomeController.text = _ficha!.nomeCompleto;
                        _profissaoController.text = _ficha!.profissao;
                        _cpfController.text = _ficha!.cpf;
                        _igrejaSelecionadaId = _ficha!.igrejaId;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                ],
                PrimaryButton(
                  key: const Key('botao_salvar_ficha'),
                  label: 'Salvar Ficha',
                  icon: Icons.save_outlined,
                  isLoading: _salvando,
                  onPressed: (_isBloqueadoParaEdicao || _salvando)
                      ? null
                      : _salvarFicha,
                ),
              ],
            ),
            if (_ficha != null) ...[
              const SizedBox(height: AppSpacing.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Versão: ${_ficha!.versao}',
                    style: AppTypography.caption,
                  ),
                  if (_ficha!.atualizadoEm != null)
                    Flexible(
                      child: Text(
                        'Última alteração: ${_formatarData(_ficha!.atualizadoEm!)}',
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardSeletorParticipacao() {
    if (_participacoes.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Documento por Participação (AD-13)',
      subtitle:
          'Selecione a equipe desejada para consultar o termo probatório específico gerado no servidor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Equipe Selecionada', style: AppTypography.label),
          const SizedBox(height: AppSpacing.s8),
          DropdownButtonFormField<String>(
            key: const Key('seletor_participacao_equipe'),
            initialValue: _participacaoSelecionada?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.groups_outlined, size: 20),
            ),
            items: _participacoes.map((p) {
              final eq = _equipes.cast<EquipeCatalogo?>().firstWhere(
                    (e) => e?.id == p.equipeId,
                    orElse: () => null,
                  );
              final nome = p.nomeEquipe.isNotEmpty
                  ? p.nomeEquipe
                  : (eq?.nome ?? p.equipeId);
              final statusTexto = p.isAtiva ? 'Aprovada' : p.estado;
              return DropdownMenuItem<String>(
                value: p.id,
                child: Text(
                  '$nome ($statusTexto)',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (novoId) {
              if (novoId == null) return;
              setState(() {
                _participacaoSelecionada =
                    _participacoes.firstWhere((p) => p.id == novoId);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPlaceholderVazio() {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: AppSpacing.s16),
            Text(
              'Nenhum documento disponível',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy900,
              ),
            ),
            SizedBox(height: AppSpacing.s8),
            Text(
              'Ao cadastrar equipes e obter aprovação, os termos probatórios individuais estarão disponíveis aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoHistorico() {
    return SectionCard(
      title: 'Linha do Tempo e Histórico',
      subtitle:
          'Acompanhamento cronológico dos marcos e decisões do seu voluntariado.',
      child: LinhaDoTempoWidget(
        eventos: _eventosHistorico,
        isLoading: _carregandoEventos,
        tituloSecao: '',
      ),
    );
  }

  String? _obterNomeIgreja(String? id) {
    if (id == null || id.isEmpty) return null;
    final match = _igrejas.cast<IgrejaCatalogo?>().firstWhere(
          (i) => i?.id == id,
          orElse: () => null,
        );
    return match?.rotulo ?? match?.nome ?? id;
  }

  Widget _buildLinhaInfo(String rotulo, String valor, {bool destaqueMonospaced = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              rotulo,
              style: AppTypography.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: destaqueMonospaced
                  ? AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    )
                  : AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoEquipes() {
    final termo = normalizarBusca(_buscaEquipeController.text);
    final equipesFiltradas = _equipes.where((e) {
      if (termo.isEmpty) return true;
      return normalizarBusca(e.nome).contains(termo);
    }).toList();

    return SectionCard(
      title: 'Equipes de Interesse',
      subtitle:
          'Selecione as equipes em que deseja servir. Suas escolhas ficam salvas como rascunho.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mensagemSucessoEquipes != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _mensagemSucessoEquipes!,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          if (_erroEquipes != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _erroEquipes!,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          Text('Buscar Equipes', style: AppTypography.label),
          const SizedBox(height: AppSpacing.s4),
          TextField(
            key: const Key('campo_busca_equipes'),
            controller: _buscaEquipeController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Pesquise pelo nome da equipe...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Equipes Disponíveis',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (equipesFiltradas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Text(
                'Nenhuma equipe encontrada.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: equipesFiltradas.map((equipe) {
                final isSelecionada = _equipesSelecionadasIds.contains(equipe.id);
                return FilterChip(
                  key: Key('chip_equipe_${equipe.id}'),
                  label: Text(equipe.nome),
                  selected: isSelecionada,
                  selectedColor: const Color(0xFFEFF6FF),
                  checkmarkColor: AppColors.blue600,
                  labelStyle: AppTypography.body.copyWith(
                    color: isSelecionada ? AppColors.blue600 : AppColors.textPrimary,
                    fontWeight: isSelecionada ? FontWeight.w600 : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                    side: BorderSide(
                      color: isSelecionada ? AppColors.blue600 : AppColors.border,
                    ),
                  ),
                  onSelected: _isBloqueadoParaEdicao
                      ? null
                      : (selecionado) {
                          setState(() {
                            if (selecionado) {
                              _equipesSelecionadasIds.add(equipe.id);
                            } else {
                              _equipesSelecionadasIds.remove(equipe.id);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          const SizedBox(height: AppSpacing.s24),
          const Divider(color: AppColors.border),
          const SizedBox(height: AppSpacing.s16),
          Text(
            _isBloqueadoParaEdicao ? 'Acompanhamento por Equipe' : 'Participações no Rascunho',
            style: AppTypography.h3,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _isBloqueadoParaEdicao
                ? 'Situação individual de cada equipe solicitada e vigência anual.'
                : 'Cada equipe selecionada gera uma participação independente.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (_ficha?.estado == 'ATIVA') ...[
            const SizedBox(height: AppSpacing.s12),
            Align(
              alignment: Alignment.centerLeft,
              child: PrimaryButton(
                key: const Key('btn_solicitar_nova_equipe'),
                label: 'Solicitar Nova Equipe',
                icon: Icons.add_circle_outline,
                onPressed: _abrirModalSolicitarEquipe,
              ),
            ),
          ],
          if (_participacoes.any((p) => p.isEmJanelaRenovacao)) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              key: const Key('banner_renovacao_disponivel'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.autorenew_rounded, color: AppColors.blue600, size: 24),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Renovação Anual Disponível',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.navy900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Você possui participações com renovação aberta. Indique se deseja continuar servindo no próximo ano.',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  ElevatedButton(
                    key: const Key('btn_abrir_renovacao_banner'),
                    onPressed: () => _abrirModalRenovacao(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Renovar'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          if (_isBloqueadoParaEdicao && _participacoes.isNotEmpty) ...[
            Column(
              children: _participacoes.map((p) {
                final eqId = p.equipeId;
                final equipe = _equipes.cast<EquipeCatalogo?>().firstWhere(
                      (e) => e?.id == eqId,
                      orElse: () => null,
                    );
                final nomeEquipe = p.nomeEquipe.isNotEmpty
                    ? p.nomeEquipe
                    : (equipe?.nome ?? eqId);

                if (p.isAtiva) {
                  return Container(
                    key: Key('card_participacao_${p.id}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nomeEquipe,
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            const StatusChip(status: 'ATIVA', label: 'Ativa'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.neutral100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Ciclo: ${p.ciclo}',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                p.proximaAcao,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (p.vigenciaInicio != null && p.vigenciaFim != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: AppColors.blue600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Vigência: ${_formatarDataApenas(p.vigenciaInicio)} até ${_formatarDataApenas(p.vigenciaFim)}',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (p.emAlertaRenovacao || p.situacaoVigencia != null || p.diasParaVencimento != null) ...[
                          const SizedBox(height: AppSpacing.s4),
                          VigenciaBadge(
                            key: Key('badge_vigencia_${p.id}'),
                            vigenciaInicio: p.vigenciaInicio,
                            vigenciaFim: p.vigenciaFim,
                            situacaoVigencia: p.situacaoVigencia,
                            diasParaVencimento: p.diasParaVencimento,
                            alertaVigencia: p.alertaVigencia,
                            compact: true,
                          ),
                        ],
                        if (p.isRenovacaoManifestada) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.intencaoRenovacao == 'CONTINUAR'
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: p.intencaoRenovacao == 'CONTINUAR'
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              p.intencaoRenovacao == 'CONTINUAR'
                                  ? 'Renovação manifestada: Continuar'
                                  : 'Encerramento programado ao término da vigência',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: p.intencaoRenovacao == 'CONTINUAR'
                                    ? AppColors.blue600
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s4,
                          children: [
                            OutlinedButton.icon(
                              key: Key('btn_baixar_termo_pdf_${p.id}'),
                              onPressed: _baixandoPdfParticipacaoId == p.id
                                  ? null
                                  : () => _baixarTermoPdf(p),
                              icon: _baixandoPdfParticipacaoId == p.id
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.blue600,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 16,
                                      color: AppColors.blue600,
                                    ),
                              label: Text(
                                _baixandoPdfParticipacaoId == p.id
                                    ? 'Gerando documento...'
                                    : 'Baixar Termo em PDF',
                                style: const TextStyle(
                                  color: AppColors.blue600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                side: const BorderSide(color: AppColors.blue600),
                              ),
                            ),
                            if (p.isEmJanelaRenovacao)
                              TextButton.icon(
                                key: Key('btn_renovar_participacao_${p.id}'),
                                onPressed: () => _abrirModalRenovacao(participacaoEspecifica: p),
                                icon: const Icon(Icons.autorenew_rounded, size: 16, color: AppColors.blue600),
                                label: Text(
                                  p.isRenovacaoManifestada ? 'Alterar Renovação' : 'Manifestar Renovação',
                                  style: const TextStyle(
                                    color: AppColors.blue600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            TextButton.icon(
                              key: Key('btn_cancelar_participacao_${p.id}'),
                              onPressed: () => _abrirModalCancelarParticipacao(p),
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                              label: const Text(
                                'Cancelar Participação',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                if (p.isRejeitada) {
                  return Container(
                    key: Key('card_participacao_${p.id}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nomeEquipe,
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            const StatusChip(
                              status: 'INATIVA',
                              label: 'Informação',
                              showDot: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.neutral150,
                            borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppColors.navy800),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  p.proximaAcao,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            key: Key('btn_solicitar_reativacao_${p.id}'),
                            onPressed: () => _abrirModalSolicitarReativacao(p),
                            icon: const Icon(Icons.replay_rounded, size: 16, color: AppColors.blue600),
                            label: const Text(
                              'Solicitar Reativação',
                              style: TextStyle(
                                color: AppColors.blue600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: const BorderSide(color: AppColors.blue600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final statusChipLabel = p.estado == 'AGUARDANDO_PASTOR_LOCAL'
                    ? 'Aguardando Pastor Local'
                    : p.estado == 'AGUARDANDO_RESPONSAVEL_EQUIPE'
                        ? 'Aguardando Responsável'
                        : p.estado == 'AGUARDANDO_COORDENADOR'
                            ? 'Aguardando Coordenador'
                            : p.estado == 'RASCUNHO'
                                ? 'Rascunho'
                                : 'Em análise';

                return Container(
                  key: Key('card_participacao_${p.id}'),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nomeEquipe,
                              style: AppTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          StatusChip(
                            status: p.estado,
                            label: statusChipLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ciclo: ${p.ciclo}',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              p.proximaAcao,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (p.isCancelada || p.isExpirada || p.isInativa) ...[
                        const SizedBox(height: AppSpacing.s8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            key: Key('btn_solicitar_reativacao_${p.id}'),
                            onPressed: () => _abrirModalSolicitarReativacao(p),
                            icon: const Icon(Icons.replay_rounded, size: 16, color: AppColors.blue600),
                            label: const Text(
                              'Solicitar Reativação',
                              style: TextStyle(
                                color: AppColors.blue600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: const BorderSide(color: AppColors.blue600),
                            ),
                          ),
                        ),
                      ],
                      if (!p.isTerminal) ...[
                        const SizedBox(height: AppSpacing.s8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: Key('btn_cancelar_participacao_${p.id}'),
                            onPressed: () => _abrirModalCancelarParticipacao(p),
                            icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                            label: const Text(
                              'Cancelar Solicitação',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
            if (_ficha?.estado == 'ATIVA' ||
                (_isBloqueadoParaEdicao &&
                    _ficha?.estado != 'CANCELADA' &&
                    _ficha?.estado != 'REJEITADA')) ...[
              const SizedBox(height: AppSpacing.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('btn_cancelar_voluntariado'),
                  onPressed: _abrirModalCancelarVoluntariado,
                  icon: const Icon(Icons.person_off_outlined, size: 18, color: AppColors.danger),
                  label: const Text(
                    'Encerrar Voluntariado',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(160, 44),
                  ),
                ),
              ),
            ],
          ] else if (_equipesSelecionadasIds.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      'Nenhuma equipe selecionada ainda. Marque uma ou mais equipes acima para adicionar ao seu rascunho.',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _equipesSelecionadasIds.map((eqId) {
                final equipe = _equipes.cast<EquipeCatalogo?>().firstWhere(
                      (e) => e?.id == eqId,
                      orElse: () => null,
                    );
                final nomeEquipe = equipe?.nome ?? eqId;
                final statusExibicao = _isAguardandoPastor ? 'AGUARDANDO_PASTOR_LOCAL' : 'RASCUNHO';
                final proximaAcaoExibicao = _isAguardandoPastor
                    ? 'Aguardando avaliação do Pastor Local'
                    : 'Aguardando envio da ficha';

                return Container(
                  key: Key('card_participacao_$eqId'),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    nomeEquipe,
                                    style: AppTypography.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                StatusChip(status: statusExibicao),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.neutral100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Ciclo: INICIAL',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Text(
                                    proximaAcaoExibicao,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_isBloqueadoParaEdicao) ...[
                        const SizedBox(width: AppSpacing.s8),
                        IconButton(
                          key: Key('botao_remover_equipe_$eqId'),
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          tooltip: 'Remover $nomeEquipe',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: () {
                            setState(() {
                              _equipesSelecionadasIds.remove(eqId);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: AppSpacing.s24),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              key: const Key('botao_salvar_equipes'),
              label: 'Salvar Equipes',
              icon: Icons.save_outlined,
              isLoading: _salvandoEquipes,
              onPressed: (_isBloqueadoParaEdicao || _salvandoEquipes) ? null : _salvarEquipes,
            ),
          ),
        ],
      ),
    );
  }

  String _formatarDataApenas(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    try {
      // A vigência é definida pelo servidor em UTC; formata-se em UTC para não
      // deslocar o dia do ciclo anual em fusos negativos.
      final dt = DateTime.parse(iso).toUtc();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year.toString();
      return '$dia/$mes/$ano';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildBannerStatus(List<String> pendencias) {
    // Os estados pós-envio (ATIVA, REJEITADA e AGUARDANDO_*) são apresentados
    // em `_buildSecaoEnvioAprovacao` ("Status da Solicitação"). O banner fica
    // restrito ao rascunho para não duplicar conteúdo nem anúncios de leitor
    // de tela.
    if (!_isRascunho) {
      return const SizedBox.shrink();
    }
    return _buildBannerPendencias(pendencias);
  }

  Widget _buildBannerPendencias(List<String> pendencias) {
    if (pendencias.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 22),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ficha pronta para avanço',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Todos os campos obrigatórios foram preenchidos. Você pode salvar suas alterações e prosseguir para escolha de equipes e termo.',
                    style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 22),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campos pendentes para avanço futuro:',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309), // âmbar escuro acessível
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                ...pendencias.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFFB45309))),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Você pode salvar como rascunho a qualquer momento e continuar depois.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year.toString();
      final hora = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$ano $hora:$min';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _aceitarTermo() async {
    final gateway = widget.termoGateway;
    if (gateway == null) {
      setState(() {
        _erroTermo = 'Serviço de termos indisponível.';
      });
      return;
    }

    if (_termoVigente == null) {
      setState(() {
        _erroTermo = 'Nenhum termo vigente carregado para aceite.';
      });
      return;
    }

    if (!_declaracaoConcordancia) {
      setState(() {
        _erroTermo =
            'É obrigatório declarar leitura e concordância antes de registrar o aceite.';
      });
      return;
    }

    setState(() {
      _salvandoTermo = true;
      _erroTermo = null;
      _mensagemSucessoTermo = null;
    });

    try {
      final commandId = comandoOpaco();
      final comprovante = await gateway.aceitarTermoVigente(
        commandId: commandId,
        versaoId: _termoVigente!.id,
        hashSha256: _termoVigente!.hashSha256,
        declaracaoLidoEConcordo: true,
      );

      if (mounted) {
        setState(() {
          _mensagemSucessoTermo =
              'Aceite eletrônico registrado com sucesso na versão ${_termoVigente!.numeroVersao}!';
          if (_ficha != null) {
            _ficha = _ficha!.copyWith(
              termoAceito: TermoAceitoModel(
                termoId: comprovante.termoId,
                versaoId: comprovante.versaoId,
                numeroVersao: comprovante.numeroVersao,
                hashSha256: comprovante.hashSha256,
                titulo: comprovante.titulo,
                aceitoEm: comprovante.aceitoEm,
                commandId: comprovante.commandId,
              ),
            );
          }
          _declaracaoConcordancia = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroTermo = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvandoTermo = false;
        });
      }
    }
  }

  Widget _buildSecaoTermo() {
    final fichaSalva = _ficha != null;
    final temEquipes = _participacoes.isNotEmpty;
    final aptoParaTermo = fichaSalva && temEquipes;

    return SectionCard(
      title: 'Termo de Adesão ao Serviço Voluntário',
      subtitle:
          'Leitura obrigatória e aceite eletrônico auditável antes do envio da solicitação.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PoliticaPrivacidadeCard(),
          const SizedBox(height: AppSpacing.s16),
          if (!aptoParaTermo)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.navy800, size: 22),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Etapa bloqueada',
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          !fichaSalva
                              ? 'Complete e salve sua ficha permanente para habilitar o Termo de Adesão.'
                              : 'Selecione e salve ao menos uma equipe de interesse acima para habilitar o aceite do termo.',
                          style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (_mensagemSucessoTermo != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _mensagemSucessoTermo!,
                        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

            if (_erroTermo != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _erroTermo!,
                        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

            _buildEstadoTermo(),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoTermo() {
    final aceite = _ficha?.termoAceito;
    final versaoVigente = _termoVigente;
    final temAceiteVigente =
        aceite != null && versaoVigente != null && aceite.versaoId == versaoVigente.id;
    final temAceiteDesatualizado =
        aceite != null && versaoVigente != null && aceite.versaoId != versaoVigente.id;

    if (temAceiteVigente) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppColors.success, size: 24),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Termo Aceito e Válido',
                    style: AppTypography.h3.copyWith(
                      fontSize: 16,
                      color: AppColors.success,
                    ),
                  ),
                ),
                StatusChip(
                  status: 'APROVADO',
                  label: 'Versão ${aceite.numeroVersao}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Você aceitou eletronicamente a versão vigente do Termo de Adesão ao Serviço Voluntário.',
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.s8),
            _buildLinhaComprovante('Data do Aceite', _formatarData(aceite.aceitoEm)),
            _buildLinhaComprovante('Versão do Termo', 'Versão ${aceite.numeroVersao}'),
            _buildLinhaComprovante(
              'Hash SHA-256',
              aceite.hashSha256.length >= 16
                  ? '${aceite.hashSha256.substring(0, 8)}...${aceite.hashSha256.substring(aceite.hashSha256.length - 8)}'
                  : aceite.hashSha256,
              tooltip: aceite.hashSha256,
            ),
            _buildLinhaComprovante('Recibo / Comando', aceite.commandId),
            const SizedBox(height: AppSpacing.s16),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                SecondaryButton(
                  key: const Key('botao_visualizar_termo_aceito'),
                  label: 'Visualizar Termo Completo',
                  icon: Icons.description_outlined,
                  onPressed: _abrirTermo,
                ),
                SecondaryButton(
                  key: const Key('botao_historico_aceites'),
                  label: 'Histórico de Aceites',
                  icon: Icons.history_outlined,
                  onPressed: _abrirHistoricoAceites,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (temAceiteDesatualizado) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nova versão do termo publicada',
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Você aceitou anteriormente a Versão ${aceite.numeroVersao}. Uma nova versão (Versão ${versaoVigente.numeroVersao}) foi publicada e requer sua leitura e novo aceite para prosseguir com o envio.',
                        style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
        ],

        if (versaoVigente == null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 24),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    'Nenhum termo de adesão vigente publicado no momento. Entre em contato com a administração.',
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          )
        else
          // Card com resumo e leitura do termo
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description_outlined, color: AppColors.navy900, size: 24),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            versaoVigente.titulo,
                            style: AppTypography.label.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            'Versão ${versaoVigente.numeroVersao} (Vigente)',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.blue600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SecondaryButton(
                      key: const Key('botao_ler_termo_completo'),
                      label: 'Ler Termo',
                      icon: Icons.menu_book_outlined,
                      onPressed: _abrirTermo,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  versaoVigente.conteudo.length > 200
                      ? '${versaoVigente.conteudo.substring(0, 200)}...'
                      : versaoVigente.conteudo,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s16),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.s8),

                // Checkbox explícito de leitura e concordância (WCAG 2.2 AA touch target >= 44px)
                Material(
                  type: MaterialType.transparency,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.navy900;
                          }
                          return Colors.transparent;
                        }),
                      ),
                    ),
                    child: CheckboxListTile(
                      key: const Key('checkbox_declaracao_termo'),
                      value: _declaracaoConcordancia,
                      onChanged: (_salvandoTermo || _isBloqueadoParaEdicao)
                          ? null
                          : (val) {
                              setState(() {
                                _declaracaoConcordancia = val ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Declaro expressamente que li na íntegra e concordo com todas as condições do Termo de Adesão ao Serviço Voluntário (Versão ${versaoVigente.numeroVersao}).',
                        style: AppTypography.body.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                Align(
                  alignment: Alignment.centerRight,
                  child: PrimaryButton(
                    key: const Key('botao_aceitar_termo'),
                    label: 'Registrar Aceite Eletrônico',
                    icon: Icons.check_circle_outline,
                    isLoading: _salvandoTermo,
                    onPressed: (!_declaracaoConcordancia || _salvandoTermo || _isBloqueadoParaEdicao)
                        ? null
                        : _aceitarTermo,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLinhaComprovante(String rotulo, String valor, {String? tooltip}) {
    final textWidget = Text(
      valor,
      style: AppTypography.body.copyWith(
        fontWeight: FontWeight.w600,
        fontFamily: rotulo.contains('Hash') ? 'monospace' : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: tooltip != null
                ? Tooltip(message: tooltip, child: textWidget)
                : textWidget,
          ),
        ],
      ),
    );
  }

  void _abrirModalSolicitarEquipe() {
    final gateway = widget.participacaoGateway;
    if (gateway == null) return;

    SolicitarEquipeModal.exibir(
      context: context,
      equipesCatalogo: _equipes,
      participacoesAtuais: _participacoes,
      participacaoGateway: gateway,
      onSucesso: (novaPart) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.surface),
                SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text('Solicitação enviada com sucesso! A equipe está em análise.'),
                ),
              ],
            ),
          ),
        );
        await _carregarDados();
      },
    );
  }

  void _abrirModalCancelarParticipacao(ParticipacaoModel participacao) {
    final gateway = widget.participacaoGateway;
    if (gateway == null) return;

    final commandId = comandoOpaco();

    CancelarParticipacaoDialog.show(
      context,
      participacao: participacao,
      isLideranca: false,
      onConfirmar: (motivo) async {
        await gateway.cancelarParticipacao(
          participacaoId: participacao.id,
          motivo: motivo,
          expectedVersion: participacao.versao,
          commandId: commandId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.navy900,
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.surface),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Participação na equipe ${participacao.nomeEquipe} foi cancelada.',
                  ),
                ),
              ],
            ),
          ),
        );
        await _carregarDados();
      },
    );
  }

  Future<void> _baixarTermoPdf(ParticipacaoModel p) async {
    if (_ficha == null) return;
    setState(() {
      _baixandoPdfParticipacaoId = p.id;
    });
    try {
      final gateway = widget.pdfTermoGateway ?? FirebasePdfTermoGateway();
      final res = await gateway.obterUrlDownloadPdf(
        fichaId: _ficha!.id,
        participacaoId: p.id,
      );
      if (!mounted) return;
      baixarOuAbrirPdf(res.urlDownload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Termo da equipe ${p.nomeEquipe.isNotEmpty ? p.nomeEquipe : p.equipeId} pronto para download!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Tentar novamente',
            textColor: Colors.white,
            onPressed: () => _baixarTermoPdf(p),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _baixandoPdfParticipacaoId = null;
        });
      }
    }
  }

  void _abrirModalSolicitarReativacao(ParticipacaoModel participacao) {
    final gateway = widget.participacaoGateway;
    if (gateway == null) return;

    SolicitarReativacaoDialog.show(
      context,
      participacao: participacao,
      onConfirmar: (justificativa) async {
        await gateway.solicitarReativacao(
          equipeId: participacao.equipeId,
          participacaoId: participacao.id,
          justificativa: justificativa,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.navy900,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.surface),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Solicitação de reativação da equipe ${participacao.nomeEquipe} enviada! Aguardando avaliação pastoral.',
                  ),
                ),
              ],
            ),
          ),
        );
        await _carregarDados();
      },
    );
  }

  void _abrirModalRenovacao({ParticipacaoModel? participacaoEspecifica}) {
    final gateway = widget.participacaoGateway;
    if (gateway == null) return;

    final elegiveis = participacaoEspecifica != null
        ? [participacaoEspecifica]
        : _participacoes.where((p) => p.isEmJanelaRenovacao).toList();

    if (elegiveis.isEmpty) return;

    ManifestarRenovacaoDialog.show(
      context,
      participacoesElegiveis: elegiveis,
      participacaoPreSelecionadaId: participacaoEspecifica?.id,
      onConfirmar: (manifestacoes) async {
        final commandId = comandoOpaco();
        await gateway.manifestarRenovacao(
          manifestacoes: manifestacoes,
          commandId: commandId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.navy900,
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.surface),
                SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Manifestação de renovação registrada com sucesso!',
                  ),
                ),
              ],
            ),
          ),
        );
        await _carregarDados();
      },
    );
  }

  void _abrirModalCancelarVoluntariado() {
    final fichaId = _ficha?.id;
    if (fichaId == null || fichaId.isEmpty) return;

    final participacoesAfetadas =
        _participacoes.where((p) => !p.isTerminal).toList();
    final commandId = comandoOpaco();

    CancelarVoluntariadoDialog.show(
      context,
      fichaId: fichaId,
      participacoesAfetadas: participacoesAfetadas,
      isLideranca: false,
      onConfirmar: (motivo) async {
        await widget.fichaGateway.cancelarVoluntariado(
          fichaId: fichaId,
          motivo: motivo,
          expectedVersion: _ficha?.versao,
          commandId: commandId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.navy900,
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.surface),
                SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text('Voluntariado cancelado com sucesso.'),
                ),
              ],
            ),
          ),
        );
        await _carregarDados();
      },
    );
  }

  void _abrirTermo() {
    final termo = _termoVigente;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.navy900),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Termo de Adesão de Voluntário',
                style: AppTypography.h3,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (termo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          termo.titulo,
                          style: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Versão: ${termo.numeroVersao} (Vigente)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.blue600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (termo.publicadoEm.isNotEmpty)
                          Text(
                            'Publicado em: ${_formatarData(termo.publicadoEm)}',
                            style: AppTypography.caption,
                          ),
                        if (termo.hashSha256.isNotEmpty)
                          Text(
                            'Hash SHA-256: ${termo.hashSha256}',
                            style: AppTypography.caption.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    termo.conteudo,
                    style: AppTypography.body,
                  ),
                ] else ...[
                  const Text('Nenhum termo vigente carregado no momento.'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          SecondaryButton(
            key: const Key('botao_fechar_dialogo_termo'),
            label: 'Fechar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirHistoricoAceites() async {
    final gateway = widget.termoGateway;
    if (gateway == null) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => FutureBuilder<List<ComprovanteAceiteModel>>(
        future: gateway.obterHistoricoAceites(),
        builder: (context, snapshot) {
          Widget corpo;
          if (snapshot.connectionState == ConnectionState.waiting) {
            corpo = const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            corpo = Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Não foi possível carregar o histórico de aceites.',
                style: AppTypography.body.copyWith(color: AppColors.danger),
              ),
            );
          } else {
            final lista = snapshot.data ?? [];
            if (lista.isEmpty) {
              corpo = const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum registro de aceite anterior encontrado.'),
              );
            } else {
              corpo = SizedBox(
                width: 500,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, idx) {
                    final item = lista[idx];
                    final hashCurto = item.hashSha256.length >= 16
                        ? '${item.hashSha256.substring(0, 16)}...'
                        : item.hashSha256;
                    return ListTile(
                      dense: true,
                      title: Text(
                        'Versão ${item.numeroVersao} - ${item.titulo.isNotEmpty ? item.titulo : 'Termo de Adesão'}',
                        style: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aceito em: ${_formatarData(item.aceitoEm)}'),
                          Text(
                            'Hash: $hashCurto',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }
          }
          return AlertDialog(
            title: const Text('Histórico de Aceites Eletrônicos'),
            content: corpo,
            actions: [
              SecondaryButton(
                label: 'Fechar',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSecaoEnvioAprovacao(List<String> pendencias) {
    final dadosCompletos = pendencias.isEmpty && _ficha != null;
    final temEquipes = _participacoes.isNotEmpty;
    final termoAceito = _ficha?.termoAceito != null &&
        _termoVigente != null &&
        _ficha?.termoAceito?.versaoId == _termoVigente?.id;
    final aptoParaEnvio = dadosCompletos && temEquipes && termoAceito;

    if (_ficha?.estado == 'ATIVA') {
      return SectionCard(
        title: 'Status da Solicitação',
        subtitle: 'Voluntariado ativo e homologado.',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.success),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Voluntariado Ativo no Maanaim',
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const StatusChip(status: 'ATIVA', label: 'Ativa'),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Sua ficha e equipes aprovadas foram homologadas pela Coordenação Geral do Maanaim com ciclo de vigência anual ativo.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),
              _buildLinhaComprovante('Situação', 'Voluntariado Ativo'),
              _buildLinhaComprovante('Próxima Ação', 'Atuação voluntária'),
              _buildLinhaComprovante(
                'Equipes Ativas',
                _participacoes.where((p) => p.isAtiva).map((p) => p.nomeEquipe).join(', '),
              ),
            ],
          ),
        ),
      );
    }

    if (_ficha?.estado == 'REJEITADA') {
      return SectionCard(
        title: 'Status da Solicitação',
        subtitle: 'Solicitação concluída.',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.neutral150,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.navy800, size: 24),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Orientações sobre a Solicitação',
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const StatusChip(status: 'INATIVA', label: 'Informação', showDot: false),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _mensagemNegativaVoluntario,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_ficha?.estado == 'AGUARDANDO_COORDENADOR') {
      return SectionCard(
        title: 'Status da Solicitação',
        subtitle: 'Sua solicitação aguarda homologação da Coordenação Geral.',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.blue600),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_top, color: AppColors.blue600, size: 24),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Homologação da Coordenação Geral',
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const StatusChip(status: 'AGUARDANDO', label: 'Aguardando Coordenador'),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Suas equipes foram aprovadas pelos responsáveis e estão em fase de homologação final após a Reunião de Pastores.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),
              _buildLinhaComprovante('Próximo Responsável', 'Coordenador Geral'),
              _buildLinhaComprovante('Próxima Ação', 'Homologação e ativação anual'),
              _buildLinhaComprovante(
                'Equipes em Homologação',
                _participacoes.map((p) => p.nomeEquipe).join(', '),
              ),
            ],
          ),
        ),
      );
    }

    if (_ficha?.estado == 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
      return SectionCard(
        title: 'Status da Solicitação',
        subtitle: 'Sua solicitação está em análise pelos Responsáveis de Equipe.',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.blue600),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, color: AppColors.blue600, size: 24),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Avaliação pelos Responsáveis de Equipe',
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const StatusChip(status: 'AGUARDANDO', label: 'Aguardando Equipes'),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Sua solicitação foi aprovada pelo Pastor Local e está em deliberação paralela pelos responsáveis de cada equipe solicitada.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),
              _buildLinhaComprovante('Próximo Responsável', 'Responsáveis de Equipe'),
              _buildLinhaComprovante('Próxima Ação', 'Análise de equipes'),
              _buildLinhaComprovante(
                'Equipes em Análise',
                _participacoes.map((p) => p.nomeEquipe).join(', '),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAguardandoPastor) {
      return SectionCard(
        title: 'Status da Solicitação',
        subtitle: 'Sua ficha foi enviada e está sob análise institucional.',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.blue600),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.blue600, size: 24),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Ficha Enviada com Sucesso',
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const StatusChip(status: 'AGUARDANDO_PASTOR_LOCAL'),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Sua solicitação está na fila de avaliação do Pastor Local. Enquanto estiver em avaliação, as informações cadastrais e equipes permanecem bloqueadas para edição.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),
              _buildLinhaComprovante('Próximo Responsável', 'Pastor da Igreja Local'),
              _buildLinhaComprovante('Próxima Ação', 'Avaliação e manifestação pastoral'),
              _buildLinhaComprovante(
                'Equipes em Avaliação',
                _participacoes.map((p) => p.nomeEquipe).join(', '),
              ),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Enviar Ficha e Iniciar Aprovações',
      subtitle:
          'Após preencher os dados, selecionar equipes e aceitar o termo, envie sua ficha para homologação pastoral.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mensagemSucessoEnvio != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _mensagemSucessoEnvio!,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          if (_erroEnvio != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _erroEnvio!,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],

          // Checklist de pré-requisitos
          Text('Pré-requisitos para envio:', style: AppTypography.label),
          const SizedBox(height: AppSpacing.s8),

          _buildItemChecklist(
            titulo: 'Dados cadastrais obrigatórios preenchidos e salvos',
            concluido: dadosCompletos,
            detalhe: dadosCompletos
                ? 'Nome, profissão, CPF válido e igreja vinculada.'
                : 'Complete todos os campos obrigatórios acima e salve a ficha.',
          ),
          const SizedBox(height: AppSpacing.s8),

          _buildItemChecklist(
            titulo: 'Ao menos uma equipe de interesse salva no rascunho',
            concluido: temEquipes,
            detalhe: temEquipes
                ? '${_participacoes.length} equipe(s) selecionada(s).'
                : 'Selecione e salve ao menos uma equipe de trabalho acima.',
          ),
          const SizedBox(height: AppSpacing.s8),

          _buildItemChecklist(
            titulo: 'Termo de voluntariado vigente lido e aceito',
            concluido: termoAceito,
            detalhe: termoAceito
                ? 'Aceite eletrônico registrado na Versão ${_ficha?.termoAceito?.numeroVersao}.'
                : 'Leia e registre o aceite eletrônico na seção do termo acima.',
          ),

          const SizedBox(height: AppSpacing.s24),

          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              key: const Key('botao_enviar_ficha_aprovacao'),
              label: 'Enviar Ficha para Aprovação',
              icon: Icons.send_rounded,
              isLoading: _enviando,
              onPressed: (aptoParaEnvio && !_enviando) ? _confirmarEnvio : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemChecklist({
    required String titulo,
    required bool concluido,
    required String detalhe,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: concluido ? AppColors.successBg : AppColors.background,
        borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
        border: Border.all(
          color: concluido
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            concluido ? Icons.check_circle : Icons.radio_button_unchecked,
            color: concluido ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: concluido ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalhe,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinhaResumo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              rotulo,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarEnvio() {
    final nomeIgreja = _igrejas
        .cast<IgrejaCatalogo?>()
        .firstWhere((i) => i?.id == _igrejaSelecionadaId, orElse: () => null)
        ?.rotulo ?? _igrejaSelecionadaId ?? 'Não informada';

    final nomesEquipes = _participacoes.map((p) => p.nomeEquipe).join(', ');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppColors.blue600),
            const SizedBox(width: AppSpacing.s8),
            const Expanded(child: Text('Confirmar Envio da Ficha', style: AppTypography.h3)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revise os dados da sua solicitação antes de enviar para aprovação:',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLinhaResumo('Voluntário', _nomeController.text),
                    _buildLinhaResumo('Igreja Local', nomeIgreja),
                    _buildLinhaResumo('Equipes', nomesEquipes.isNotEmpty ? nomesEquipes : 'Nenhuma'),
                    _buildLinhaResumo('Termo Aceito', 'Versão ${_ficha?.termoAceito?.numeroVersao ?? 1}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Atenção: Ao enviar, sua ficha entrará em avaliação pelo Pastor Local e ficará bloqueada para alterações cadastrais e de equipes.',
                        style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          PrimaryButton(
            key: const Key('botao_confirmar_envio_dialogo'),
            label: 'Confirmar e Enviar',
            icon: Icons.check,
            onPressed: () {
              Navigator.of(ctx).pop();
              _executarEnvioFicha();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executarEnvioFicha() async {
    setState(() {
      _enviando = true;
      _erroEnvio = null;
      _mensagemSucessoEnvio = null;
    });

    try {
      final commandId = comandoOpaco();
      final resposta = await widget.fichaGateway.enviarFichaAprovacao(
        commandId: commandId,
        expectedVersion: _ficha?.versao,
      );

      if (mounted) {
        setState(() {
          _ficha = _ficha?.copyWith(
            estado: resposta.estado,
            versao: resposta.versao,
          );
          _participacoes = _participacoes.map((p) {
            if (p.isRascunho) {
              return p.copyWith(
                estado: 'AGUARDANDO_PASTOR_LOCAL',
                proximaAcao: resposta.proximaAcao,
              );
            }
            return p;
          }).toList();
          _enviando = false;
          _mensagemSucessoEnvio = 'Ficha enviada com sucesso para aprovação do Pastor Local!';
        });

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Ficha enviada com sucesso para aprovação do Pastor Local!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final mensagem = e.toString().contains('termo de voluntariado')
            ? 'O termo de voluntariado vigente precisa ser aceito antes do envio.'
            : e.toString().contains('ao menos uma equipe')
                ? 'Selecione e salve ao menos uma equipe antes do envio.'
                : 'Não foi possível enviar a ficha para aprovação. Tente novamente.';
        setState(() {
          _enviando = false;
          _erroEnvio = mensagem;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}


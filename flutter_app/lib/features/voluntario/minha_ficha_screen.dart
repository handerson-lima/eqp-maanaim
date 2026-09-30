import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/components/app_shell.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../admin/catalogo_service.dart';
import '../auth/validadores.dart';
import 'ficha_service.dart';
import 'participacao_service.dart';

/// Tela responsiva mobile-first para o voluntário preencher e manter sua ficha cadastral permanente.
class MinhaFichaScreen extends StatefulWidget {
  const MinhaFichaScreen({
    super.key,
    required this.fichaGateway,
    required this.catalogoGateway,
    this.participacaoGateway,
    this.onSair,
    this.userName,
  });

  final FichaGateway fichaGateway;
  final CatalogoGateway catalogoGateway;
  final ParticipacaoGateway? participacaoGateway;
  final VoidCallback? onSair;
  final String? userName;

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
  String? _erroCarregamento;
  String? _mensagemSucesso;
  String? _erroSalvar;
  String? _mensagemSucessoEquipes;
  String? _erroEquipes;

  @override
  void initState() {
    super.initState();
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
      final resultados = await Future.wait([
        widget.fichaGateway.obterMinhaFicha(),
        widget.catalogoGateway.consultar(),
        if (partGateway != null)
          partGateway.obterMinhasParticipacoes()
        else
          Future.value(<ParticipacaoModel>[]),
      ]);

      final respostaFicha = resultados[0] as ObterFichaResposta;
      final respostaCatalogo = resultados[1] as CatalogoResposta;
      final participacoes = resultados[2] as List<ParticipacaoModel>;

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
          }
          _carregando = false;
        });
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

    final estadoExibicao = _ficha?.estado ?? 'RASCUNHO';

    return AppShell(
      items: navItems,
      selectedIndex: 0,
      onLogout: widget.onSair,
      userName: _ficha?.nomeCompleto.isNotEmpty == true
          ? _ficha!.nomeCompleto
          : widget.userName,
      userRole: 'Voluntário',
      userStatus: estadoExibicao,
      body: _carregando
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
                        action: StatusChip(status: _ficha?.estado ?? 'RASCUNHO'),
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
              : _buildConteudo(),
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da página
              PageHeader(
                title: 'Minha Ficha',
                subtitle:
                    'Acesso realizado. Sua ficha pode continuar em rascunho.',
                action: StatusChip(status: _ficha?.estado ?? 'RASCUNHO'),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Banner de pendências ou conclusão
              _buildBannerPendencias(pendencias),
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

              // Card com formulário de dados cadastrais
              SectionCard(
                title: 'Dados Cadastrais',
                subtitle:
                    'Campos marcados são obrigatórios para emissão do termo e aprovação.',
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nome Completo
                      Text('Nome Completo', style: AppTypography.label),
                      const SizedBox(height: AppSpacing.s4),
                      TextFormField(
                        key: const Key('campo_nome_completo'),
                        controller: _nomeController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Seu nome completo',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Profissão
                      Text('Profissão', style: AppTypography.label),
                      const SizedBox(height: AppSpacing.s4),
                      TextFormField(
                        key: const Key('campo_profissao'),
                        controller: _profissaoController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Sua ocupação principal (ex: Marceneiro, Advogado)',
                          prefixIcon: Icon(Icons.work_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // CPF
                      Text('CPF', style: AppTypography.label),
                      const SizedBox(height: AppSpacing.s4),
                      TextFormField(
                        key: const Key('campo_cpf'),
                        controller: _cpfController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: '000.000.000-00',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Igreja Local
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
                        onChanged: (novoId) {
                          setState(() {
                            _igrejaSelecionadaId = novoId;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.s24),

                      // Botão de salvar rascunho
                      Align(
                        alignment: Alignment.centerRight,
                        child: PrimaryButton(
                          key: const Key('botao_salvar_ficha'),
                          label: 'Salvar Ficha',
                          icon: Icons.save_outlined,
                          isLoading: _salvando,
                          onPressed: _salvando ? null : _salvarFicha,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_ficha != null) ...[
                const SizedBox(height: AppSpacing.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Versão: ${_ficha!.versao}',
                        style: AppTypography.caption,
                      ),
                      if (_ficha!.atualizadoEm != null)
                        Text(
                          'Última alteração: ${_formatarData(_ficha!.atualizadoEm!)}',
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s24),

              // Seção de seleção de equipes e participações em rascunho
              _buildSecaoEquipes(),
            ],
          ),
        ),
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
                  onSelected: (selecionado) {
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
            'Participações no Rascunho',
            style: AppTypography.h3,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Cada equipe selecionada gera uma participação independente.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (_equipesSelecionadasIds.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
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
                                const StatusChip(status: 'RASCUNHO'),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
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
                                    'Aguardando envio da ficha',
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
              onPressed: _salvandoEquipes ? null : _salvarEquipes,
            ),
          ),
        ],
      ),
    );
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
}

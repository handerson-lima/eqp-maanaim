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

/// Tela responsiva mobile-first para o voluntário preencher e manter sua ficha cadastral permanente.
class MinhaFichaScreen extends StatefulWidget {
  const MinhaFichaScreen({
    super.key,
    required this.fichaGateway,
    required this.catalogoGateway,
    this.onSair,
    this.userName,
  });

  final FichaGateway fichaGateway;
  final CatalogoGateway catalogoGateway;
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

  String? _igrejaSelecionadaId;
  FichaModel? _ficha;
  List<IgrejaCatalogo> _igrejas = const [];

  bool _carregando = true;
  bool _salvando = false;
  String? _erroCarregamento;
  String? _mensagemSucesso;
  String? _erroSalvar;

  @override
  void initState() {
    super.initState();
    _nomeController.addListener(_aoMudarCampos);
    _profissaoController.addListener(_aoMudarCampos);
    _cpfController.addListener(_aoMudarCampos);
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.removeListener(_aoMudarCampos);
    _profissaoController.removeListener(_aoMudarCampos);
    _cpfController.removeListener(_aoMudarCampos);
    _nomeController.dispose();
    _profissaoController.dispose();
    _cpfController.dispose();
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
      final resultados = await Future.wait([
        widget.fichaGateway.obterMinhaFicha(),
        widget.catalogoGateway.consultar(),
      ]);

      final respostaFicha = resultados[0] as ObterFichaResposta;
      final respostaCatalogo = resultados[1] as CatalogoResposta;

      final igrejasAtivas = respostaCatalogo.igrejas
          .where((i) => i.ativo)
          .toList(growable: false);

      if (mounted) {
        setState(() {
          _igrejas = igrejasAtivas;
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
            ],
          ),
        ),
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

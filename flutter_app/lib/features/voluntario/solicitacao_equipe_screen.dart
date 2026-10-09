import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../routes/app_router.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/cpf_formatter.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/components/stepper.dart';
import '../../ui/tokens.dart';
import '../admin/catalogo_service.dart';
import '../termo/termo_service.dart';
import 'ficha_service.dart';
import 'participacao_service.dart';

/// Tela S03: Nova Solicitação de Equipe / Inscrição em Etapas (Story 8.8).
///
/// Implementa o fluxo guiado em 4 etapas:
/// 1. Seleção de Equipes (grid administrável responsivo com seleção múltipla, busca e foco acessível)
/// 2. Termo de Adesão (leitura do termo vigente, detecção de nova versão e aceite explícito)
/// 3. Revisão (resumo de dados, igreja, equipes selecionadas e status do termo)
/// 4. Envio (confirmação, feedback de erro/sucesso acessível e retorno autorizado)
class SolicitacaoEquipeScreen extends StatefulWidget {
  const SolicitacaoEquipeScreen({
    super.key,
    this.fichaGateway,
    this.participacaoGateway,
    this.catalogoGateway,
    this.termoGateway,
    this.fichaInicial,
    this.participacoesIniciais,
    this.equipesCatalogoIniciais,
    this.modoAdicional = false,
    this.dentroDeShell = false,
    this.onConcluido,
  });

  final FichaGateway? fichaGateway;
  final ParticipacaoGateway? participacaoGateway;
  final CatalogoGateway? catalogoGateway;
  final TermoGateway? termoGateway;
  final FichaModel? fichaInicial;
  final List<ParticipacaoModel>? participacoesIniciais;
  final List<EquipeCatalogo>? equipesCatalogoIniciais;
  final bool modoAdicional;
  final bool dentroDeShell;
  final VoidCallback? onConcluido;

  @override
  State<SolicitacaoEquipeScreen> createState() => _SolicitacaoEquipeScreenState();
}

class _SolicitacaoEquipeScreenState extends State<SolicitacaoEquipeScreen> {
  int _etapaAtual = 0;
  bool _carregandoInicial = true;
  String? _erroCarregamento;

  // Dados carregados
  FichaModel? _ficha;
  List<ParticipacaoModel> _participacoes = [];
  List<EquipeCatalogo> _equipesCatalogo = [];
  List<IgrejaCatalogo> _igrejasCatalogo = [];
  TermoVigenteModel? _termoVigente;

  // Estado da Seleção (Etapa 0) - Preservação de rascunho
  final Set<String> _equipesSelecionadasIds = <String>{};
  String _filtroBusca = '';
  final TextEditingController _buscaController = TextEditingController();
  final ScrollController _termoScrollController = ScrollController();

  // Estado do Termo (Etapa 1)
  bool _termoAceitoNestaSessao = false;
  bool _termoJaAceitoAnteriormente = false;
  String? _termoErro;

  // Estado de Envio (Etapa 3)
  bool _enviando = false;
  String? _mensagemErroEnvio;
  bool _envioConcluidoComSucesso = false;
  String? _protocoloOuRecibo;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _termoScrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregandoInicial = true;
      _erroCarregamento = null;
    });

    try {
      // 1. Carrega ou usa Ficha
      if (widget.fichaInicial != null) {
        _ficha = widget.fichaInicial;
      } else if (widget.fichaGateway != null) {
        final resp = await widget.fichaGateway!.obterMinhaFicha();
        _ficha = resp.ficha;
      }

      // 2. Carrega ou usa Participações
      if (widget.participacoesIniciais != null) {
        _participacoes = List.of(widget.participacoesIniciais!);
      } else if (widget.participacaoGateway != null) {
        _participacoes = await widget.participacaoGateway!.obterMinhasParticipacoes();
      }

      // 3. Carrega Catálogo de Equipes e Igrejas
      if (widget.equipesCatalogoIniciais != null) {
        _equipesCatalogo = List.of(widget.equipesCatalogoIniciais!);
      } else if (widget.catalogoGateway != null) {
        final cat = await widget.catalogoGateway!.consultar();
        _equipesCatalogo = cat.equipes;
        _igrejasCatalogo = cat.igrejas;
      }

      // Pré-seleciona equipes que já estavam em rascunho (se não for modo estritamente adicional)
      if (!widget.modoAdicional) {
        final rascunhos = _participacoes
            .where((p) => p.isRascunho)
            .map((p) => p.equipeId)
            .toSet();
        _equipesSelecionadasIds.addAll(rascunhos);
      }

      // 4. Carrega Termo Vigente
      if (widget.termoGateway != null) {
        _termoVigente = await widget.termoGateway!.obterTermoVigente();
      }

      // Verifica se o voluntário já aceitou o termo vigente previamente
      if (_ficha != null && _ficha!.termoAceito != null && _termoVigente != null) {
        // Se a ficha já registrou aceite e não há exigência de nova versão
        if (_ficha!.termoAceito!.versaoId == _termoVigente!.id ||
            _ficha!.termoAceito!.numeroVersao == _termoVigente!.numeroVersao) {
          _termoJaAceitoAnteriormente = true;
        }
      }

      if (mounted) {
        setState(() {
          _carregandoInicial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregandoInicial = false;
          _erroCarregamento = 'Não foi possível carregar os dados para a solicitação. Verifique sua conexão e tente novamente.';
        });
      }
    }
  }

  bool _isEquipeInelegivel(String equipeId) {
    // Equipe em que o voluntário já possui participação ativa ou em análise
    return _participacoes.any(
      (p) => p.equipeId == equipeId && (p.isAtiva || p.isPendente),
    );
  }

  ParticipacaoModel? _obterParticipacaoExistente(String equipeId) {
    final encontradas = _participacoes.where((p) => p.equipeId == equipeId);
    if (encontradas.isEmpty) return null;
    return encontradas.first;
  }

  String _nomeIgreja(String? igrejaId) {
    if (igrejaId == null || igrejaId.isEmpty) return 'Não informada';
    final igreja = _igrejasCatalogo.where((i) => i.id == igrejaId);
    if (igreja.isNotEmpty) return igreja.first.nome;
    return igrejaId;
  }

  void _avancarEtapa() {
    if (_etapaAtual == 0) {
      // Validação da etapa 0: pelo menos 1 equipe selecionada
      if (_equipesSelecionadasIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione pelo menos uma equipe para prosseguir.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      // Sincroniza rascunho com o backend se disponível e não for modo estritamente adicional
      if (widget.participacaoGateway != null && !widget.modoAdicional) {
        widget.participacaoGateway!.salvarParticipacoesRascunho(
          _equipesSelecionadasIds.toList(),
        ).catchError((_) => <ParticipacaoModel>[]);
      }
    } else if (_etapaAtual == 1) {
      // Validação da etapa 1: aceite do termo vigente obrigatório
      final aceito = _termoJaAceitoAnteriormente || _termoAceitoNestaSessao;
      if (!aceito) {
        setState(() {
          _termoErro = 'Você deve ler e aceitar o Termo de Adesão para continuar.';
        });
        return;
      }
      setState(() => _termoErro = null);
    }

    if (_etapaAtual < 3) {
      setState(() {
        _etapaAtual++;
        _mensagemErroEnvio = null;
      });
    }
  }

  void _voltarEtapa() {
    if (_etapaAtual > 0 && !_enviando && !_envioConcluidoComSucesso) {
      setState(() {
        _etapaAtual--;
        _mensagemErroEnvio = null;
      });
    }
  }

  Future<void> _submeterSolicitacao() async {
    if (_enviando) return;

    setState(() {
      _enviando = true;
      _mensagemErroEnvio = null;
    });

    try {
      final commandId = comandoOpaco();

      // 1. Se aceitou termo nesta sessão e o gateway está presente, registra o aceite no servidor
      if (_termoAceitoNestaSessao && widget.termoGateway != null && _termoVigente != null) {
        await widget.termoGateway!.aceitarTermoVigente(
          commandId: commandId,
          versaoId: _termoVigente!.id,
          hashSha256: _termoVigente!.hashSha256,
          declaracaoLidoEConcordo: true,
        );
      }

      // 2. Processa o envio conforme o modo (adicional ou inicial)
      if (widget.modoAdicional) {
        // Modo Adicional: solicita cada equipe selecionada individualmente (AD-5, AD-11)
        if (widget.participacaoGateway != null) {
          for (final equipeId in _equipesSelecionadasIds) {
            await widget.participacaoGateway!.solicitarEquipeAdicional(
              equipeId,
              commandId: comandoOpaco(),
            );
          }
        }
      } else {
        // Modo Inicial: salva rascunho e envia a ficha para aprovação (Story 2.4 / AD-5)
        if (widget.participacaoGateway != null) {
          await widget.participacaoGateway!.salvarParticipacoesRascunho(
            _equipesSelecionadasIds.toList(),
            commandId: commandId,
          );
        }

        if (widget.fichaGateway != null) {
          final resp = await widget.fichaGateway!.enviarFichaAprovacao(
            commandId: commandId,
            expectedVersion: _ficha?.versao,
          );
          _protocoloOuRecibo = 'Protocolo #${resp.versao}';
        }
      }

      if (mounted) {
        setState(() {
          _enviando = false;
          _envioConcluidoComSucesso = true;
          _protocoloOuRecibo ??= 'Solicitação registrada com sucesso';
        });
        widget.onConcluido?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _mensagemErroEnvio = _traduzirErroEnvio(e);
        });
      }
    }
  }

  String _traduzirErroEnvio(Object erro) {
    if (erro is FirebaseFunctionsException) {
      switch (erro.code) {
        case 'failed-precondition':
          return erro.message ?? 'Não foi possível concluir a solicitação. Verifique os dados e tente novamente.';
        case 'permission-denied':
          return 'Permissão negada para submeter a solicitação.';
        case 'invalid-argument':
          return erro.message ?? 'Dados inválidos. Revise as equipes e o termo antes de enviar.';
        case 'unavailable':
        case 'internal':
          return 'Serviço temporariamente indisponível. Suas seleções continuam salvas, tente novamente em instantes.';
      }
    }
    final msg = erro.toString();
    if (msg.contains('Termo')) {
      return 'O Termo de Adesão foi atualizado recentemente. Por favor, volte à etapa anterior e renove o aceite.';
    }
    return 'Ocorreu um erro ao enviar a solicitação. Suas seleções foram preservadas. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dentroDeShell) {
      return _buildCorpo();
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildCorpo()),
    );
  }

  Widget _buildCorpo() {
    if (_carregandoInicial) {
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
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.s16),
              Text(
                _erroCarregamento!,
                style: AppTypography.body.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s16),
              PrimaryButton(
                label: 'Tentar novamente',
                onPressed: _carregarDados,
              ),
            ],
          ),
        ),
      );
    }

    final etapas = [
      const StepperEtapa(titulo: 'Seleção de Equipes', subtitulo: 'Escolha onde servir'),
      const StepperEtapa(titulo: 'Termo de Adesão', subtitulo: 'Leitura e concordância'),
      const StepperEtapa(titulo: 'Revisão', subtitulo: 'Confira os dados'),
      const StepperEtapa(titulo: 'Envio', subtitulo: 'Confirmação final'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho institucional
              PageHeader(
                title: widget.modoAdicional
                    ? 'Solicitar Equipe Adicional'
                    : 'Nova Solicitação de Equipe',
                subtitle: widget.modoAdicional
                    ? 'Amplie sua atuação no voluntariado sem interromper suas participações ativas.'
                    : 'Preencha as etapas guiadas para solicitar suas equipes no Maanaim.',
              ),
              const SizedBox(height: AppSpacing.s16),

              // Stepper Responsivo
              AppStepper(
                etapas: etapas,
                etapaAtual: _etapaAtual,
                onEtapaTap: (novaEtapa) {
                  // Permite voltar diretamente para etapas anteriores
                  if (novaEtapa < _etapaAtual && !_enviando && !_envioConcluidoComSucesso) {
                    setState(() {
                      _etapaAtual = novaEtapa;
                      _mensagemErroEnvio = null;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s24),

              // Conteúdo da etapa ativa
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildConteudoEtapaAtiva(),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Barra de ações (Voltar / Avançar / Enviar)
              if (!_envioConcluidoComSucesso) _buildBarraAcoes(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudoEtapaAtiva() {
    switch (_etapaAtual) {
      case 0:
        return _buildEtapaSelecao();
      case 1:
        return _buildEtapaTermo();
      case 2:
        return _buildEtapaRevisao();
      case 3:
        return _buildEtapaEnvio();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // ETAPA 0: SELEÇÃO DE EQUIPES (GRID ADMINISTRÁVEL RESPONSIVO)
  // ---------------------------------------------------------------------------
  Widget _buildEtapaSelecao() {
    final equipesFiltradas = _equipesCatalogo
        .where((e) => e.ativo)
        .where((e) =>
            _filtroBusca.isEmpty ||
            e.nome.toLowerCase().contains(_filtroBusca.toLowerCase()))
        .toList(growable: false);

    return SectionCard(
      title: '1. Seleção de Equipes',
      subtitle:
          'Selecione uma ou mais equipes administráveis para o seu voluntariado. Suas seleções ficam salvas como rascunho.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo de busca acessível
          TextField(
            key: const Key('campo_busca_equipes_solicitacao'),
            controller: _buscaController,
            decoration: InputDecoration(
              labelText: 'Buscar equipe',
              hintText: 'Digite o nome da equipe...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _filtroBusca.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _buscaController.clear();
                        setState(() => _filtroBusca = '');
                      },
                      tooltip: 'Limpar busca',
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _filtroBusca = val.trim()),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Resumo da seleção
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_equipesSelecionadasIds.length} equipe(s) selecionada(s)',
                  style: AppTypography.caption.copyWith(
                    color: _equipesSelecionadasIds.isNotEmpty
                        ? AppColors.blue600
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_equipesSelecionadasIds.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _equipesSelecionadasIds.clear()),
                  child: const Text('Limpar seleção'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Grid de Equipes conforme regra de responsividade de S03
          LayoutBuilder(
            builder: (context, constraints) {
              if (equipesFiltradas.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
                  child: Center(
                    child: Text(
                      _filtroBusca.isEmpty
                          ? 'Nenhuma equipe disponível no catálogo.'
                          : 'Nenhuma equipe encontrada para "$_filtroBusca".',
                      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              // Regra de seleção S03:
              // Mobile (<600): 1 coluna por padrão; 2 colunas apenas se largura útil por card >= 160 px + gap 16 px.
              final larguraDisponivel = constraints.maxWidth;
              int colunas;
              if (larguraDisponivel < 600) {
                // Para 2 colunas: (largura - 16) / 2 >= 160 => largura >= 336
                colunas = larguraDisponivel >= 360 ? 2 : 1;
              } else if (larguraDisponivel < 900) {
                colunas = 2;
              } else {
                colunas = 3;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: equipesFiltradas.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: colunas,
                  crossAxisSpacing: AppSpacing.s16,
                  mainAxisSpacing: AppSpacing.s12,
                  childAspectRatio: colunas == 1 ? 4.5 : 2.6,
                ),
                itemBuilder: (context, index) {
                  final equipe = equipesFiltradas[index];
                  final inelegivel = _isEquipeInelegivel(equipe.id);
                  final partExistente = _obterParticipacaoExistente(equipe.id);
                  final selecionada = _equipesSelecionadasIds.contains(equipe.id);

                  return _buildCardEquipe(
                    equipe: equipe,
                    selecionada: selecionada,
                    inelegivel: inelegivel,
                    participacaoExistente: partExistente,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardEquipe({
    required EquipeCatalogo equipe,
    required bool selecionada,
    required bool inelegivel,
    required ParticipacaoModel? participacaoExistente,
  }) {
    return Semantics(
      enabled: !inelegivel,
      selected: selecionada,
      button: true,
      label: inelegivel
          ? '${equipe.nome}, indisponível: já possui participação'
          : '${equipe.nome}, ${selecionada ? "selecionada" : "não selecionada"}',
      child: InkWell(
        key: Key('card_equipe_${equipe.id}'),
        onTap: inelegivel
            ? null
            : () {
                setState(() {
                  if (widget.modoAdicional) {
                    // No modo adicional unitário, seleciona apenas uma equipe
                    _equipesSelecionadasIds.clear();
                    _equipesSelecionadasIds.add(equipe.id);
                  } else {
                    if (selecionada) {
                      _equipesSelecionadasIds.remove(equipe.id);
                    } else {
                      _equipesSelecionadasIds.add(equipe.id);
                    }
                  }
                });
              },
        borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: inelegivel
                ? AppColors.neutral150.withValues(alpha: 0.4)
                : selecionada
                    ? AppColors.blue50
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            border: Border.all(
              color: selecionada
                  ? AppColors.blue600
                  : AppColors.border,
              width: selecionada ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Checkbox acessível com indicação nítida de estado
              Icon(
                inelegivel
                    ? Icons.block
                    : selecionada
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                color: inelegivel
                    ? AppColors.textSecondary
                    : selecionada
                        ? AppColors.blue600
                        : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      equipe.nome,
                      style: AppTypography.body.copyWith(
                        fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                        color: inelegivel ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (inelegivel && participacaoExistente != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        participacaoExistente.isAtiva ? 'Participação Ativa' : 'Em Análise',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (inelegivel)
                const StatusChip(
                  status: 'INATIVA',
                  label: 'Já inscrito',
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 1: TERMO DE ADESÃO
  // ---------------------------------------------------------------------------
  Widget _buildEtapaTermo() {
    final termo = _termoVigente;

    return SectionCard(
      title: '2. Termo de Adesão ao Serviço Voluntário',
      subtitle:
          'Leia atentamente o documento de adesão. A concordância com o termo vigente é requisito legal e institucional.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (termo == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.s24),
              child: Center(
                child: Text('Carregando termo de adesão vigente...'),
              ),
            )
          else ...[
            // Cabeçalho do termo com versão e data
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.blue600, size: 24),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          termo.titulo.isNotEmpty ? termo.titulo : 'Termo de Adesão ao Serviço Voluntário',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy900,
                          ),
                        ),
                        Text(
                          'Versão ${termo.numeroVersao} • Publicado em ${termo.publicadoEm.split('T').first}',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_termoJaAceitoAnteriormente)
                    const StatusChip(
                      status: 'ATIVA',
                      label: 'Aceite vigente',
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Caixa de texto rolável com o conteúdo integral do termo
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.border),
              ),
              child: Scrollbar(
                controller: _termoScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _termoScrollController,
                  child: Text(
                    termo.conteudo.isNotEmpty
                        ? termo.conteudo
                        : 'Conteúdo institucional do termo de adesão ao serviço voluntário...',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Informação do hash de integridade
            if (termo.hashSha256.isNotEmpty)
              Text(
                'Hash SHA-256: ${termo.hashSha256}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.s16),

            // Alerta de termo atualizado ou confirmação de aceite prévio
            if (_termoJaAceitoAnteriormente)
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Você já concordou com esta versão do Termo de Adesão. Não é necessário novo aceite, mas você pode renová-lo abaixo.',
                        style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s12),

            // Checkbox explícito de aceite
            Semantics(
              label: 'Declaração de concordância com o termo de adesão',
              child: InkWell(
                key: const Key('checkbox_aceite_termo_solicitacao'),
                onTap: () {
                  setState(() {
                    _termoAceitoNestaSessao = !_termoAceitoNestaSessao;
                    _termoErro = null;
                  });
                },
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _termoJaAceitoAnteriormente || _termoAceitoNestaSessao,
                        onChanged: (val) {
                          setState(() {
                            _termoAceitoNestaSessao = val ?? false;
                            _termoErro = null;
                          });
                        },
                        activeColor: AppColors.blue600,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          'Declaro que li na íntegra e concordo com os termos e condições do Serviço Voluntário no Maanaim.',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_termoErro != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                _termoErro!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 2: REVISÃO DOS DADOS ANTES DO ENVIO
  // ---------------------------------------------------------------------------
  Widget _buildEtapaRevisao() {
    final equipesSelecionadas = _equipesCatalogo
        .where((e) => _equipesSelecionadasIds.contains(e.id))
        .toList(growable: false);

    return SectionCard(
      title: '3. Revisão da Solicitação',
      subtitle:
          'Verifique todas as informações antes de confirmar o envio para aprovação.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resumo dos Dados Pessoais e Igreja
          Text('Dados do Voluntário', style: AppTypography.label),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildLinhaRevisao('Nome Completo', _ficha?.nomeCompleto ?? 'Não informado'),
                const Divider(height: 16),
                _buildLinhaRevisao('CPF', CpfFormatter.formatar(_ficha?.cpf ?? '')),
                const Divider(height: 16),
                _buildLinhaRevisao('Igreja Local', _nomeIgreja(_ficha?.igrejaId)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Resumo das Equipes Selecionadas
          Text('Equipes Solicitadas (${equipesSelecionadas.length})', style: AppTypography.label),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: equipesSelecionadas.isEmpty
                ? const Text('Nenhuma equipe selecionada.')
                : Column(
                    children: equipesSelecionadas.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.blue600, size: 18),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                e.nome,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Resumo do Termo de Adesão
          Text('Termo de Adesão', style: AppTypography.label),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.success, size: 22),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Termo Versão ${_termoVigente?.numeroVersao ?? 1}',
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _termoAceitoNestaSessao
                            ? 'Aceite confirmado para envio imediato'
                            : 'Aceite vigente registrado no sistema',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const StatusChip(
                  status: 'ATIVA',
                  label: 'Pronto para envio',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Nota explicativa
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.blue600, size: 20),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Ao confirmar, sua solicitação será enviada para avaliação pelo Pastor da sua igreja e pelos responsáveis das equipes selecionadas.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.navy900,
                      fontWeight: FontWeight.w500,
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

  Widget _buildLinhaRevisao(String rotulo, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          rotulo,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          valor,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.navy900,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 3: ENVIO E RESULTADO
  // ---------------------------------------------------------------------------
  Widget _buildEtapaEnvio() {
    if (_envioConcluidoComSucesso) {
      return SectionCard(
        title: 'Solicitação Enviada com Sucesso!',
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.successBg,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 56,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Suas equipes foram solicitadas!',
              style: AppTypography.h3.copyWith(
                color: AppColors.navy900,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Acompanhe o andamento das aprovações no seu painel inicial.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (_protocoloOuRecibo != null) ...[
              const SizedBox(height: AppSpacing.s16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _protocoloOuRecibo!,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s32),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    key: const Key('btn_ir_para_inicio_voluntario'),
                    label: 'Ir para o Início',
                    icon: Icons.home_outlined,
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(AppRotas.inicio);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
        ),
      );
    }

    return SectionCard(
      title: '4. Confirmação e Envio',
      subtitle:
          'Clique no botão abaixo para concluir e submeter a sua solicitação.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mensagemErroEnvio != null) ...[
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
                      _mensagemErroEnvio!,
                      style: AppTypography.body.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          Text(
            'Você está prestes a submeter a solicitação de ${_equipesSelecionadasIds.length} equipe(s). '
            'Após o envio, as participações ficarão disponíveis para análise dos responsáveis.',
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            key: const Key('btn_confirmar_envio_solicitacao'),
            label: _enviando ? 'Enviando...' : 'Confirmar e Enviar Solicitação',
            icon: _enviando ? null : Icons.send_outlined,
            isLoading: _enviando,
            onPressed: _enviando ? null : _submeterSolicitacao,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA DE AÇÕES (VOLTAR / AVANÇAR)
  // ---------------------------------------------------------------------------
  Widget _buildBarraAcoes() {
    final ehPrimeira = _etapaAtual == 0;
    final ehUltima = _etapaAtual == 3;

    return Row(
      children: [
        if (!ehPrimeira) ...[
          Expanded(
            child: SecondaryButton(
              key: const Key('btn_voltar_etapa_solicitacao'),
              label: 'Voltar',
              icon: Icons.arrow_back,
              onPressed: _enviando ? null : _voltarEtapa,
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
        ],
        if (!ehUltima)
          Expanded(
            child: PrimaryButton(
              key: const Key('btn_avancar_etapa_solicitacao'),
              label: 'Próximo',
              icon: Icons.arrow_forward,
              onPressed: _enviando ? null : _avancarEtapa,
            ),
          ),
      ],
    );
  }
}

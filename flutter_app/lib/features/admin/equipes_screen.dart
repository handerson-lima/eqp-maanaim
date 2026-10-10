import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import 'catalogo_service.dart';

enum SituacaoEquipeFiltro { todas, ativas, inativas }

/// S11 — Administração e Gestão de Equipes.
/// Suporta tabela responsiva no desktop, cartões estruturados no mobile (<768px),
/// busca textual, filtro de situação e criação/edição autenticada via comandos no servidor.
class EquipesScreen extends StatefulWidget {
  const EquipesScreen({
    super.key,
    required this.gateway,
    this.onNavegarVinculos,
  });

  final CatalogoGateway gateway;
  final void Function(EquipeCatalogo equipe)? onNavegarVinculos;

  @override
  State<EquipesScreen> createState() => _EquipesScreenState();
}

class _EquipesScreenState extends State<EquipesScreen> {
  late Future<CatalogoResposta> _futuro;
  final _buscaController = TextEditingController();
  String _termo = '';
  SituacaoEquipeFiltro _filtroSituacao = SituacaoEquipeFiltro.todas;
  bool _executando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _carregar() {
    setState(() {
      _futuro = widget.gateway.consultar();
    });
  }

  List<EquipeCatalogo> _filtrar(List<EquipeCatalogo> lista) {
    var resultado = filtrarEquipes(lista, _termo);
    switch (_filtroSituacao) {
      case SituacaoEquipeFiltro.todas:
        break;
      case SituacaoEquipeFiltro.ativas:
        resultado = resultado.where((e) => e.ativo).toList();
        break;
      case SituacaoEquipeFiltro.inativas:
        resultado = resultado.where((e) => !e.ativo).toList();
        break;
    }
    return resultado;
  }

  Future<void> _abrirFormularioEquipe({EquipeCatalogo? equipeParaEdicao}) async {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: equipeParaEdicao?.nome ?? '');
    String? erroServidor;
    bool salvando = false;

    final salvo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final ehEdicao = equipeParaEdicao != null;
          final titulo = ehEdicao ? 'Editar Equipe' : 'Nova Equipe';

          Future<void> submeter() async {
            if (!formKey.currentState!.validate()) return;

            setDialogState(() {
              salvando = true;
              erroServidor = null;
            });

            try {
              await widget.gateway.salvarEquipe(
                commandId: comandoOpaco(),
                equipeId: equipeParaEdicao?.id,
                nome: nomeController.text.trim(),
                expectedVersion: equipeParaEdicao?.versao ?? 0,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (e) {
              setDialogState(() {
                salvando = false;
                final msg = e.toString();
                if (msg.contains('already-exists') || msg.contains('duplicad')) {
                  erroServidor = 'Já existe uma equipe cadastrada com este nome.';
                } else if (msg.contains('aborted') || msg.contains('concorrência')) {
                  erroServidor = 'Conflito de versão: a equipe foi alterada por outro usuário. Recarregue a página.';
                } else {
                  erroServidor = 'Não foi possível salvar a equipe. Verifique os dados e tente novamente.';
                }
              });
            }
          }

          return AlertDialog(
            title: Text(titulo, style: AppTypography.h3),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (erroServidor != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: AppGeometry.cardBorderRadius,
                            border: Border.all(color: AppColors.danger),
                          ),
                          child: Text(
                            erroServidor!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                      ],
                      TextFormField(
                        controller: nomeController,
                        enabled: !salvando,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Equipe *',
                          hintText: 'Ex.: Apoio, Recepção, Louvor, etc.',
                        ),
                        validator: (valor) {
                          final v = valor?.trim() ?? '';
                          if (v.length < 3) return 'Nome deve ter no mínimo 3 caracteres';
                          if (v.length > 160) return 'Nome deve ter no máximo 160 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'A equipe admite um único responsável canônico vigente, que pode ser vinculado após a criação.',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: SecondaryButton(
                  label: 'Cancelar',
                  onPressed: salvando ? null : () => Navigator.of(dialogContext).pop(false),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: PrimaryButton(
                  label: salvando ? 'Salvando...' : 'Salvar Equipe',
                  onPressed: salvando ? null : submeter,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (salvo == true) {
      if (mounted) {
        setState(() {
          _aviso = equipeParaEdicao == null
              ? 'Equipe "${nomeController.text.trim()}" cadastrada com sucesso.'
              : 'Equipe "${nomeController.text.trim()}" atualizada com sucesso.';
        });
        _carregar();
      }
    }
  }

  Future<void> _confirmarAlternarEquipe(EquipeCatalogo equipe) async {
    final novoAtivo = !equipe.ativo;
    final acao = novoAtivo ? 'Reativar' : 'Inativar';
    final titulo = '$acao Equipe';
    final mensagem = novoAtivo
        ? 'Deseja reativar a equipe "${equipe.nome}"?\n\nEla voltará a ficar disponível para novas seleções no cadastro de voluntários.'
        : 'Deseja inativar a equipe "${equipe.nome}"?\n\nEla deixará de ser exibida em novas seleções. Participações ativas e vigentes existentes não serão afetadas.';

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo, style: AppTypography.h3),
        content: Text(mensagem, style: AppTypography.body),
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.cardBorderRadius,
        ),
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: SecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(dialogo, false),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: PrimaryButton(
              label: acao,
              onPressed: () => Navigator.pop(dialogo, true),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    setState(() {
      _executando = true;
      _aviso = null;
    });

    try {
      await widget.gateway.alternarStatusEquipe(
        commandId: comandoOpaco(),
        equipeId: equipe.id,
        ativo: novoAtivo,
      );
      if (!mounted) return;
      setState(() {
        _aviso = 'Equipe "${equipe.nome}" ${novoAtivo ? "reativada" : "inativada"} com sucesso.';
      });
      _carregar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aviso = 'Não foi possível alterar o status da equipe.';
      });
    } finally {
      if (mounted) {
        setState(() => _executando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: PageHeader(
            title: 'Gestão de Equipes',
            subtitle: 'Catálogo institucional de frentes de atuação e seus respectivos responsáveis',
            action: PrimaryButton(
              icon: Icons.add,
              label: 'Nova Equipe',
              onPressed: () => _abrirFormularioEquipe(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final searchWidget = TextField(
                controller: _buscaController,
                onChanged: (valor) => setState(() => _termo = valor),
                decoration: InputDecoration(
                  labelText: 'Pesquisar equipe por nome',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _termo.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _buscaController.clear();
                            setState(() => _termo = '');
                          },
                        )
                      : null,
                ),
              );

              final filterWidget = SegmentedButton<SituacaoEquipeFiltro>(
                segments: const [
                  ButtonSegment(
                    value: SituacaoEquipeFiltro.todas,
                    label: Text('Todas'),
                  ),
                  ButtonSegment(
                    value: SituacaoEquipeFiltro.ativas,
                    label: Text('Ativas'),
                  ),
                  ButtonSegment(
                    value: SituacaoEquipeFiltro.inativas,
                    label: Text('Inativas'),
                  ),
                ],
                selected: {_filtroSituacao},
                onSelectionChanged: (nova) {
                  setState(() => _filtroSituacao = nova.first);
                },
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchWidget,
                    const SizedBox(height: AppSpacing.s12),
                    filterWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchWidget),
                  const SizedBox(width: AppSpacing.s16),
                  filterWidget,
                ],
              );
            },
          ),
        ),
        if (_aviso != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: AppGeometry.cardBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.navy900, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _aviso!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.navy900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _aviso = null),
                      tooltip: 'Fechar aviso',
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: _construirCorpo()),
      ],
    );
  }

  Widget _construirCorpo() {
    return FutureBuilder<CatalogoResposta>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Semantics(
              label: 'Carregando equipes',
              child: const CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          final erroMsg = snapshot.error.toString();
          final ehNegado = erroMsg.contains('permission-denied') || erroMsg.contains('sem autoridade');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ehNegado ? Icons.lock_outline : Icons.error_outline,
                    size: 48,
                    color: ehNegado ? AppColors.warning : AppColors.danger,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    ehNegado
                        ? 'Acesso administrativo não autorizado.'
                        : 'Não foi possível carregar o catálogo de equipes.',
                    style: AppTypography.h3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    ehNegado
                        ? 'Esta funcionalidade requer privilégios de administrador do Maanaim.'
                        : 'Verifique sua conexão e tente novamente.',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  PrimaryButton(
                    onPressed: _carregar,
                    label: 'Tentar novamente',
                  ),
                ],
              ),
            ),
          );
        }

        final dados = snapshot.data!;
        final itens = _filtrar(dados.equipes);

        if (itens.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: EmptyState(
                title: _termo.isEmpty && _filtroSituacao == SituacaoEquipeFiltro.todas
                    ? 'Nenhuma equipe cadastrada'
                    : 'Nenhuma equipe encontrada para os filtros aplicados',
                message: 'Utilize o botão "Nova Equipe" acima para cadastrar a primeira equipe.',
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppDataTable<EquipeCatalogo>(
            items: itens,
            breakpoint: 768,
            columns: [
              AppDataColumn<EquipeCatalogo>(
                label: 'Nome da Equipe',
                cellBuilder: (item) => Text(
                  item.nome,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              AppDataColumn<EquipeCatalogo>(
                label: 'Situação',
                cellBuilder: (item) => item.ativo
                    ? const StatusChip(status: 'ATIVA', label: 'Ativa')
                    : const StatusChip(status: 'INATIVA', label: 'Inativa'),
              ),
              AppDataColumn<EquipeCatalogo>(
                label: 'Responsável Vigente Único',
                cellBuilder: (item) => Text(
                  item.responsavelNome ?? 'Não designado',
                  style: AppTypography.caption.copyWith(
                    color: item.responsavelNome != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontStyle: item.responsavelNome == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              AppDataColumn<EquipeCatalogo>(
                label: 'Ações',
                cellBuilder: (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Editar ${item.nome}',
                      onPressed: () => _abrirFormularioEquipe(equipeParaEdicao: item),
                    ),
                    IconButton(
                      icon: Icon(
                        item.ativo ? Icons.block_outlined : Icons.check_circle_outline,
                        size: 20,
                        color: item.ativo ? AppColors.danger : AppColors.blue600,
                      ),
                      tooltip: '${item.ativo ? "Inativar" : "Reativar"} ${item.nome}',
                      onPressed: _executando ? null : () => _confirmarAlternarEquipe(item),
                    ),
                    if (widget.onNavegarVinculos != null)
                      IconButton(
                        icon: const Icon(Icons.handshake_outlined, size: 20, color: AppColors.navy900),
                        tooltip: 'Vínculos do responsável',
                        onPressed: () => widget.onNavegarVinculos!(item),
                      ),
                  ],
                ),
              ),
            ],
            cardBuilder: (context, item) => _construirCardMobile(item),
          ),
        );
      },
    );
  }

  Widget _construirCardMobile(EquipeCatalogo item) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.nome,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.navy900),
                ),
              ),
              item.ativo
                  ? const StatusChip(status: 'ATIVA', label: 'Ativa')
                  : const StatusChip(status: 'INATIVA', label: 'Inativa'),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  'Responsável Único: ${item.responsavelNome ?? "Não designado"}',
                  style: AppTypography.caption.copyWith(
                    color: item.responsavelNome != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.s24),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                  onPressed: () => _abrirFormularioEquipe(equipeParaEdicao: item),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: item.ativo ? AppColors.danger : AppColors.blue600,
                    side: BorderSide(
                      color: item.ativo ? AppColors.danger : AppColors.blue600,
                    ),
                  ),
                  icon: Icon(
                    item.ativo ? Icons.block_outlined : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(item.ativo ? 'Inativar' : 'Reativar'),
                  onPressed: _executando ? null : () => _confirmarAlternarEquipe(item),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

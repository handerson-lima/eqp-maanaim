import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import 'catalogo_service.dart';

enum SituacaoIgrejaFiltro { todas, ativas, inativas }

/// S07 — Administração e Gestão de Igrejas.
/// Suporta tabela responsiva no desktop, cartões estruturados no mobile (<768px),
/// busca textual, filtro de situação e criação/edição autenticada via comandos no servidor.
class IgrejasScreen extends StatefulWidget {
  const IgrejasScreen({
    super.key,
    required this.gateway,
    this.onNavegarVinculos,
  });

  final CatalogoGateway gateway;
  final void Function(IgrejaCatalogo igreja)? onNavegarVinculos;

  @override
  State<IgrejasScreen> createState() => _IgrejasScreenState();
}

class _IgrejasScreenState extends State<IgrejasScreen> {
  late Future<CatalogoResposta> _futuro;
  final _buscaController = TextEditingController();
  String _termo = '';
  SituacaoIgrejaFiltro _filtroSituacao = SituacaoIgrejaFiltro.todas;
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

  List<IgrejaCatalogo> _filtrar(List<IgrejaCatalogo> lista) {
    var resultado = filtrarIgrejas(lista, _termo);
    switch (_filtroSituacao) {
      case SituacaoIgrejaFiltro.todas:
        break;
      case SituacaoIgrejaFiltro.ativas:
        resultado = resultado.where((i) => i.ativo).toList();
        break;
      case SituacaoIgrejaFiltro.inativas:
        resultado = resultado.where((i) => !i.ativo).toList();
        break;
    }
    return resultado;
  }

  Future<void> _abrirFormularioIgreja({IgrejaCatalogo? igrejaParaEdicao}) async {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: igrejaParaEdicao?.nome ?? '');
    final codigoController = TextEditingController(text: igrejaParaEdicao?.codigo ?? '');
    String? erroServidor;
    bool salvando = false;

    final salvo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final ehEdicao = igrejaParaEdicao != null;
          final titulo = ehEdicao ? 'Editar Igreja' : 'Nova Igreja';

          Future<void> submeter() async {
            if (!formKey.currentState!.validate()) return;

            setDialogState(() {
              salvando = true;
              erroServidor = null;
            });

            try {
              await widget.gateway.salvarIgreja(
                commandId: comandoOpaco(),
                igrejaId: igrejaParaEdicao?.id,
                codigo: codigoController.text.trim(),
                nome: nomeController.text.trim(),
                expectedVersion: igrejaParaEdicao?.versao ?? 0,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (e) {
              setDialogState(() {
                salvando = false;
                final msg = e.toString();
                if (msg.contains('already-exists') || msg.contains('duplicad')) {
                  erroServidor = 'Já existe uma igreja cadastrada com este código.';
                } else if (msg.contains('aborted') || msg.contains('concorrência')) {
                  erroServidor = 'Conflito de versão: a igreja foi alterada por outro usuário. Recarregue a página.';
                } else {
                  erroServidor = 'Não foi possível salvar a igreja. Verifique os dados e tente novamente.';
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
                          labelText: 'Nome da Igreja *',
                          hintText: 'Ex.: Central, Ponta Negra, etc.',
                        ),
                        validator: (valor) {
                          final v = valor?.trim() ?? '';
                          if (v.length < 3) return 'Nome deve ter no mínimo 3 caracteres';
                          if (v.length > 160) return 'Nome deve ter no máximo 160 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextFormField(
                        controller: codigoController,
                        enabled: !salvando,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código da Igreja (6 dígitos) *',
                          hintText: 'Ex.: 240001',
                        ),
                        validator: (valor) {
                          final v = valor?.trim() ?? '';
                          if (!RegExp(r'^\d{6}$').hasMatch(v)) {
                            return 'O código deve conter exatamente 6 dígitos numéricos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'O código de igreja é uma chave cadastral canônica (String) e preserva zeros à esquerda.',
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
                  label: salvando ? 'Salvando...' : 'Salvar Igreja',
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
          _aviso = igrejaParaEdicao == null
              ? 'Igreja "${nomeController.text.trim()}" cadastrada com sucesso.'
              : 'Igreja "${nomeController.text.trim()}" atualizada com sucesso.';
        });
        _carregar();
      }
    }
  }

  Future<void> _confirmarAlternarIgreja(IgrejaCatalogo igreja) async {
    final novoAtivo = !igreja.ativo;
    final acao = novoAtivo ? 'Reativar' : 'Inativar';
    final titulo = '$acao Igreja';
    final mensagem = novoAtivo
        ? 'Deseja reativar a igreja "${igreja.rotulo}"?\n\nEla voltará a ficar disponível para novos cadastros e seleções no catálogo.'
        : 'Deseja inativar a igreja "${igreja.rotulo}"?\n\nEla deixará de ser exibida em novos cadastros. Fichas e participações ativas existentes não serão afetadas.';

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
      await widget.gateway.alternarStatusIgreja(
        commandId: comandoOpaco(),
        igrejaId: igreja.id,
        ativo: novoAtivo,
      );
      if (!mounted) return;
      setState(() {
        _aviso = 'Igreja "${igreja.nome}" ${novoAtivo ? "reativada" : "inativada"} com sucesso.';
      });
      _carregar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aviso = 'Não foi possível alterar o status da igreja.';
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
            title: 'Gestão de Igrejas',
            subtitle: 'Catálogo institucional de igrejas e acompanhamento de pastores locais',
            action: PrimaryButton(
              icon: Icons.add,
              label: 'Nova Igreja',
              onPressed: () => _abrirFormularioIgreja(),
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
                  labelText: 'Pesquisar igreja por nome ou código',
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

              final filterWidget = SegmentedButton<SituacaoIgrejaFiltro>(
                segments: const [
                  ButtonSegment(
                    value: SituacaoIgrejaFiltro.todas,
                    label: Text('Todas'),
                  ),
                  ButtonSegment(
                    value: SituacaoIgrejaFiltro.ativas,
                    label: Text('Ativas'),
                  ),
                  ButtonSegment(
                    value: SituacaoIgrejaFiltro.inativas,
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
              label: 'Carregando igrejas',
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
                        : 'Não foi possível carregar o catálogo de igrejas.',
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
        final itens = _filtrar(dados.igrejas);

        if (itens.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: EmptyState(
                title: _termo.isEmpty && _filtroSituacao == SituacaoIgrejaFiltro.todas
                    ? 'Nenhuma igreja cadastrada'
                    : 'Nenhuma igreja encontrada para os filtros aplicados',
                message: 'Utilize o botão "Nova Igreja" acima para cadastrar a primeira unidade.',
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppDataTable<IgrejaCatalogo>(
            items: itens,
            breakpoint: 768,
            columns: [
              AppDataColumn<IgrejaCatalogo>(
                label: 'Nome da Igreja',
                cellBuilder: (item) => Text(
                  item.nome,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              AppDataColumn<IgrejaCatalogo>(
                label: 'Código',
                cellBuilder: (item) => Text(
                  item.codigo,
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.navy900),
                ),
              ),
              AppDataColumn<IgrejaCatalogo>(
                label: 'Situação',
                cellBuilder: (item) => item.ativo
                    ? const StatusChip(status: 'ATIVA', label: 'Ativa')
                    : const StatusChip(status: 'INATIVA', label: 'Inativa'),
              ),
              AppDataColumn<IgrejaCatalogo>(
                label: 'Pastor Local Vigente',
                cellBuilder: (item) => Text(
                  item.pastorLocalNome ?? 'Não designado',
                  style: AppTypography.caption.copyWith(
                    color: item.pastorLocalNome != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontStyle: item.pastorLocalNome == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              AppDataColumn<IgrejaCatalogo>(
                label: 'Ações',
                cellBuilder: (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Editar ${item.nome}',
                      onPressed: () => _abrirFormularioIgreja(igrejaParaEdicao: item),
                    ),
                    IconButton(
                      icon: Icon(
                        item.ativo ? Icons.block_outlined : Icons.check_circle_outline,
                        size: 20,
                        color: item.ativo ? AppColors.danger : AppColors.blue600,
                      ),
                      tooltip: '${item.ativo ? "Inativar" : "Reativar"} ${item.nome}',
                      onPressed: _executando ? null : () => _confirmarAlternarIgreja(item),
                    ),
                    if (widget.onNavegarVinculos != null)
                      IconButton(
                        icon: const Icon(Icons.handshake_outlined, size: 20, color: AppColors.navy900),
                        tooltip: 'Vínculos pastorais',
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

  Widget _construirCardMobile(IgrejaCatalogo item) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.navy900),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Código: ${item.codigo}',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.blue600),
                    ),
                  ],
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
                  'Pastor: ${item.pastorLocalNome ?? "Não designado"}',
                  style: AppTypography.caption.copyWith(
                    color: item.pastorLocalNome != null
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
                  onPressed: () => _abrirFormularioIgreja(igrejaParaEdicao: item),
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
                  onPressed: _executando ? null : () => _confirmarAlternarIgreja(item),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import 'pessoas_service.dart';
import 'vinculos_service.dart';

/// Tipo de mutação proposta para uma entidade no lote centrado no pastor/responsável.
enum TipoAcaoLote {
  inclusao,
  substituicao,
  encerramento,
  inalterado,
}

/// Ciclo de vida e monitoramento de execução desacoplada de cada intenção de vínculo.
enum EstadoItemLote {
  naoEnviado,
  processando,
  aguardandoRecibo,
  completo,
  falhou,
  conflito,
}

/// Intenção desacoplada de alteração de vínculo em lote. Cada item possui seu
/// próprio `commandId` estável e `expectedVersion` independente (UI-CONTRACTS §6).
class IntencaoItemLote {
  IntencaoItemLote({
    required this.item,
    required this.acao,
    required this.commandId,
    required this.expectedVersion,
    this.responsavelAtual,
    this.justificativa,
    this.estado = EstadoItemLote.naoEnviado,
    this.mensagemErro,
  });

  final ItemVinculo item;
  final TipoAcaoLote acao;
  String commandId;
  int expectedVersion;
  final ResponsavelVigente? responsavelAtual;
  String? justificativa;
  EstadoItemLote estado;
  String? mensagemErro;

  bool get temMudanca => acao != TipoAcaoLote.inalterado;
  bool get elegivelRetry => estado == EstadoItemLote.falhou;
}

bool _isConflitoErro(Object erro) {
  if (erro is FirebaseFunctionsException && erro.code == 'aborted') {
    return true;
  }
  final msg = erro.toString().toLowerCase();
  return msg.contains('aborted') ||
      msg.contains('conflito') ||
      msg.contains('versao');
}

/// Superfície administrativa mobile-first "Vínculos e Responsáveis" (S08).
/// Suporta tanto a gestão individual tradicional por igreja/equipe quanto a
/// gestão centrada no pastor/responsável com seleção múltipla, revisão de
/// consequências, execução desacoplada por item e retentativa seletiva.
class VinculosResponsaveis extends StatefulWidget {
  const VinculosResponsaveis(
    this.gateway, {
    super.key,
    this.pastorInicial,
  });

  final VinculosGateway gateway;
  final PessoaAdministrativa? pastorInicial;

  @override
  State<VinculosResponsaveis> createState() => _VinculosResponsaveisState();
}

class _VinculosResponsaveisState extends State<VinculosResponsaveis> {
  late Future<VinculosResposta> _futuro;
  final _busca = TextEditingController();
  String _termo = '';
  int _aba = 0; // 0: Igrejas, 1: Equipes
  bool _executando = false;
  String? _aviso;
  String? _erroAcao;

  // Estado do Modo Centrado no Pastor / Responsável (Story 8.12)
  PessoaAdministrativa? _pastorSelecionado;
  late DateTime _dataEfetiva;
  final Map<String, IntencaoItemLote> _intencoes = {};
  bool _executandoLote = false;
  bool _loteFinalizado = false;

  @override
  void initState() {
    super.initState();
    _pastorSelecionado = widget.pastorInicial;
    final agora = DateTime.now();
    _dataEfetiva = DateTime(agora.year, agora.month, agora.day);
    _futuro = widget.gateway.consultar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _recarregar() {
    setState(() {
      _futuro = widget.gateway.consultar();
    });
  }

  Future<bool> _confirmar(String titulo, String mensagem) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo, style: AppTypography.h3),
        content: Text(mensagem, style: AppTypography.body),
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.cardBorderRadius,
        ),
        actions: [
          SecondaryButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(dialogo, false),
          ),
          PrimaryButton(
            label: 'Confirmar',
            onPressed: () => Navigator.pop(dialogo, true),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  String _papel(ItemVinculo item) =>
      item.tipoEntidade == 'IGREJA' ? 'Pastor Local' : 'Responsável';

  String _rotuloPapelAtual() => _aba == 0 ? 'Pastor Local' : 'Responsável de Equipe';

  List<IntencaoItemLote> get _intencoesAtivas =>
      _intencoes.values.where((i) => i.temMudanca).toList();

  bool _isItemMarcado(ItemVinculo item) {
    final intencao = _intencoes[item.id];
    if (intencao != null) {
      if (intencao.acao == TipoAcaoLote.encerramento) return false;
      if (intencao.acao == TipoAcaoLote.inclusao ||
          intencao.acao == TipoAcaoLote.substituicao) {
        return true;
      }
    }
    return item.responsavel?.pessoaId == _pastorSelecionado?.uid;
  }

  Future<void> _abrirSelecaoPastor() async {
    final pessoa = await showDialog<PessoaAdministrativa>(
      context: context,
      builder: (_) => _SelecionarPessoa(widget.gateway),
    );
    if (pessoa != null && mounted) {
      setState(() {
        _pastorSelecionado = pessoa;
        _intencoes.clear();
        _loteFinalizado = false;
        _executandoLote = false;
      });
    }
  }

  void _voltarModoIndividual() {
    if (_intencoesAtivas.isNotEmpty && !_loteFinalizado) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text(
            'Você tem alterações não salvas neste lote. Deseja sair do modo por pastor?',
          ),
          actions: [
            SecondaryButton(
              label: 'Continuar editando',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            PrimaryButton(
              label: 'Descartar e voltar',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ).then((descartar) {
        if (descartar == true && mounted) {
          setState(() {
            _pastorSelecionado = null;
            _intencoes.clear();
            _loteFinalizado = false;
            _executandoLote = false;
          });
        }
      });
    } else {
      setState(() {
        _pastorSelecionado = null;
        _intencoes.clear();
        _loteFinalizado = false;
        _executandoLote = false;
      });
    }
  }

  Future<void> _escolherDataEfetivaLote() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final limite = DateTime(agora.year - 5, 1, 1);
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataEfetiva.isAfter(hoje) ? hoje : _dataEfetiva,
      firstDate: limite,
      lastDate: hoje,
      helpText: 'Data efetiva dos vínculos (não pode ser futura)',
    );
    if (escolhida != null && mounted) {
      setState(() => _dataEfetiva = escolhida);
    }
  }

  Future<void> _aoAlternarItemLote(ItemVinculo item, bool? valor) async {
    if (_executandoLote) return;
    final novoValor = valor ?? false;
    final jaEraDestePastor =
        item.responsavel?.pessoaId == _pastorSelecionado?.uid;

    if (!novoValor && jaEraDestePastor) {
      // Regra de Ouro: Desmarcar entidade atualmente vinculada NÃO encerra
      // automaticamente; exige confirmação explícita com justificativa.
      final justificativaController = TextEditingController();
      final papel = _papel(item);
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Confirmar encerramento de vínculo',
            style: AppTypography.h3,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desmarcar "${item.rotulo}" registrará o encerramento do vínculo de '
                  '"${_pastorSelecionado!.rotulo}" como $papel a partir de ${_formatarData(_dataEfetiva)}.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 8),
                Text(
                  'Apenas pendências não decididas serão afetadas. '
                  'Decisões tomadas anteriormente permanecem preservadas no histórico imutável.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: justificativaController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Justificativa do encerramento (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            PrimaryButton(
              label: 'Confirmar encerramento',
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );

      if (confirmado == true && mounted) {
        setState(() {
          _intencoes[item.id] = IntencaoItemLote(
            item: item,
            acao: TipoAcaoLote.encerramento,
            commandId: comandoOpaco(),
            expectedVersion: item.versaoVinculo,
            responsavelAtual: item.responsavel,
            justificativa: justificativaController.text.trim().isEmpty
                ? null
                : justificativaController.text.trim(),
          );
        });
      }
      return;
    }

    setState(() {
      if (novoValor) {
        if (jaEraDestePastor) {
          // Reverteu para o estado original vinculado
          _intencoes.remove(item.id);
        } else if (item.responsavel == null) {
          _intencoes[item.id] = IntencaoItemLote(
            item: item,
            acao: TipoAcaoLote.inclusao,
            commandId: comandoOpaco(),
            expectedVersion: item.versaoVinculo,
          );
        } else {
          _intencoes[item.id] = IntencaoItemLote(
            item: item,
            acao: TipoAcaoLote.substituicao,
            commandId: comandoOpaco(),
            expectedVersion: item.versaoVinculo,
            responsavelAtual: item.responsavel,
          );
        }
      } else {
        // Desmarcou uma entidade que não era originalmente deste pastor
        _intencoes.remove(item.id);
      }
    });
  }

  Future<void> _revisarLote() async {
    final ativas = _intencoesAtivas;
    if (ativas.isEmpty) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRevisaoLote(
        pastor: _pastorSelecionado!,
        dataEfetiva: _dataEfetiva,
        intencoes: ativas,
        papel: _rotuloPapelAtual(),
      ),
    );

    if (confirmou == true && mounted) {
      await _executarLote();
    }
  }

  Future<void> _executarLote({bool apenasFalhas = false}) async {
    setState(() {
      _executandoLote = true;
      _loteFinalizado = false;
    });

    final alvos = apenasFalhas
        ? _intencoesAtivas.where((i) => i.elegivelRetry).toList()
        : _intencoesAtivas.where((i) => i.estado != EstadoItemLote.completo).toList();

    for (final intencao in alvos) {
      if (!mounted) break;
      setState(() {
        intencao.estado = EstadoItemLote.processando;
      });
      // Aguardando recibo
      setState(() {
        intencao.estado = EstadoItemLote.aguardandoRecibo;
      });

      try {
        final acaoString = switch (intencao.acao) {
          TipoAcaoLote.inclusao => 'ATRIBUIR',
          TipoAcaoLote.substituicao => 'SUBSTITUIR',
          TipoAcaoLote.encerramento => 'ENCERRAR',
          TipoAcaoLote.inalterado => '',
        };
        if (acaoString.isEmpty) continue;

        await widget.gateway.gerenciar(
          commandId: intencao.commandId,
          tipoEntidade: intencao.item.tipoEntidade,
          entidadeId: intencao.item.id,
          acao: acaoString,
          pessoaId: intencao.acao == TipoAcaoLote.encerramento
              ? null
              : _pastorSelecionado!.uid,
          dataEfetiva: _dataEfetiva,
          versao: intencao.expectedVersion,
          justificativa: intencao.justificativa,
        );

        if (!mounted) break;
        setState(() {
          intencao.estado = EstadoItemLote.completo;
          intencao.mensagemErro = null;
        });
      } catch (e) {
        if (!mounted) break;
        final conflito = _isConflitoErro(e);
        setState(() {
          if (conflito) {
            intencao.estado = EstadoItemLote.conflito;
            intencao.mensagemErro =
                'Conflito de versão detectado. O vínculo foi modificado concorrentemente.';
          } else {
            intencao.estado = EstadoItemLote.falhou;
            intencao.mensagemErro = 'Falha ao processar comando.';
          }
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _executandoLote = false;
      _loteFinalizado = true;
    });

    final todosSucesso =
        _intencoesAtivas.every((i) => i.estado == EstadoItemLote.completo);
    if (todosSucesso) {
      _recarregar();
    }
  }

  Future<void> _reavaliarConflito(IntencaoItemLote intencao) async {
    try {
      final resp = await widget.gateway.consultar();
      final lista = intencao.item.tipoEntidade == 'IGREJA'
          ? resp.igrejas
          : resp.equipes;
      final itemAtualizado = lista.firstWhere((it) => it.id == intencao.item.id);

      if (!mounted) return;
      final reconfirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Conflito concorrente detectado', style: AppTypography.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A entidade "${itemAtualizado.rotulo}" teve seu vínculo modificado no servidor.',
                style: AppTypography.body,
              ),
              const SizedBox(height: 8),
              Text(
                'Versão esperada: ${intencao.expectedVersion} → Versão atual: ${itemAtualizado.versaoVinculo}',
                style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              if (itemAtualizado.temResponsavel) ...[
                const SizedBox(height: 4),
                Text(
                  'Responsável atual: ${itemAtualizado.responsavel!.rotulo}',
                  style: AppTypography.body,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Deseja atualizar a versão e gerar um novo comando para reconfirmar esta operação?',
                style: AppTypography.caption,
              ),
            ],
          ),
          actions: [
            SecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            PrimaryButton(
              label: 'Reconfirmar e Enviar',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (reconfirmado == true && mounted) {
        setState(() {
          intencao.expectedVersion = itemAtualizado.versaoVinculo;
          intencao.commandId = comandoOpaco(); // Novo commandId!
          intencao.estado = EstadoItemLote.naoEnviado;
          intencao.mensagemErro = null;
        });

        // Reenvia apenas este item
        setState(() {
          intencao.estado = EstadoItemLote.processando;
        });
        setState(() {
          intencao.estado = EstadoItemLote.aguardandoRecibo;
        });

        try {
          final acaoString = switch (intencao.acao) {
            TipoAcaoLote.inclusao => 'ATRIBUIR',
            TipoAcaoLote.substituicao => 'SUBSTITUIR',
            TipoAcaoLote.encerramento => 'ENCERRAR',
            TipoAcaoLote.inalterado => '',
          };

          await widget.gateway.gerenciar(
            commandId: intencao.commandId,
            tipoEntidade: intencao.item.tipoEntidade,
            entidadeId: intencao.item.id,
            acao: acaoString,
            pessoaId: intencao.acao == TipoAcaoLote.encerramento
                ? null
                : _pastorSelecionado!.uid,
            dataEfetiva: _dataEfetiva,
            versao: intencao.expectedVersion,
            justificativa: intencao.justificativa,
          );

          if (mounted) {
            setState(() {
              intencao.estado = EstadoItemLote.completo;
              intencao.mensagemErro = null;
            });
            _recarregar();
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              intencao.estado =
                  _isConflitoErro(e) ? EstadoItemLote.conflito : EstadoItemLote.falhou;
              intencao.mensagemErro = 'Falha ao reprocessar item.';
            });
          }
        }
      }
    } catch (_) {}
  }

  void _concluirLote() {
    setState(() {
      _intencoes.clear();
      _loteFinalizado = false;
      _executandoLote = false;
      _futuro = widget.gateway.consultar();
    });
  }

  Future<void> _abrirAcao(ItemVinculo item, String acao) async {
    PessoaAdministrativa? pessoa;
    if (acao != 'ENCERRAR') {
      pessoa = await showDialog<PessoaAdministrativa>(
        context: context,
        builder: (_) => _SelecionarPessoa(widget.gateway),
      );
      if (pessoa == null || !mounted) return;
    }
    final primeira = _primeiraData(item);
    final agoraLocal = DateTime.now();
    final ultima = DateTime(agoraLocal.year, agoraLocal.month, agoraLocal.day);
    final dados = await showDialog<_DadosVinculo>(
      context: context,
      builder: (_) => _FormularioVinculo(
        item: item,
        acao: acao,
        pessoa: pessoa,
        primeiraData: primeira.isAfter(ultima) ? ultima : primeira,
        ultimaData: ultima,
      ),
    );
    if (dados == null || !mounted) return;

    final data = _formatarData(dados.data);
    final papel = _papel(item);
    final mensagem = switch (acao) {
      'ATRIBUIR' =>
        'Atribuir ${pessoa!.rotulo} como $papel de ${item.rotulo} a partir de $data?',
      'SUBSTITUIR' =>
        'Encerrar o vínculo de ${item.responsavel?.rotulo ?? '—'} e atribuir '
            '${pessoa!.rotulo} como $papel de ${item.rotulo} em $data?',
      _ =>
        'Encerrar o vínculo de ${item.responsavel?.rotulo ?? '—'} em '
            '${item.rotulo} a partir de $data?',
    };
    final confirmado = await _confirmar(
      acao == 'ENCERRAR' ? 'Encerrar vínculo' : 'Confirmar $papel',
      mensagem,
    );
    if (!confirmado || !mounted) return;

    setState(() {
      _executando = true;
      _erroAcao = null;
    });
    try {
      await widget.gateway.gerenciar(
        commandId: comandoOpaco(),
        tipoEntidade: item.tipoEntidade,
        entidadeId: item.id,
        acao: acao,
        pessoaId: pessoa?.uid,
        dataEfetiva: dados.data,
        versao: item.versaoVinculo,
        justificativa: dados.justificativa,
      );
      if (!mounted) return;
      setState(() {
        _aviso = switch (acao) {
          'ATRIBUIR' => 'Responsável atribuído.',
          'SUBSTITUIR' => 'Responsável substituído.',
          _ => 'Vínculo encerrado.',
        };
        _erroAcao = null;
        _executando = false;
        _futuro = widget.gateway.consultar();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroAcao =
            'Não foi possível concluir a operação. Recarregue e tente novamente.';
        _aviso = null;
        _executando = false;
      });
    }
  }

  DateTime _primeiraData(ItemVinculo item) {
    final agora = DateTime.now();
    var limite = DateTime(agora.year - 5, 1, 1);
    for (final evento in item.historico) {
      if (!evento.vigente || evento.inicioVigencia == null) continue;
      final inicio = evento.inicioVigencia!;
      final data = DateTime(inicio.year, inicio.month, inicio.day);
      if (data.isAfter(limite)) limite = data;
    }
    return limite;
  }

  String _dataDaTroca(ItemVinculo item) {
    for (final evento in item.historico) {
      if (evento.vigente) return _formatarDataEvento(evento.inicioVigencia);
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Vínculos e Responsáveis',
              subtitle:
                  'Mantenha exatamente um responsável vigente por igreja e equipe. '
                  'A troca encerra o vínculo anterior sem apagar o histórico.',
            ),
            const SizedBox(height: 12),
            if (_pastorSelecionado == null) ...[
              _bannerModoPastor(),
              const SizedBox(height: 12),
              _seletorAbas(),
              const SizedBox(height: 12),
              _campoBusca(),
            ] else ...[
              _cabecalhoPastor(),
              const SizedBox(height: 12),
              _seletorAbas(),
            ],
            if (_aviso != null)
              _faixa(
                _aviso!,
                AppColors.successBg,
                Icons.check_circle_outline,
              ),
            if (_erroAcao != null)
              _faixa(
                _erroAcao!,
                AppColors.dangerBg,
                Icons.error_outline,
                trailing: TextButton(
                  onPressed: _recarregar,
                  child: const Text('Recarregar'),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: _pastorSelecionado == null ? _corpoIndividual() : _corpoLote(),
      ),
    ],
  );

  Widget _bannerModoPastor() => SectionCard(
    child: Row(
      children: [
        const Icon(Icons.hub_outlined, color: AppColors.blue600, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestão Centrada no Pastor / Responsável',
                style: AppTypography.h3,
              ),
              const SizedBox(height: 4),
              Text(
                'Vincule múltiplas igrejas ou equipes simultaneamente a partir de uma pessoa com revisão de consequências.',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PrimaryButton(
          label: 'Vincular por pastor',
          icon: Icons.person_search,
          onPressed: _abrirSelecaoPastor,
        ),
      ],
    ),
  );

  Widget _cabecalhoPastor() => SectionCard(
    child: FutureBuilder<VinculosResposta>(
      future: _futuro,
      builder: (context, snapshot) {
        final totalVinculos = snapshot.hasData
            ? (_aba == 0
                ? snapshot.data!.igrejas
                    .where((i) => i.responsavel?.pessoaId == _pastorSelecionado!.uid)
                    .length
                : snapshot.data!.equipes
                    .where((e) => e.responsavel?.pessoaId == _pastorSelecionado!.uid)
                    .length)
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.blue50,
                  foregroundColor: AppColors.blue600,
                  radius: 20,
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pastorSelecionado!.rotulo, style: AppTypography.h3),
                      if (_pastorSelecionado!.email.isNotEmpty)
                        Text(
                          _pastorSelecionado!.email,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  status: 'ATIVA',
                  label: _rotuloPapelAtual(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _aba == 0 ? Icons.church_outlined : Icons.groups_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalVinculos ${_aba == 0 ? 'igreja(s)' : 'equipe(s)'}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _executandoLote ? null : _abrirSelecaoPastor,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Trocar pessoa'),
                    ),
                    TextButton.icon(
                      onPressed: _executandoLote ? null : _voltarModoIndividual,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Voltar ao modo individual'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _seletorAbas() => Semantics(
    label: 'Selecionar entre igrejas e equipes',
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          icon: Icon(Icons.church_outlined),
          label: Text('Igrejas'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.groups_outlined),
          label: Text('Equipes'),
        ),
      ],
      selected: {_aba},
      onSelectionChanged: _executandoLote
          ? null
          : (valor) {
              setState(() {
                _aba = valor.first;
                _intencoes.clear();
                _loteFinalizado = false;
              });
            },
    ),
  );

  Widget _campoBusca() => TextField(
    controller: _busca,
    onChanged: (valor) => setState(() => _termo = valor),
    textInputAction: TextInputAction.search,
    decoration: const InputDecoration(
      labelText: 'Pesquisar por nome ou código',
      prefixIcon: Icon(Icons.search),
    ),
  );

  Widget _faixa(
    String texto,
    Color cor,
    IconData icone, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: cor,
          borderRadius: AppGeometry.cardBorderRadius,
          border: Border.all(
            color: AppColors.border,
            width: AppGeometry.borderWidth,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icone),
            const SizedBox(width: 12),
            Expanded(child: Text(texto)),
            if (trailing != null) trailing,
          ],
        ),
      ),
    ),
  );

  Widget _corpoIndividual() => FutureBuilder<VinculosResposta>(
    future: _futuro,
    builder: (context, estado) {
      if (estado.hasError) {
        return _mensagem(
          'Não foi possível carregar os vínculos.',
          comRetentativa: true,
        );
      }
      if (!estado.hasData) {
        return Center(
          child: Semantics(
            label: 'Carregando vínculos e responsáveis',
            child: const CircularProgressIndicator(),
          ),
        );
      }
      final dados = estado.data!;
      final itens = filtrarVinculos(
        _aba == 0 ? dados.igrejas : dados.equipes,
        _termo,
      );
      if (itens.isEmpty) {
        final base = _aba == 0 ? dados.igrejas : dados.equipes;
        return _mensagem(
          base.isEmpty
              ? (_aba == 0
                    ? 'Nenhuma igreja cadastrada.'
                    : 'Nenhuma equipe cadastrada.')
              : 'Nenhum resultado encontrado.',
          comRetentativa: false,
        );
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [for (final item in itens) _cartao(item)],
      );
    },
  );

  Widget _corpoLote() => FutureBuilder<VinculosResposta>(
    future: _futuro,
    builder: (context, estado) {
      if (estado.hasError) {
        return _mensagem(
          'Não foi possível carregar os vínculos para seleção.',
          comRetentativa: true,
        );
      }
      if (!estado.hasData) {
        return Center(
          child: Semantics(
            label: 'Carregando lista de entidades',
            child: const CircularProgressIndicator(),
          ),
        );
      }

      final dados = estado.data!;
      final todos = _aba == 0 ? dados.igrejas : dados.equipes;
      final filtrados = filtrarVinculos(todos, _termo);

      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          if (isDesktop) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _colunaSelecaoEntidades(
                      filtrados,
                      todos.isEmpty,
                      isDesktop: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _colunaRevisaoLote(),
                  ),
                ],
              ),
            );
          } else {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _colunaSelecaoEntidades(
                  filtrados,
                  todos.isEmpty,
                  isDesktop: false,
                ),
                const SizedBox(height: 16),
                _colunaRevisaoLote(),
              ],
            );
          }
        },
      );
    },
  );

  Widget _colunaSelecaoEntidades(
    List<ItemVinculo> itens,
    bool baseVazia, {
    required bool isDesktop,
  }) {
    if (baseVazia) {
      return _mensagem(
        _aba == 0
            ? 'Nenhuma igreja cadastrada.'
            : 'Nenhuma equipe cadastrada.',
        comRetentativa: false,
      );
    }

    final listaTiles = [
      for (final item in itens)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppGeometry.cardBorderRadius,
              side: BorderSide(
                color: _isItemMarcado(item) ? AppColors.blue600 : AppColors.border,
                width: _isItemMarcado(item) ? 1.5 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: _isItemMarcado(item),
              onChanged: !item.ativo || _executandoLote
                  ? null
                  : (val) => _aoAlternarItemLote(item, val),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.rotulo,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!item.ativo)
                    const StatusChip(
                      status: 'INATIVA',
                      label: 'Inativa',
                    ),
                ],
              ),
              subtitle: Text(
                _subtituloEntidade(item),
                style: AppTypography.caption.copyWith(
                  color: (item.temResponsavel &&
                          item.responsavel?.pessoaId != _pastorSelecionado?.uid)
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ),
    ];

    final cabecalho = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campoBusca(),
        const SizedBox(height: 8),
        Text(
          'Selecione as ${_aba == 0 ? 'igrejas' : 'equipes'} a serem vinculadas a este pastor:',
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
      ],
    );

    if (itens.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecalho,
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum resultado encontrado.')),
          ),
        ],
      );
    }

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecalho,
          Expanded(
            child: ListView(
              children: listaTiles,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecalho,
        ...listaTiles,
      ],
    );
  }

  String _subtituloEntidade(ItemVinculo item) {
    final jaEraDestePastor =
        item.responsavel?.pessoaId == _pastorSelecionado?.uid;
    final temOutro = item.temResponsavel && !jaEraDestePastor;

    if (jaEraDestePastor) {
      return 'Vínculo vigente com este pastor';
    } else if (temOutro) {
      return 'Responsável atual: ${item.responsavel!.rotulo} (substituição)';
    } else {
      return 'Sem responsável vigente (inclusão)';
    }
  }

  Widget _colunaRevisaoLote() {
    final ativas = _intencoesAtivas;

    return SingleChildScrollView(
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: AppColors.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Painel de Revisão e Ações', style: AppTypography.h3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _executandoLote ? null : _escolherDataEfetivaLote,
            icon: const Icon(Icons.event),
            label: Text('Data efetiva: ${_formatarData(_dataEfetiva)}'),
          ),
          const SizedBox(height: 12),
          if (_executandoLote || _loteFinalizado) ...[
            _painelMonitorExecucao(),
          ] else ...[
            if (ativas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhuma alteração selecionada para este pastor.\n'
                    'Marque ou desmarque entidades na lista à esquerda para configurar as intenções de vínculo.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                'Alterações preparadas (${ativas.length}):',
                style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ativas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final intencao = ativas[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _iconeTipoAcao(intencao.acao),
                    title: Text(intencao.item.rotulo, style: AppTypography.body),
                    subtitle: Text(
                      _descricaoAcao(intencao),
                      style: AppTypography.caption.copyWith(
                        color: intencao.acao == TipoAcaoLote.substituicao
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Revisar e Salvar Vínculos (${ativas.length})',
                icon: Icons.checklist,
                onPressed: _revisarLote,
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

  Widget _painelMonitorExecucao() {
    final ativas = _intencoesAtivas;
    final concluidos =
        ativas.where((i) => i.estado == EstadoItemLote.completo).length;
    final falhas =
        ativas.where((i) => i.estado == EstadoItemLote.falhou).length;
    final conflitos =
        ativas.where((i) => i.estado == EstadoItemLote.conflito).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: falhas > 0 || conflitos > 0
                  ? AppColors.warningBg
                  : AppColors.successBg,
              borderRadius: AppGeometry.cardBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _executandoLote
                      ? 'Processando comandos de vínculo...'
                      : 'Resumo da Execução:',
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$concluidos concluído(s) com sucesso · $falhas falha(s) · $conflitos conflito(s)',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ativas.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
              final intencao = ativas[idx];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _iconeEstadoLote(intencao.estado),
                title: Text(intencao.item.rotulo, style: AppTypography.body),
                subtitle: Text(
                  intencao.mensagemErro ?? _rotuloEstadoLote(intencao.estado),
                  style: AppTypography.caption.copyWith(
                    color: intencao.estado == EstadoItemLote.falhou
                        ? AppColors.danger
                        : intencao.estado == EstadoItemLote.conflito
                            ? AppColors.warning
                            : AppColors.textSecondary,
                  ),
                ),
                trailing: intencao.estado == EstadoItemLote.conflito
                    ? OutlinedButton(
                        onPressed: () => _reavaliarConflito(intencao),
                        child: const Text('Atualizar e reavaliar'),
                      )
                    : null,
              );
            },
          ),
        const SizedBox(height: 16),
        if (!_executandoLote) ...[
          if (falhas > 0)
            PrimaryButton(
              label: 'Tentar novamente falhas ($falhas)',
              icon: Icons.refresh,
              onPressed: () => _executarLote(apenasFalhas: true),
            ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Concluir e Recarregar',
            icon: Icons.done_all,
            onPressed: _concluirLote,
          ),
        ],
      ],
    );
  }

  Widget _iconeTipoAcao(TipoAcaoLote acao) => switch (acao) {
    TipoAcaoLote.inclusao => const Icon(
        Icons.add_circle_outline,
        color: AppColors.success,
      ),
    TipoAcaoLote.substituicao => const Icon(
        Icons.swap_horiz,
        color: AppColors.warning,
      ),
    TipoAcaoLote.encerramento => const Icon(
        Icons.link_off,
        color: AppColors.danger,
      ),
    TipoAcaoLote.inalterado => const Icon(
        Icons.check,
        color: AppColors.textSecondary,
      ),
  };

  String _descricaoAcao(IntencaoItemLote intencao) => switch (intencao.acao) {
    TipoAcaoLote.inclusao => 'Novo vínculo a ser atribuído.',
    TipoAcaoLote.substituicao =>
      'Substitui ${intencao.responsavelAtual?.rotulo ?? '—'}. '
          'Apenas pendências não decididas serão redirecionadas. Decisões históricas são preservadas.',
    TipoAcaoLote.encerramento =>
      'Encerramento do vínculo vigente a partir da data efetiva.',
    TipoAcaoLote.inalterado => 'Sem alteração.',
  };

  Widget _iconeEstadoLote(EstadoItemLote estado) => switch (estado) {
    EstadoItemLote.naoEnviado => const Icon(
        Icons.schedule,
        color: AppColors.textSecondary,
      ),
    EstadoItemLote.processando => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    EstadoItemLote.aguardandoRecibo => const Icon(
        Icons.hourglass_empty,
        color: AppColors.blue600,
      ),
    EstadoItemLote.completo => const Icon(
        Icons.check_circle_outline,
        color: AppColors.success,
      ),
    EstadoItemLote.falhou => const Icon(
        Icons.error_outline,
        color: AppColors.danger,
      ),
    EstadoItemLote.conflito => const Icon(
        Icons.warning_amber,
        color: AppColors.warning,
      ),
  };

  String _rotuloEstadoLote(EstadoItemLote estado) => switch (estado) {
    EstadoItemLote.naoEnviado => 'Não enviado',
    EstadoItemLote.processando => 'Processando comando...',
    EstadoItemLote.aguardandoRecibo => 'Aguardando recibo...',
    EstadoItemLote.completo => 'Concluído com sucesso',
    EstadoItemLote.falhou => 'Falhou',
    EstadoItemLote.conflito => 'Conflito de versão',
  };

  Widget _mensagem(String texto, {required bool comRetentativa}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(liveRegion: true, child: Text(texto)),
          if (comRetentativa) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              onPressed: _recarregar,
              label: 'Tentar novamente',
            ),
          ],
        ],
      ),
    ),
  );

  Widget _cartao(ItemVinculo item) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.tipoEntidade == 'IGREJA'
                    ? Icons.church_outlined
                    : Icons.groups_outlined,
                color: AppColors.blue600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.rotulo,
                  style: AppTypography.h3,
                ),
              ),
              if (!item.ativo)
                const StatusChip(
                  status: 'INATIVA',
                  label: 'Inativa',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: item.temResponsavel
                ? 'Responsável vigente: ${item.responsavel!.rotulo}'
                : 'Sem responsável vigente',
            child: Row(
              children: [
                Icon(
                  item.temResponsavel
                      ? Icons.verified_user_outlined
                      : Icons.person_off_outlined,
                  size: 20,
                  color: item.temResponsavel
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.temResponsavel
                        ? 'Vigente: ${item.responsavel!.rotulo}'
                        : 'Sem responsável vigente',
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
          if (item.temResponsavel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Data da troca: ${_dataDaTroca(item)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!item.ativo)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Igreja/equipe inativa: as ações de vínculo estão indisponíveis.',
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!item.temResponsavel)
                PrimaryButton(
                  onPressed: _executando || !item.ativo
                      ? null
                      : () => _abrirAcao(item, 'ATRIBUIR'),
                  icon: Icons.person_add_alt,
                  label: 'Atribuir responsável',
                )
              else ...[
                PrimaryButton(
                  onPressed: _executando || !item.ativo
                      ? null
                      : () => _abrirAcao(item, 'SUBSTITUIR'),
                  icon: Icons.swap_horiz,
                  label: 'Substituir responsável',
                ),
                SecondaryButton(
                  onPressed: _executando || !item.ativo
                      ? null
                      : () => _abrirAcao(item, 'ENCERRAR'),
                  icon: Icons.link_off,
                  label: 'Encerrar vínculo',
                ),
              ],
            ],
          ),
          if (item.historico.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: const Icon(
                  Icons.history,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  'Linha do tempo (somente leitura)',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  for (final evento in item.historico) _evento(evento),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _evento(EventoHistoricoVinculo evento) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(
      evento.vigente ? Icons.check_circle_outline : Icons.history_toggle_off,
    ),
    title: Text(
      '${rotuloAcaoVinculo(evento.acao)} · ${rotuloPapelVinculo(evento.papel)}',
    ),
    subtitle: Text(
      [
        'Ator: ${evento.atorRotulo}',
        'Início: ${_formatarDataEvento(evento.inicioVigencia)}'
            '${evento.fimVigencia == null ? ' (vigente)' : ' · Fim: ${_formatarDataEvento(evento.fimVigencia)}'}',
        if (evento.justificativa != null &&
            evento.justificativa!.isNotEmpty)
          'Justificativa: ${evento.justificativa}',
      ].join('\n'),
    ),
    isThreeLine: true,
  );
}

class _DadosVinculo {
  const _DadosVinculo({
    required this.data,
    required this.justificativa,
  });

  final DateTime data;
  final String? justificativa;
}

class _FormularioVinculo extends StatefulWidget {
  const _FormularioVinculo({
    required this.item,
    required this.acao,
    required this.pessoa,
    required this.primeiraData,
    required this.ultimaData,
  });

  final ItemVinculo item;
  final String acao;
  final PessoaAdministrativa? pessoa;
  final DateTime primeiraData;
  final DateTime ultimaData;

  @override
  State<_FormularioVinculo> createState() => _FormularioVinculoState();
}

class _FormularioVinculoState extends State<_FormularioVinculo> {
  late DateTime _data = widget.ultimaData;
  final _justificativa = TextEditingController();

  @override
  void dispose() {
    _justificativa.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: widget.primeiraData,
      lastDate: widget.ultimaData,
      helpText: 'Data efetiva (não pode ser futura)',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.acao == 'ENCERRAR'
          ? 'Encerrar vínculo'
          : widget.acao == 'SUBSTITUIR'
          ? 'Substituir responsável'
          : 'Atribuir responsável',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.item.rotulo),
          if (widget.item.responsavel != null) ...[
            const SizedBox(height: 8),
            Text('Responsável atual: ${widget.item.responsavel!.rotulo}'),
          ],
          if (widget.pessoa != null) ...[
            const SizedBox(height: 8),
            Text('Nova pessoa: ${widget.pessoa!.rotulo}'),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _escolherData,
            icon: const Icon(Icons.event),
            label: Text('Data efetiva: ${_formatarData(_data)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _justificativa,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Justificativa (opcional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      SecondaryButton(
        onPressed: () => Navigator.pop(context),
        label: 'Cancelar',
      ),
      PrimaryButton(
        onPressed: () => Navigator.pop(
          context,
          _DadosVinculo(
            data: _data,
            justificativa: _justificativa.text.trim().isEmpty
                ? null
                : _justificativa.text.trim(),
          ),
        ),
        label: 'Continuar',
      ),
    ],
  );
}

class _SelecionarPessoa extends StatefulWidget {
  const _SelecionarPessoa(this.gateway);

  final VinculosGateway gateway;

  @override
  State<_SelecionarPessoa> createState() => _SelecionarPessoaState();
}

class _SelecionarPessoaState extends State<_SelecionarPessoa> {
  late final Future<List<PessoaAdministrativa>> _futuro =
      widget.gateway.buscarPessoas();
  final _busca = TextEditingController();
  String _termo = '';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Selecionar pessoa'),
    content: SizedBox(
      width: 420,
      height: 360,
      child: Column(
        children: [
          TextField(
            controller: _busca,
            onChanged: (valor) => setState(() => _termo = valor),
            decoration: const InputDecoration(
              labelText: 'Pesquisar pessoa por nome ou e-mail',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<PessoaAdministrativa>>(
              future: _futuro,
              builder: (context, estado) {
                if (estado.hasError) {
                  return Semantics(
                    liveRegion: true,
                    child: const Center(
                      child: Text('Não foi possível carregar as pessoas.'),
                    ),
                  );
                }
                if (!estado.hasData) {
                  return Center(
                    child: Semantics(
                      label: 'Carregando pessoas',
                      child: const CircularProgressIndicator(),
                    ),
                  );
                }
                final pessoas = filtrarPessoas(estado.data!, _termo);
                if (pessoas.isEmpty) {
                  return const Center(child: Text('Nenhuma pessoa encontrada.'));
                }
                return ListView(
                  children: [
                    for (final pessoa in pessoas)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(pessoa.rotulo),
                        subtitle: pessoa.email.isEmpty
                            ? null
                            : Text(pessoa.email),
                        onTap: () => Navigator.pop(context, pessoa),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      SecondaryButton(
        onPressed: () => Navigator.pop(context),
        label: 'Cancelar',
      ),
    ],
  );
}

class _DialogoRevisaoLote extends StatelessWidget {
  const _DialogoRevisaoLote({
    required this.pastor,
    required this.dataEfetiva,
    required this.intencoes,
    required this.papel,
  });

  final PessoaAdministrativa pastor;
  final DateTime dataEfetiva;
  final List<IntencaoItemLote> intencoes;
  final String papel;

  @override
  Widget build(BuildContext context) {
    final inclusoes =
        intencoes.where((i) => i.acao == TipoAcaoLote.inclusao).toList();
    final substituicoes =
        intencoes.where((i) => i.acao == TipoAcaoLote.substituicao).toList();
    final encerramentos =
        intencoes.where((i) => i.acao == TipoAcaoLote.encerramento).toList();

    return AlertDialog(
      title: Text('Revisão de Vínculos em Lote', style: AppTypography.h3),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pessoa selecionada: ${pastor.rotulo} ($papel)'),
              const SizedBox(height: 4),
              Text('Data efetiva: ${_formatarData(dataEfetiva)}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.neutral50,
                  borderRadius: AppGeometry.cardBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      '${inclusoes.length} inclusão(ões)',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      '${substituicoes.length} substituição(ões)',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    Text(
                      '${encerramentos.length} encerramento(s)',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Detalhamento das consequências:',
                style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final i in intencoes) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (i.acao) {
                          TipoAcaoLote.inclusao => '[+] ',
                          TipoAcaoLote.substituicao => '[⇄] ',
                          TipoAcaoLote.encerramento => '[-] ',
                          TipoAcaoLote.inalterado => '[=] ',
                        },
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          switch (i.acao) {
                            TipoAcaoLote.inclusao =>
                              '${i.item.rotulo}: Nova atribuição',
                            TipoAcaoLote.substituicao =>
                              '${i.item.rotulo}: Substitui ${i.responsavelAtual?.rotulo ?? '—'} (apenas pendências não decididas serão redirecionadas)',
                            TipoAcaoLote.encerramento =>
                              '${i.item.rotulo}: Encerramento de vínculo vigente',
                            TipoAcaoLote.inalterado => '${i.item.rotulo}: Inalterado',
                          },
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: AppGeometry.cardBorderRadius,
                ),
                child: Text(
                  'Cada alteração será orquestrada como um comando independente e idempotente. '
                  'Decisões tomadas anteriormente permanecem preservadas.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        SecondaryButton(
          label: 'Voltar e editar',
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'Confirmar e Salvar Vínculos',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

String _formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Data efetiva (dia escolhido) em UTC, sem hora: o backend grava a data como
/// meia-noite UTC, então converter para o fuso local deslocaria o dia.
String _formatarDataEvento(DateTime? data) =>
    data == null ? '—' : _formatarData(data.toUtc());

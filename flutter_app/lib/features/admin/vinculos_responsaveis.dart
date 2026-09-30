import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import 'pessoas_service.dart';
import 'vinculos_service.dart';

/// Superfície administrativa mobile-first "Vínculos e Responsáveis": abas
/// Igrejas/Equipes, responsável vigente, atribuição/substituição/encerramento
/// com data efetiva e linha do tempo somente leitura.
class VinculosResponsaveis extends StatefulWidget {
  const VinculosResponsaveis(this.gateway, {super.key});

  final VinculosGateway gateway;

  @override
  State<VinculosResponsaveis> createState() => _VinculosResponsaveisState();
}

class _VinculosResponsaveisState extends State<VinculosResponsaveis> {
  late Future<VinculosResposta> _futuro;
  final _busca = TextEditingController();
  String _termo = '';
  int _aba = 0;
  bool _executando = false;
  String? _aviso;
  String? _erroAcao;

  @override
  void initState() {
    super.initState();
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
            Semantics(
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
                onSelectionChanged: (valor) =>
                    setState(() => _aba = valor.first),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _busca,
              onChanged: (valor) => setState(() => _termo = valor),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Pesquisar por nome ou código',
                prefixIcon: Icon(Icons.search),
              ),
            ),
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
      Expanded(child: _corpo()),
    ],
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

  Widget _corpo() => FutureBuilder<VinculosResposta>(
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

String _formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Data efetiva (dia escolhido) em UTC, sem hora: o backend grava a data como
/// meia-noite UTC, então converter para o fuso local deslocaria o dia.
String _formatarDataEvento(DateTime? data) =>
    data == null ? '—' : _formatarData(data.toUtc());

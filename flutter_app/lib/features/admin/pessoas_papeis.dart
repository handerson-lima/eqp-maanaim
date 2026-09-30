import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comando.dart';
import 'pessoas_service.dart';

/// Superfície administrativa mobile-first de pessoas e papéis. Papéis efetivos
/// e contexto ativo são exibidos apenas como leitura, sem seletor de troca.
class PessoasPapeis extends StatefulWidget {
  const PessoasPapeis(this.gateway, {super.key});

  final PessoasGateway gateway;

  @override
  State<PessoasPapeis> createState() => _PessoasPapeisState();
}

class _PessoasPapeisState extends State<PessoasPapeis> {
  late Future<PessoasResposta> _futuro;
  final _busca = TextEditingController();
  String _termo = '';
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
      _futuro = widget.gateway.consultar(termo: _termo);
    });
  }

  Future<bool> _confirmar(String titulo, String mensagem) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _alterarPapel(
    PessoaAdministrativa pessoa,
    String papel,
    bool conceder,
  ) async {
    final rotulo = rotuloPapel(papel);
    final confirmado = await _confirmar(
      conceder ? 'Conceder $rotulo' : 'Revogar $rotulo',
      '${conceder ? 'Conceder' : 'Revogar'} o papel de $rotulo '
      '${conceder ? 'a' : 'de'} ${pessoa.rotulo}? '
      'A decisão é registrada na auditoria e passa a valer na hora.',
    );
    if (!confirmado || !mounted) return;
    setState(() {
      _executando = true;
      _erroAcao = null;
    });
    try {
      await widget.gateway.alterarPapeis(
        commandId: comandoOpaco(),
        alvoUid: pessoa.uid,
        versao: pessoa.versao,
        papel: papel,
        conceder: conceder,
      );
      if (!mounted) return;
      setState(() {
        _aviso = '${conceder ? 'Papel concedido' : 'Papel revogado'}: $rotulo.';
        _executando = false;
        _futuro = widget.gateway.consultar(termo: _termo);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroAcao =
            'Não foi possível atualizar o papel. Recarregue a lista e tente novamente.';
        _executando = false;
      });
    }
  }

  Future<void> _abrirFormulario([PessoaAdministrativa? pessoa]) async {
    final dados = await showDialog<_DadosPessoa>(
      context: context,
      builder: (_) => _FormularioPessoa(pessoa: pessoa),
    );
    if (dados == null || !mounted) return;
    setState(() {
      _executando = true;
      _erroAcao = null;
    });
    try {
      await widget.gateway.salvarPessoa(
        commandId: comandoOpaco(),
        uid: pessoa?.uid,
        nomeCompleto: dados.nomeCompleto,
        email: dados.email,
        coordenador: dados.coordenador,
        cpf: dados.cpf,
      );
      if (!mounted) return;
      setState(() {
        _aviso = pessoa == null ? 'Pessoa cadastrada.' : 'Cadastro atualizado.';
        _executando = false;
        _futuro = widget.gateway.consultar(termo: _termo);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroAcao =
            'Não foi possível salvar o cadastro. Revise os campos e tente novamente.';
        _executando = false;
      });
    }
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
            Semantics(
              header: true,
              child: Text(
                'Pessoas e Papéis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gerencie o perfil e os papéis de sistema. Identidade, perfil e '
              'papel são fontes separadas.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _busca,
              onChanged: (valor) => setState(() => _termo = valor),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Pesquisar por nome ou e-mail',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _executando ? null : () => _abrirFormulario(),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Cadastrar pessoa'),
              ),
            ),
            if (_aviso != null)
              _faixa(
                _aviso!,
                Theme.of(context).colorScheme.primaryContainer,
                Icons.check_circle_outline,
              ),
            if (_erroAcao != null)
              _faixa(
                _erroAcao!,
                Theme.of(context).colorScheme.errorContainer,
                Icons.error_outline,
              ),
          ],
        ),
      ),
      Expanded(child: _corpo()),
    ],
  );

  Widget _faixa(String texto, Color cor, IconData icone) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Card(
        color: cor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icone),
              const SizedBox(width: 12),
              Expanded(child: Text(texto)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _corpo() => FutureBuilder<PessoasResposta>(
    future: _futuro,
    builder: (context, estado) {
      if (estado.hasError) {
        return _mensagem(
          'Não foi possível carregar pessoas e papéis.',
          comRetentativa: true,
        );
      }
      if (!estado.hasData) {
        return Center(
          child: Semantics(
            label: 'Carregando pessoas e papéis',
            child: const CircularProgressIndicator(),
          ),
        );
      }
      final dados = estado.data!;
      final pessoas = filtrarPessoas(dados.pessoas, _termo);
      final contexto = _cartaoContexto(dados);
      if (pessoas.isEmpty) {
        return Column(
          children: [
            contexto,
            Expanded(
              child: _mensagem(
                dados.vazio
                    ? 'Nenhuma pessoa cadastrada.'
                    : 'Nenhum resultado encontrado.',
                comRetentativa: false,
              ),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [contexto, for (final pessoa in pessoas) _cartao(pessoa)],
      );
    },
  );

  Widget _cartaoContexto(PessoasResposta dados) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Semantics(
      label: 'Contexto ativo: ${dados.contextoRotulo}',
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: const Text('Contexto ativo (somente leitura)'),
          subtitle: Text(dados.contextoRotulo),
        ),
      ),
    ),
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
            ElevatedButton(
              onPressed: _recarregar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _cartao(PessoaAdministrativa pessoa) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pessoa.rotulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (pessoa.coordenador)
                const Chip(
                  avatar: Icon(Icons.badge_outlined, size: 18),
                  label: Text('Coordenador do Maanaim'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (pessoa.email.isNotEmpty) Text(pessoa.email),
          const SizedBox(height: 4),
          Semantics(
            label: 'Papéis de ${pessoa.rotulo}: ${pessoa.papeisRotulo}',
            child: Text('Papéis: ${pessoa.papeisRotulo}'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _executando
                    ? null
                    : () => _alterarPapel(
                        pessoa,
                        'ADMINISTRADOR',
                        !pessoa.temAdministrador,
                      ),
                child: Text(
                  pessoa.temAdministrador
                      ? 'Revogar Administrador'
                      : 'Conceder Administrador',
                ),
              ),
              OutlinedButton(
                onPressed: _executando
                    ? null
                    : () => _alterarPapel(
                        pessoa,
                        'COORDENADOR',
                        !pessoa.temCoordenador,
                      ),
                child: Text(
                  pessoa.temCoordenador
                      ? 'Revogar Coordenador'
                      : 'Conceder Coordenador',
                ),
              ),
              TextButton.icon(
                onPressed: _executando ? null : () => _abrirFormulario(pessoa),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DadosPessoa {
  const _DadosPessoa({
    required this.nomeCompleto,
    required this.email,
    required this.coordenador,
    this.cpf,
  });

  final String nomeCompleto;
  final String email;
  final bool coordenador;
  final String? cpf;
}

class _FormularioPessoa extends StatefulWidget {
  const _FormularioPessoa({this.pessoa});

  final PessoaAdministrativa? pessoa;

  @override
  State<_FormularioPessoa> createState() => _FormularioPessoaState();
}

class _FormularioPessoaState extends State<_FormularioPessoa> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nome = TextEditingController(
    text: widget.pessoa?.nomeCompleto ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.pessoa?.email ?? '',
  );
  final _cpf = TextEditingController();
  late bool _coordenador = widget.pessoa?.coordenador ?? false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _cpf.dispose();
    super.dispose();
  }

  String? _validaNome(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.length < 3) return 'Informe o nome completo.';
    return null;
  }

  String? _validaEmail(String? valor) {
    final texto = (valor ?? '').trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(texto)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  String? _validaCpf(String? valor) {
    if (!_coordenador) return null;
    final digitos = (valor ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 11) return 'Informe o CPF com 11 dígitos.';
    return null;
  }

  void _salvar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _DadosPessoa(
        nomeCompleto: _nome.text.trim(),
        email: _email.text.trim(),
        coordenador: _coordenador,
        cpf: _coordenador ? _cpf.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.pessoa == null ? 'Cadastrar pessoa' : 'Editar pessoa'),
    content: SingleChildScrollView(
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: _validaNome,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              validator: _validaEmail,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Coordenador do Maanaim'),
              value: _coordenador,
              onChanged: (valor) => setState(() => _coordenador = valor),
            ),
            if (_coordenador)
              TextFormField(
                controller: _cpf,
                decoration: const InputDecoration(labelText: 'CPF'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validaCpf,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
    ],
  );
}

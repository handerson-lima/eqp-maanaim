import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
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
      // Busca sempre o conjunto completo: a filtragem por termo é local, para
      // que limpar/trocar a busca não esconda quem foi estreitado no servidor.
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
            onPressed: () => Navigator.pop(dialogo, false),
            label: 'Cancelar',
          ),
          PrimaryButton(
            onPressed: () => Navigator.pop(dialogo, true),
            label: 'Confirmar',
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
        _erroAcao = null;
        _executando = false;
        _futuro = widget.gateway.consultar();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroAcao =
            'Não foi possível atualizar o papel. Recarregue a lista e tente novamente.';
        _aviso = null;
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
        versao: pessoa?.versao ?? 0,
        nomeCompleto: dados.nomeCompleto,
        email: dados.email,
        coordenador: dados.coordenador,
        cpf: dados.cpf,
      );
      if (!mounted) return;
      setState(() {
        _aviso = pessoa == null ? 'Pessoa cadastrada.' : 'Cadastro atualizado.';
        _erroAcao = null;
        _executando = false;
        _futuro = widget.gateway.consultar();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroAcao =
            'Não foi possível salvar o cadastro. Revise os campos e tente novamente.';
        _aviso = null;
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
            PageHeader(
              title: 'Pessoas e Papéis',
              subtitle:
                  'Gerencie o perfil e os papéis de sistema. Identidade, perfil e '
                  'papel são fontes separadas.',
              action: PrimaryButton(
                onPressed: _executando ? null : () => _abrirFormulario(),
                icon: Icons.person_add_alt,
                label: 'Cadastrar pessoa',
              ),
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
          ],
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
      child: SectionCard(
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.blue600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contexto ativo (somente leitura)',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dados.contextoRotulo,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            PrimaryButton(
              onPressed: _recarregar,
              label: 'Tentar novamente',
            ),
          ],
        ],
      ),
    ),
  );

  Widget _cartao(PessoaAdministrativa pessoa) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pessoa.rotulo,
                  style: AppTypography.h3,
                ),
              ),
              if (pessoa.coordenador)
                const StatusChip(
                  status: 'ATIVA',
                  label: 'Coordenador do Maanaim',
                ),
            ],
          ),
          if (pessoa.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              pessoa.email,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Semantics(
            label: 'Papéis de ${pessoa.rotulo}: ${pessoa.papeisRotulo}',
            child: Text(
              'Papéis: ${pessoa.papeisRotulo}',
              style: AppTypography.body,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SecondaryButton(
                onPressed: _executando
                    ? null
                    : () => _alterarPapel(
                        pessoa,
                        'ADMINISTRADOR',
                        !pessoa.temAdministrador,
                      ),
                label: pessoa.temAdministrador
                    ? 'Revogar Administrador'
                    : 'Conceder Administrador',
              ),
              SecondaryButton(
                onPressed: _executando
                    ? null
                    : () => _alterarPapel(
                        pessoa,
                        'COORDENADOR',
                        !pessoa.temCoordenador,
                      ),
                label: pessoa.temCoordenador
                    ? 'Revogar Coordenador'
                    : 'Conceder Coordenador',
              ),
              SecondaryButton(
                onPressed: _executando ? null : () => _abrirFormulario(pessoa),
                icon: Icons.edit_outlined,
                label: 'Editar',
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
    final digitos = CpfFormatter.apenasDigitos(valor);
    // Edição sem CPF preserva o registro restrito vigente; na criação é exigido.
    if (digitos.isEmpty && widget.pessoa != null) return null;
    if (digitos.length != 11) return 'Informe o CPF com 11 dígitos.';
    return null;
  }

  void _salvar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final digitos = CpfFormatter.apenasDigitos(_cpf.text.trim());
    Navigator.pop(
      context,
      _DadosPessoa(
        nomeCompleto: _nome.text.trim(),
        email: _email.text.trim(),
        coordenador: _coordenador,
        cpf: _coordenador ? digitos : null,
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
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  hintText: '000.000.000-00',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [CpfInputFormatter()],
                validator: _validaCpf,
              ),
          ],
        ),
      ),
    ),
    actions: [
      SecondaryButton(
        onPressed: () => Navigator.pop(context),
        label: 'Cancelar',
      ),
      PrimaryButton(onPressed: _salvar, label: 'Salvar'),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import 'catalogo_service.dart';

/// Tela administrativa do catálogo com inativação/reativação lógica, mobile-first e acessível.
class ConsultaCatalogo extends StatefulWidget {
  const ConsultaCatalogo(this.gateway, {super.key});

  final CatalogoGateway gateway;

  @override
  State<ConsultaCatalogo> createState() => _ConsultaCatalogoState();
}

class _ConsultaCatalogoState extends State<ConsultaCatalogo> {
  late Future<CatalogoResposta> _futuro;
  final _busca = TextEditingController();
  String _termo = '';
  bool _executando = false;
  String? _aviso;

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

  Future<void> _confirmarAlternarIgreja(IgrejaCatalogo igreja) async {
    final novoAtivo = !igreja.ativo;
    final acao = novoAtivo ? 'Reativar' : 'Inativar';
    final titulo = '$acao Igreja';
    final mensagem = novoAtivo
        ? 'Deseja reativar a igreja "${igreja.rotulo}"?\n\nEla voltará a ficar disponível para novos cadastros e seleções no catálogo.'
        : 'Deseja inativar a igreja "${igreja.rotulo}"?\n\nEla deixará de ser exibida em novos cadastros. Fichas e participações ativas existentes não serão afetadas.';

    final confirmou = await _exibirModalConfirmacao(
      titulo: titulo,
      mensagem: mensagem,
      rotuloConfirmar: acao,
    );
    if (!confirmou || !mounted) return;

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
      _recarregar();
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

  Future<void> _confirmarAlternarEquipe(EquipeCatalogo equipe) async {
    final novoAtivo = !equipe.ativo;
    final acao = novoAtivo ? 'Reativar' : 'Inativar';
    final titulo = '$acao Equipe';
    final mensagem = novoAtivo
        ? 'Deseja reativar a equipe "${equipe.nome}"?\n\nEla voltará a ficar disponível para novas seleções no cadastro de voluntários.'
        : 'Deseja inativar a equipe "${equipe.nome}"?\n\nEla deixará de ser exibida em novas seleções. Participações ativas e vigentes existentes não serão afetadas.';

    final confirmou = await _exibirModalConfirmacao(
      titulo: titulo,
      mensagem: mensagem,
      rotuloConfirmar: acao,
    );
    if (!confirmou || !mounted) return;

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
      _recarregar();
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

  Future<bool> _exibirModalConfirmacao({
    required String titulo,
    required String mensagem,
    required String rotuloConfirmar,
  }) async {
    final resultado = await showDialog<bool>(
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
              label: rotuloConfirmar,
              onPressed: () => Navigator.pop(dialogo, true),
            ),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _busca,
          onChanged: (valor) => setState(() => _termo = valor),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Pesquisar por nome ou código',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      if (_aviso != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: AppGeometry.cardBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _aviso!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.navy900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      Expanded(child: _corpo()),
    ],
  );

  Widget _corpo() => FutureBuilder<CatalogoResposta>(
    future: _futuro,
    builder: (context, estado) {
      if (estado.hasError) {
        return _mensagem('Não foi possível carregar o catálogo.', true);
      }
      if (!estado.hasData) {
        return Center(
          child: Semantics(
            label: 'Carregando catálogo',
            child: const CircularProgressIndicator(),
          ),
        );
      }
      final dados = estado.data!;
      final igrejas = filtrarIgrejas(dados.igrejas, _termo);
      final equipes = filtrarEquipes(dados.equipes, _termo);
      if (igrejas.isEmpty && equipes.isEmpty) {
        return _mensagem('Nenhum resultado encontrado.', false);
      }
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (igrejas.isNotEmpty) ...[
            SectionCard(
              title: 'Igrejas',
              child: Column(
                children: [
                  for (final igreja in igrejas) _itemIgreja(igreja),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (equipes.isNotEmpty) ...[
            SectionCard(
              title: 'Equipes',
              child: Column(
                children: [
                  for (final equipe in equipes) _itemEquipe(equipe),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _mensagem(String texto, bool comRetentativa) => Center(
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

  Widget _botaoAlternar({
    required String rotulo,
    required IconData icone,
    required Color cor,
    required String mensagemSemantica,
    required VoidCallback onPressed,
  }) => Semantics(
    label: mensagemSemantica,
    button: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: cor,
          side: BorderSide(color: cor.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icone, size: 18),
        label: Text(
          rotulo,
          style: AppTypography.caption.copyWith(
            color: cor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: _executando ? null : onPressed,
      ),
    ),
  );

  Widget _itemIgreja(IgrejaCatalogo igreja) => ListTile(
    leading: const Icon(Icons.church_outlined, color: AppColors.blue600),
    title: Text(
      igreja.rotulo,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
    ),
    trailing: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        igreja.ativo
            ? const StatusChip(status: 'ATIVA')
            : const StatusChip(status: 'INATIVA', label: 'Inativa'),
        _botaoAlternar(
          rotulo: igreja.ativo ? 'Inativar' : 'Reativar',
          icone: igreja.ativo ? Icons.block_outlined : Icons.check_circle_outline,
          cor: igreja.ativo ? AppColors.danger : AppColors.blue600,
          mensagemSemantica: '${igreja.ativo ? "Inativar" : "Reativar"} igreja ${igreja.nome}',
          onPressed: () => _confirmarAlternarIgreja(igreja),
        ),
      ],
    ),
  );

  Widget _itemEquipe(EquipeCatalogo equipe) => ListTile(
    leading: const Icon(Icons.groups_outlined, color: AppColors.blue600),
    title: Text(
      equipe.nome,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
    ),
    trailing: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        equipe.ativo
            ? const StatusChip(status: 'ATIVA')
            : const StatusChip(status: 'INATIVA', label: 'Inativa'),
        _botaoAlternar(
          rotulo: equipe.ativo ? 'Inativar' : 'Reativar',
          icone: equipe.ativo ? Icons.block_outlined : Icons.check_circle_outline,
          cor: equipe.ativo ? AppColors.danger : AppColors.blue600,
          mensagemSemantica: '${equipe.ativo ? "Inativar" : "Reativar"} equipe ${equipe.nome}',
          onPressed: () => _confirmarAlternarEquipe(equipe),
        ),
      ],
    ),
  );
}


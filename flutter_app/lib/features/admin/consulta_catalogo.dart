import 'package:flutter/material.dart';

import '../../ui/identidade.dart';
import 'catalogo_service.dart';

/// Tela administrativa read-only do catálogo, mobile-first e acessível.
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

  Widget _itemIgreja(IgrejaCatalogo igreja) => ListTile(
    leading: const Icon(Icons.church_outlined, color: AppColors.blue600),
    title: Text(
      igreja.rotulo,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
    ),
    trailing: igreja.ativo
        ? const StatusChip(status: 'ATIVA')
        : const StatusChip(status: 'INATIVA', label: 'Inativa'),
  );

  Widget _itemEquipe(EquipeCatalogo equipe) => ListTile(
    leading: const Icon(Icons.groups_outlined, color: AppColors.blue600),
    title: Text(
      equipe.nome,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
    ),
    trailing: equipe.ativo
        ? const StatusChip(status: 'ATIVA')
        : const StatusChip(status: 'INATIVA', label: 'Inativa'),
  );
}

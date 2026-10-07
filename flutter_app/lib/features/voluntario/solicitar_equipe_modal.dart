import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../ui/components/buttons.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../admin/catalogo_service.dart';
import 'participacao_service.dart';

/// Modal e BottomSheet acessível mobile-first (WCAG 2.2 AA) para o voluntário
/// solicitar participação em equipe adicional do catálogo administrável.
class SolicitarEquipeModal extends StatefulWidget {
  const SolicitarEquipeModal({
    super.key,
    required this.equipesCatalogo,
    required this.participacoesAtuais,
    required this.participacaoGateway,
    required this.onSucesso,
  });

  final List<EquipeCatalogo> equipesCatalogo;
  final List<ParticipacaoModel> participacoesAtuais;
  final ParticipacaoGateway participacaoGateway;
  final ValueChanged<ParticipacaoModel> onSucesso;

  static Future<void> exibir({
    required BuildContext context,
    required List<EquipeCatalogo> equipesCatalogo,
    required List<ParticipacaoModel> participacoesAtuais,
    required ParticipacaoGateway participacaoGateway,
    required ValueChanged<ParticipacaoModel> onSucesso,
  }) {
    final largura = MediaQuery.of(context).size.width;
    final ehMobile = largura < 600;

    if (ehMobile) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SolicitarEquipeModal(
            equipesCatalogo: equipesCatalogo,
            participacoesAtuais: participacoesAtuais,
            participacaoGateway: participacaoGateway,
            onSucesso: onSucesso,
          ),
        ),
      );
    } else {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: SolicitarEquipeModal(
              equipesCatalogo: equipesCatalogo,
              participacoesAtuais: participacoesAtuais,
              participacaoGateway: participacaoGateway,
              onSucesso: onSucesso,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<SolicitarEquipeModal> createState() => _SolicitarEquipeModalState();
}

class _SolicitarEquipeModalState extends State<SolicitarEquipeModal> {
  String? _equipeSelecionadaId;
  String _filtro = '';
  bool _enviando = false;
  String? _mensagemErro;

  bool _isEquipeInelegivel(String equipeId) {
    return widget.participacoesAtuais.any(
      (p) =>
          p.equipeId == equipeId &&
          (p.isAtiva || p.isPendente || p.isRascunho),
    );
  }

  ParticipacaoModel? _obterParticipacaoExistente(String equipeId) {
    final encontradas = widget.participacoesAtuais.where(
      (p) => p.equipeId == equipeId,
    );
    if (encontradas.isEmpty) return null;
    return encontradas.first;
  }

  Future<void> _submeter() async {
    if (_equipeSelecionadaId == null || _enviando) return;

    setState(() {
      _enviando = true;
      _mensagemErro = null;
    });

    try {
      final novaPart = await widget.participacaoGateway.solicitarEquipeAdicional(
        _equipeSelecionadaId!,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSucesso(novaPart);
      }
    } catch (erro) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _mensagemErro = _mensagemDeErro(erro);
        });
      }
    }
  }

  /// Traduz o erro do backend numa mensagem clara, distinguindo a recusa de
  /// domínio (equipe já solicitada) de indisponibilidade de rede.
  String _mensagemDeErro(Object erro) {
    if (erro is FirebaseFunctionsException) {
      switch (erro.code) {
        case 'failed-precondition':
          final mensagem = erro.message;
          return (mensagem != null && mensagem.isNotEmpty)
              ? mensagem
              : 'Não foi possível solicitar a equipe. Verifique os dados e tente novamente.';
        case 'permission-denied':
          return 'Não é permitido solicitar equipe em nome de outro voluntário.';
        case 'invalid-argument':
          return 'Não foi possível validar a solicitação. Recarregue a página e tente novamente.';
        case 'unauthenticated':
          return 'Sua sessão expirou. Entre novamente para solicitar.';
        case 'internal':
        case 'unavailable':
          return 'Serviço indisponível no momento. Tente novamente em instantes.';
      }
    }
    return 'Não foi possível solicitar a equipe. Verifique se a equipe já foi solicitada ou tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final equipesAtivas = widget.equipesCatalogo
        .where((e) => e.ativo)
        .where((e) =>
            _filtro.isEmpty ||
            e.nome.toLowerCase().contains(_filtro.toLowerCase()))
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                ),
                child: const Icon(
                  Icons.group_add_outlined,
                  color: AppColors.blue600,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitar Equipe Adicional',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.navy900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Amplie seu voluntariado sem interromper as equipes ativas.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('btn_fechar_modal_solicitar_equipe'),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Campo de busca rápida
          TextField(
            key: const Key('input_busca_equipe_modal'),
            decoration: InputDecoration(
              labelText: 'Buscar equipe',
              hintText: 'Filtrar equipes pelo nome...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.neutral100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (val) => setState(() => _filtro = val.trim()),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Erro se houver
          if (_mensagemErro != null) ...[
            Semantics(
              container: true,
              liveRegion: true,
              label: _mensagemErro,
              child: Container(
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
                        _mensagemErro!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],

          // Lista de equipes
          Flexible(
            child: equipesAtivas.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                    child: Center(
                      child: Text(
                        'Nenhuma equipe ativa encontrada.',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: equipesAtivas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final equipe = equipesAtivas[index];
                      final inelegivel = _isEquipeInelegivel(equipe.id);
                      final partExistente = _obterParticipacaoExistente(equipe.id);
                      final selecionada = _equipeSelecionadaId == equipe.id;

                      return Semantics(
                        enabled: !inelegivel,
                        selected: selecionada,
                        label: inelegivel
                            ? '${equipe.nome}, indisponível: já possui participação'
                            : '${equipe.nome}, disponível para seleção',
                        child: InkWell(
                          key: Key('item_equipe_${equipe.id}'),
                          onTap: inelegivel || _enviando
                              ? null
                              : () {
                                  setState(() {
                                    _equipeSelecionadaId = equipe.id;
                                    _mensagemErro = null;
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
                                  ? AppColors.neutral150.withValues(alpha: 0.5)
                                  : selecionada
                                      ? AppColors.blue50
                                      : AppColors.surface,
                              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                              border: Border.all(
                                color: selecionada
                                    ? AppColors.blue600
                                    : AppColors.border,
                                width: selecionada ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: inelegivel
                                          ? AppColors.border
                                          : selecionada
                                              ? AppColors.blue600
                                              : AppColors.textSecondary,
                                      width: 2,
                                    ),
                                    color: selecionada
                                        ? AppColors.blue600
                                        : Colors.transparent,
                                  ),
                                  child: selecionada
                                      ? const Center(
                                          child: SizedBox(
                                            width: 8,
                                            height: 8,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.surface,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                Expanded(
                                  child: Text(
                                    equipe.nome,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: selecionada
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: inelegivel
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (inelegivel && partExistente != null) ...[
                                  const SizedBox(width: AppSpacing.s8),
                                  if (partExistente.isAtiva)
                                    const StatusChip(
                                      status: 'ATIVA',
                                      label: 'Ativa',
                                    )
                                  else
                                    const StatusChip(
                                      status: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
                                      label: 'Em análise',
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Botões de Ação
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const Key('btn_cancelar_solicitar_equipe'),
                  label: 'Cancelar',
                  onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: PrimaryButton(
                  key: const Key('btn_confirmar_solicitar_equipe'),
                  label: _enviando ? 'Enviando...' : 'Confirmar Solicitação',
                  icon: _enviando ? null : Icons.check_circle_outline,
                  onPressed: _equipeSelecionadaId == null || _enviando
                      ? null
                      : _submeter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

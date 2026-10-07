import 'package:flutter/material.dart';
import '../../ui/tokens.dart';
import 'historico_service.dart';

/// Componente de Linha do Tempo Auditável e Segura (WCAG 2.2 AA).
/// Desenvolvido conforme DESIGN-RULES-FOR-AGENTS.md e arquitetura canônica (AD-9, AD-12).
class LinhaDoTempoWidget extends StatefulWidget {
  const LinhaDoTempoWidget({
    super.key,
    required this.eventos,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.tituloSecao = 'Linha do Tempo e Histórico',
  });

  final List<EventoLinhaDoTempoModel> eventos;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String tituloSecao;

  @override
  State<LinhaDoTempoWidget> createState() => _LinhaDoTempoWidgetState();
}

class _LinhaDoTempoWidgetState extends State<LinhaDoTempoWidget> {
  int _selecionado = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.errorMessage != null) {
      return _buildErrorState();
    }

    if (widget.eventos.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final indice = _selecionado.clamp(0, widget.eventos.length - 1);
        final lista = _buildLista(isDesktop, indice);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.tituloSecao.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_edu_outlined,
                      size: 22,
                      color: AppColors.navy900,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      widget.tituloSecao,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: lista),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    flex: 2,
                    child: _PainelDetalheEvento(evento: widget.eventos[indice]),
                  ),
                ],
              )
            else
              lista,
          ],
        );
      },
    );
  }

  Widget _buildLista(bool isDesktop, int indice) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.eventos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final evento = widget.eventos[index];
        final isLast = index == widget.eventos.length - 1;

        return _ItemLinhaDoTempo(
          evento: evento,
          isLast: isLast,
          isDesktop: isDesktop,
          isSelected: isDesktop && index == indice,
          onTap: isDesktop ? () => setState(() => _selecionado = index) : null,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s32),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue600),
            ),
          ),
          SizedBox(height: AppSpacing.s12),
          Text(
            'Carregando histórico...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 36,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppSpacing.s8),
          Text(
            'Nenhum evento registrado no histórico até o momento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            widget.errorMessage ?? 'Não foi possível carregar a linha do tempo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: AppSpacing.s12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: OutlinedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar novamente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue600,
                  side: const BorderSide(color: AppColors.blue600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppGeometry.radiusButton),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemLinhaDoTempo extends StatelessWidget {
  const _ItemLinhaDoTempo({
    required this.evento,
    required this.isLast,
    required this.isDesktop,
    this.isSelected = false,
    this.onTap,
  });

  final EventoLinhaDoTempoModel evento;
  final bool isLast;
  final bool isDesktop;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _resolveStatusConfig(evento);

    final cartao = Semantics(
      container: true,
      selected: isSelected,
      label:
          'Evento: ${evento.titulo}. Status: ${statusConfig.label}. Em: ${_formatarData(evento.timestamp)}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna do Conector e Ícone
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: statusConfig.backgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.blue600
                              : statusConfig.borderColor,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        statusConfig.icon,
                        size: 16,
                        color: statusConfig.iconColor,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.border,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              // Cartão de Conteúdo do Evento
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s16),
                  child: _CartaoEvento(
                    evento: evento,
                    statusConfig: statusConfig,
                    destacado: isSelected,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return cartao;
    return InkWell(
      onTap: onTap,
      borderRadius: AppGeometry.cardBorderRadius,
      child: cartao,
    );
  }
}

class _CartaoEvento extends StatelessWidget {
  const _CartaoEvento({
    required this.evento,
    required this.statusConfig,
    this.destacado = false,
  });

  final EventoLinhaDoTempoModel evento;
  final _StatusConfig statusConfig;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: statusConfig.cardColor,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: destacado ? AppColors.blue600 : statusConfig.cardBorderColor,
          width: destacado ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  evento.titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              _ChipStatus(
                label: statusConfig.label,
                textColor: statusConfig.chipTextColor,
                bgColor: statusConfig.chipBgColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            evento.descricao,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          _MetaEvento(evento: evento),
          _JustificativaInterna(evento: evento),
        ],
      ),
    );
  }
}

class _MetaEvento extends StatelessWidget {
  const _MetaEvento({required this.evento});

  final EventoLinhaDoTempoModel evento;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _formatarData(evento.timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (evento.atorNome != null && evento.atorNome!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  evento.atorNome!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (evento.atorPapel != null && evento.atorPapel!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  evento.atorPapel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (evento.atorVinculoId != null && evento.atorVinculoId!.isNotEmpty) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        if (evento.nomeEquipe != null && evento.nomeEquipe!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  evento.nomeEquipe!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _JustificativaInterna extends StatelessWidget {
  const _JustificativaInterna({required this.evento});

  final EventoLinhaDoTempoModel evento;

  @override
  Widget build(BuildContext context) {
    if (evento.justificativaInterna == null ||
        evento.justificativaInterna!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s8),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Justificativa interna (autorizada):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                evento.justificativaInterna!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Painel de detalhe exibido no desktop (>= 600px) ao lado da lista.
class _PainelDetalheEvento extends StatelessWidget {
  const _PainelDetalheEvento({required this.evento});

  final EventoLinhaDoTempoModel evento;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _resolveStatusConfig(evento);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhe do evento',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  evento.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              _ChipStatus(
                label: statusConfig.label,
                textColor: statusConfig.chipTextColor,
                bgColor: statusConfig.chipBgColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            evento.descricao,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          _MetaEvento(evento: evento),
          _JustificativaInterna(evento: evento),
        ],
      ),
    );
  }
}

_StatusConfig _resolveStatusConfig(EventoLinhaDoTempoModel evento) {
  if (evento.isOrientacaoPastoral) {
    return const _StatusConfig(
      label: 'Orientações',
      icon: Icons.info_outline,
      iconColor: AppColors.textSecondary,
      backgroundColor: AppColors.neutral100,
      borderColor: AppColors.border,
      cardColor: AppColors.neutral50,
      cardBorderColor: AppColors.border,
      chipTextColor: AppColors.textSecondary,
      chipBgColor: AppColors.neutral100,
    );
  }

  if (evento.isConcluido) {
    return const _StatusConfig(
      label: 'Concluído',
      icon: Icons.check,
      iconColor: AppColors.success,
      backgroundColor: AppColors.successBg,
      borderColor: AppColors.success,
      cardColor: AppColors.surface,
      cardBorderColor: AppColors.border,
      chipTextColor: AppColors.success,
      chipBgColor: AppColors.successBg,
    );
  }

  // Default seguro: estado desconhecido/em andamento nunca é exibido como concluído.
  return const _StatusConfig(
    label: 'Em análise',
    icon: Icons.hourglass_top,
    iconColor: AppColors.blue600,
    backgroundColor: AppColors.blue50,
    borderColor: AppColors.blue600,
    cardColor: AppColors.surface,
    cardBorderColor: AppColors.border,
    chipTextColor: AppColors.blue600,
    chipBgColor: AppColors.blue50,
  );
}

String _formatarData(String isoString) {
  if (isoString.isEmpty) return '';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final ano = dt.year.toString();
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$minuto';
  } catch (_) {
    return isoString;
  }
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  final String label;
  final Color textColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.cardColor,
    required this.cardBorderColor,
    required this.chipTextColor,
    required this.chipBgColor,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color cardColor;
  final Color cardBorderColor;
  final Color chipTextColor;
  final Color chipBgColor;
}

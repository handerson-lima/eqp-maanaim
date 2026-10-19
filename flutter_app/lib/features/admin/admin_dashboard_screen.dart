import 'package:flutter/material.dart';
import '../../ui/identidade.dart';

/// Item descritivo para cada card do painel administrativo.
class AdminCardItem {
  const AdminCardItem({
    required this.label,
    required this.descricao,
    required this.icone,
    required this.secao,
  });

  final String label;
  final String descricao;
  final IconData icone;
  final String secao;
}

/// Tela de boas-vindas / Dashboard do Administrador.
/// Apresenta um hub de cartões responsivos e acessíveis para acesso rápido a
/// todas as áreas administrativas do sistema Maanaim.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onNavegar,
    this.temPastor = false,
    this.temResponsavelEquipe = false,
    this.temCoordenador = false,
  });

  final void Function(String label) onNavegar;
  final bool temPastor;
  final bool temResponsavelEquipe;
  final bool temCoordenador;

  List<AdminCardItem> get _cardsCadastros => const [
    AdminCardItem(
      label: 'Igrejas',
      descricao: 'Cadastre e gerencie igrejas e congregações ativas',
      icone: Icons.church_outlined,
      secao: 'Cadastros',
    ),
    AdminCardItem(
      label: 'Equipes',
      descricao: 'Estrutura, setores e áreas de serviço voluntário',
      icone: Icons.groups_outlined,
      secao: 'Cadastros',
    ),
    AdminCardItem(
      label: 'Pessoas e Papéis',
      descricao: 'Gestão de acessos, administradores e coordenadores',
      icone: Icons.manage_accounts_outlined,
      secao: 'Cadastros',
    ),
    AdminCardItem(
      label: 'Vínculos e Responsáveis',
      descricao: 'Atribuição temporal de pastores e líderes de equipes',
      icone: Icons.handshake_outlined,
      secao: 'Cadastros',
    ),
    AdminCardItem(
      label: 'Termos',
      descricao: 'Publicação e versionamento dos termos de voluntariado',
      icone: Icons.description_outlined,
      secao: 'Cadastros',
    ),
  ];

  List<AdminCardItem> get _cardsOperacao => [
    const AdminCardItem(
      label: 'Solicitações por Equipe',
      descricao: 'Acompanhamento consolidado de pendências de voluntários',
      icone: Icons.pending_actions_outlined,
      secao: 'Operação',
    ),
    if (temPastor)
      const AdminCardItem(
        label: 'Fila do Pastor',
        descricao: 'Fila de análise e aprovação das fichas locais',
        icone: Icons.how_to_reg_outlined,
        secao: 'Operação',
      ),
    if (temResponsavelEquipe)
      const AdminCardItem(
        label: 'Fila da Equipe',
        descricao: 'Fila de aprovação específica por equipe de serviço',
        icone: Icons.groups_outlined,
        secao: 'Operação',
      ),
    if (temCoordenador)
      const AdminCardItem(
        label: 'Fila do Coordenador',
        descricao: 'Conclusão geral do processo e ativação da ficha',
        icone: Icons.verified_outlined,
        secao: 'Operação',
      ),
    const AdminCardItem(
      label: 'Renovações',
      descricao: 'Acompanhamento e gestão do ciclo anual de renovações',
      icone: Icons.autorenew_outlined,
      secao: 'Operação',
    ),
  ];

  List<AdminCardItem> get _cardsGovernanca => const [
    AdminCardItem(
      label: 'Carga inicial do catálogo',
      descricao: 'Seed e importação inicial de igrejas e equipes',
      icone: Icons.cloud_upload_outlined,
      secao: 'Governança & Sistema',
    ),
    AdminCardItem(
      label: 'Auditoria & Relatórios',
      descricao: 'Evidências imutáveis, logs de auditoria e relatórios',
      icone: Icons.history_edu_outlined,
      secao: 'Governança & Sistema',
    ),
    AdminCardItem(
      label: 'Retenção e Privacidade',
      descricao: 'Políticas de retenção de dados e conformidade LGPD',
      icone: Icons.privacy_tip_outlined,
      secao: 'Governança & Sistema',
    ),
  ];

  Widget _construirSecao({
    required BuildContext context,
    required String titulo,
    required List<AdminCardItem> itens,
    required int colunas,
  }) {
    if (itens.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Text(
            titulo,
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final espacamento = AppSpacing.cardGap;
            final larguraDisponivel = constraints.maxWidth;
            final larguraCard = (larguraDisponivel - (colunas - 1) * espacamento) / colunas;

            return Wrap(
              spacing: espacamento,
              runSpacing: espacamento,
              children: [
                for (final item in itens)
                  SizedBox(
                    width: colunas == 1 ? larguraDisponivel : larguraCard,
                    child: _AdminDashboardCard(
                      item: item,
                      onTap: () => onNavegar(item.label),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.s32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final isDesktop = constraints.maxWidth >= 1024;
        final colunas = isCompact ? 1 : (isDesktop ? 3 : 2);
        final paddingHorizontal = isCompact
            ? AppSpacing.pagePaddingMobile
            : AppSpacing.pagePaddingDesktop;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: paddingHorizontal,
            vertical: AppSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Painel Administrativo',
                subtitle:
                    'Bem-vindo ao Maanaim. Selecione uma área para gerenciar ou acompanhar as operações.',
              ),
              const SizedBox(height: AppSpacing.s24),
              _construirSecao(
                context: context,
                titulo: 'Cadastros',
                itens: _cardsCadastros,
                colunas: colunas,
              ),
              _construirSecao(
                context: context,
                titulo: 'Operação',
                itens: _cardsOperacao,
                colunas: colunas,
              ),
              _construirSecao(
                context: context,
                titulo: 'Governança & Sistema',
                itens: _cardsGovernanca,
                colunas: colunas,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Card interativo do painel administrativo com foco e semântica acessíveis.
class _AdminDashboardCard extends StatefulWidget {
  const _AdminDashboardCard({
    required this.item,
    required this.onTap,
  });

  final AdminCardItem item;
  final VoidCallback onTap;

  @override
  State<_AdminDashboardCard> createState() => _AdminDashboardCardState();
}

class _AdminDashboardCardState extends State<_AdminDashboardCard> {
  bool _emFoco = false;
  bool _emHover = false;

  @override
  Widget build(BuildContext context) {
    final destaque = _emHover || _emFoco;

    return Semantics(
      button: true,
      label: '${widget.item.label}, ${widget.item.descricao}',
      child: Material(
        color: destaque ? AppColors.blue50 : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.cardBorderRadius,
          side: BorderSide(
            color: destaque ? AppColors.blue600 : AppColors.border,
            width: destaque ? 1.5 : AppGeometry.borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (foco) => setState(() => _emFoco = foco),
          onHover: (hover) => setState(() => _emHover = hover),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppGeometry.minTouchTarget + 16,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: destaque
                          ? AppColors.surface
                          : AppColors.blue50,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                      border: Border.all(
                        color: destaque
                            ? AppColors.blue600.withValues(alpha: 0.3)
                            : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.item.icone,
                      color: AppColors.blue600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.item.label,
                          style: AppTypography.h3.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          widget.item.descricao,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: destaque
                        ? AppColors.blue600
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../ui/tokens.dart';
import '../../ui/components/buttons.dart';
import 'contexto_acesso_model.dart';

/// Visão de múltiplos destinos para usuários com mais de um papel/vínculo ativo (Story 8.3).
class SeletorDestinoCapacidades extends StatelessWidget {
  const SeletorDestinoCapacidades({
    super.key,
    required this.contexto,
    required this.onNavegarPastor,
    required this.onNavegarEquipe,
    required this.onNavegarCoordenador,
    required this.onNavegarAdmin,
    required this.onNavegarVoluntario,
    required this.onNavegarRenovacao,
    this.onSair,
  });

  final ContextoAcesso contexto;
  final VoidCallback onNavegarPastor;
  final VoidCallback onNavegarEquipe;
  final VoidCallback onNavegarCoordenador;
  final VoidCallback onNavegarAdmin;
  final VoidCallback onNavegarVoluntario;
  final VoidCallback onNavegarRenovacao;
  final VoidCallback? onSair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Selecione uma Área de Atuação'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.navy900,
        elevation: 1,
        actions: [
          if (onSair != null)
            TextButton.icon(
              onPressed: onSair,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Suas Áreas e Vínculos Autorizados',
                      style: AppTypography.h1.copyWith(
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Você possui múltiplos papéis ativos no Maanaim. Selecione a área que deseja acessar:',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  // Cards de destinos disponíveis
                  if (contexto.ehPastorLocal) ...[
                    _CardDestino(
                      titulo: 'Fila do Pastor Local',
                      subtitulo: contexto.igrejas.isNotEmpty
                          ? 'Igrejas: ${contexto.igrejas.map((i) => i.nome).join(', ')}'
                          : 'Avaliação pastoral de fichas e renovações',
                      icone: Icons.church_outlined,
                      corIcone: AppColors.blue600,
                      onAcessar: onNavegarPastor,
                      rotuloBotao: 'Acessar Fila Pastoral',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  if (contexto.ehResponsavelEquipe) ...[
                    _CardDestino(
                      titulo: 'Fila do Responsável de Equipe',
                      subtitulo: contexto.equipes.isNotEmpty
                          ? 'Equipes: ${contexto.equipes.map((e) => e.nome).join(', ')}'
                          : 'Avaliação técnica e confirmações de voluntários',
                      icone: Icons.groups_outlined,
                      corIcone: AppColors.warning,
                      onAcessar: onNavegarEquipe,
                      rotuloBotao: 'Acessar Fila da Equipe',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  if (contexto.ehCoordenador) ...[
                    _CardDestino(
                      titulo: 'Fila do Coordenador Geral',
                      subtitulo: 'Aprovações finais em reunião e ativação permanente',
                      icone: Icons.verified_outlined,
                      corIcone: AppColors.success,
                      onAcessar: onNavegarCoordenador,
                      rotuloBotao: 'Acessar Fila da Coordenação',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  if (contexto.ehAdministrador) ...[
                    _CardDestino(
                      titulo: 'Painel Administrativo Geral',
                      subtitulo: 'Catálogos, pessoas, vínculos, auditoria e governança',
                      icone: Icons.admin_panel_settings_outlined,
                      corIcone: AppColors.navy900,
                      onAcessar: onNavegarAdmin,
                      rotuloBotao: 'Acessar Administração',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  if (contexto.ehPastorLocal ||
                      contexto.ehResponsavelEquipe ||
                      contexto.ehCoordenador ||
                      contexto.ehAdministrador) ...[
                    _CardDestino(
                      titulo: 'Dashboard de Renovação',
                      subtitulo: 'Métricas, prazos e manifestações do ciclo anual por papel',
                      icone: Icons.insights_outlined,
                      corIcone: AppColors.blue600,
                      onAcessar: onNavegarRenovacao,
                      rotuloBotao: 'Acessar Renovação',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  _CardDestino(
                    titulo: 'Área do Voluntário (Minha Ficha)',
                    subtitulo: 'Consulte seus dados, participações e documentos pessoais',
                    icone: Icons.badge_outlined,
                    corIcone: AppColors.navy800,
                    onAcessar: onNavegarVoluntario,
                    rotuloBotao: 'Acessar Minha Ficha',
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

class _CardDestino extends StatelessWidget {
  const _CardDestino({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.corIcone,
    required this.onAcessar,
    required this.rotuloBotao,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color corIcone;
  final VoidCallback onAcessar;
  final String rotuloBotao;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: corIcone.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              ),
              child: Icon(icone, color: corIcone, size: 26),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.navy900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitulo,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            PrimaryButton(
              label: rotuloBotao,
              onPressed: onAcessar,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../ui/components/app_shell.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import 'historico_service.dart';
import 'linha_tempo_widget.dart';

/// Tela autorizada mobile-first para consulta de ficha, participações
/// e histórico/linha do tempo auditável conforme escopo (Story 4.1).
class ConsultaFichaAutorizadaScreen extends StatefulWidget {
  const ConsultaFichaAutorizadaScreen({
    super.key,
    this.fichaId,
    this.historicoService,
    this.onVoltar,
    this.onSair,
    this.userName,
    this.userRole,
  });

  final String? fichaId;
  final HistoricoService? historicoService;
  final VoidCallback? onVoltar;
  final VoidCallback? onSair;
  final String? userName;
  final String? userRole;

  @override
  State<ConsultaFichaAutorizadaScreen> createState() =>
      _ConsultaFichaAutorizadaScreenState();
}

class _ConsultaFichaAutorizadaScreenState
    extends State<ConsultaFichaAutorizadaScreen> {
  late final HistoricoService _service;

  bool _carregando = true;
  String? _erro;
  ResultadoConsultaFichaModel? _resultadoFicha;
  List<EventoLinhaDoTempoModel> _eventos = [];

  @override
  void initState() {
    super.initState();
    _service = widget.historicoService ?? HistoricoService();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final fFuture = _service.consultarFichaAutorizada(fichaId: widget.fichaId);
      final tFuture = _service.consultarLinhaDoTempoAutorizada(fichaId: widget.fichaId);

      final results = await Future.wait([fFuture, tFuture]);
      final fichaRes = results[0] as ResultadoConsultaFichaModel;
      final timelineRes = results[1] as List<EventoLinhaDoTempoModel>;

      if (mounted) {
        setState(() {
          _resultadoFicha = fichaRes;
          _eventos = timelineRes;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('permission-denied') ||
                e.toString().contains('não autorizado')
            ? 'Acesso não autorizado para a ficha solicitada ou vínculo não vigente.'
            : 'Falha ao carregar as informações da ficha. Tente novamente.';
        setState(() {
          _erro = msg;
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      items: const [
        AppNavItem(
          label: 'Consulta de Ficha',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
        ),
      ],
      selectedIndex: 0,
      onLogout: widget.onSair,
      userName: widget.userName ?? 'Usuário',
      userRole: widget.userRole ?? 'Liderança',
      body: _buildCorpo(),
    );
  }

  Widget _buildCorpo() {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ErrorState(
              title: 'Acesso Restrito',
              message: _erro!,
              onRetry: _carregarDados,
            ),
          ),
        ),
      );
    }

    if (_resultadoFicha?.existe != true || _resultadoFicha?.ficha == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Ficha não encontrada',
              message: 'Não há registros disponíveis para a identificação informada.',
              action: widget.onVoltar != null
                  ? OutlinedButton.icon(
                      onPressed: widget.onVoltar,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Voltar'),
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    final ficha = _resultadoFicha!.ficha!;
    final participacoes = _resultadoFicha!.participacoes;
    final papelConsulta = _resultadoFicha!.papel;
    final equipesFiltradas = _resultadoFicha!.equipesFiltradas;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Voltar se fornecida
              if (widget.onVoltar != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: TextButton.icon(
                      onPressed: widget.onVoltar,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Voltar para a fila'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.blue600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              // Cabeçalho
              PageHeader(
                title: ficha.nomeCompleto,
                subtitle: ficha.nomeIgreja != null
                    ? 'Igreja: ${ficha.nomeIgreja}'
                    : 'Situação cadastral e histórico do voluntariado',
                action: StatusChip(status: ficha.estado),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Aviso de Escopo Restrito de Equipe (se aplicável)
              if (equipesFiltradas) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                    border: Border.all(color: AppColors.blue600.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 20, color: AppColors.blue600),
                      SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          'Visualização restrita: exibindo exclusivamente as participações e eventos sob sua gestão de equipe.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.navy900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              // Card: Dados Cadastrais
              SectionCard(
                title: 'Dados Cadastrais',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLinhaInfo('Nome Completo', ficha.nomeCompleto),
                    _buildLinhaInfo('Profissão', ficha.profissao),
                    _buildLinhaInfo(
                      'CPF',
                      ficha.cpfExibicao,
                      destaqueMonospaced: true,
                    ),
                    if (ficha.nomeIgreja != null)
                      _buildLinhaInfo('Igreja Local', ficha.nomeIgreja!),
                    _buildLinhaInfo('Versão da Ficha', 'v${ficha.versao}'),
                    if (ficha.proximaAcao != null)
                      _buildLinhaInfo('Próxima Ação', ficha.proximaAcao!),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Card: Participações por Equipe
              SectionCard(
                title: 'Participações por Equipe',
                subtitle: 'Acompanhamento independente de cada equipe e ciclo.',
                child: participacoes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
                        child: Text(
                          'Nenhuma participação registrada no momento.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: participacoes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.s12),
                        itemBuilder: (context, index) {
                          final part = participacoes[index];
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.s12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius:
                                  BorderRadius.circular(AppGeometry.radiusCard),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        part.nomeEquipe,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    StatusChip(status: part.estado),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.neutral100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Ciclo: ${part.ciclo}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: Text(
                                        part.proximaAcao,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (part.vigenciaInicio != null &&
                                    part.vigenciaFim != null) ...[
                                  const SizedBox(height: AppSpacing.s8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Vigência: ${_formatarDataApenas(part.vigenciaInicio)} até ${_formatarDataApenas(part.vigenciaFim)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Card: Linha do Tempo Auditável
              SectionCard(
                title: 'Linha do Tempo Auditável',
                subtitle: papelConsulta == 'VOLUNTARIO'
                    ? 'Acompanhamento público sanitizado dos marcos e decisões.'
                    : 'Registro imutável de eventos e evidências autorizadas.',
                child: LinhaDoTempoWidget(
                  eventos: _eventos,
                  tituloSecao: '',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinhaInfo(String rotulo, String valor,
      {bool destaqueMonospaced = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              rotulo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontFamily: destaqueMonospaced ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarDataApenas(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toUtc();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year.toString();
      return '$dia/$mes/$ano';
    } catch (_) {
      return iso;
    }
  }
}

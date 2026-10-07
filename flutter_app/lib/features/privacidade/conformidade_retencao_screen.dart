import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import 'retencao_service.dart';

/// Painel administrativo de retenção e privacidade (AD-12 / LGPD).
///
/// Mobile-first, responsivo e acessível: loading, erro, acesso negado, vazio,
/// sucesso e confirmação explícita antes de executar. Nunca exibe IDs de
/// voluntários — apenas contagens agregadas.
class ConformidadeRetencaoScreen extends StatefulWidget {
  const ConformidadeRetencaoScreen({
    super.key,
    required this.gateway,
    this.onSair,
  });

  final RetencaoGateway gateway;
  final VoidCallback? onSair;

  @override
  State<ConformidadeRetencaoScreen> createState() =>
      _ConformidadeRetencaoScreenState();
}

class _ConformidadeRetencaoScreenState
    extends State<ConformidadeRetencaoScreen> {
  bool _carregando = true;
  bool _acessoNegado = false;
  String? _erro;
  IndicadoresRetencao? _indicadores;
  ResultadoRotinaRetencao? _resultado;
  bool _processando = false;
  String? _erroAcao;
  String? _mensagemAcao;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _acessoNegado = false;
    });
    try {
      final indicadores = await widget.gateway.consultarConformidade();
      if (!mounted) return;
      setState(() {
        _indicadores = indicadores;
        _carregando = false;
      });
    } on RetencaoAcessoNegadoException {
      if (!mounted) return;
      setState(() {
        _acessoNegado = true;
        _carregando = false;
      });
    } on RetencaoFalhaException catch (err) {
      if (!mounted) return;
      setState(() {
        _erro = err.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os indicadores de retenção.';
        _carregando = false;
      });
    }
  }

  Future<void> _executar({required bool dryRun}) async {
    setState(() {
      _processando = true;
      _erroAcao = null;
      _mensagemAcao = null;
    });
    try {
      final resultado = await widget.gateway.executarRotina(
        commandId: comandoOpaco(),
        dryRun: dryRun,
      );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _processando = false;
        _mensagemAcao = dryRun
            ? 'Simulação concluída. Nada foi alterado.'
            : 'Rotina executada com sucesso.';
      });
      if (!dryRun) {
        await _carregar();
      }
    } on RetencaoAcessoNegadoException {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erroAcao = 'Acesso negado. Você não tem autorização para executar a rotina.';
      });
    } on RetencaoFalhaException catch (err) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erroAcao = err.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erroAcao = 'Não foi possível executar a rotina. Tente novamente.';
      });
    }
  }

  Future<void> _confirmarExecucao() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar execução da rotina'),
        content: const Text(
          'A execução real anonimiza fichas encerradas elegíveis (mascarando nome, '
          'CPF e profissão) e expurga rascunhos abandonados. Os IDs de voluntários '
          'não são exibidos e a auditoria é gravada sem PII. Deseja continuar?',
        ),
        actions: [
          TextButton(
            key: const Key('retencao_cancelar_execucao'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('retencao_confirmar_execucao'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Executar rotina'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await _executar(dryRun: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(
              isMobile
                  ? AppSpacing.pagePaddingMobile
                  : AppSpacing.pagePaddingDesktop,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'Retenção e Privacidade',
                  subtitle:
                      'Minimização de dados, retenção de 5 anos e controles operacionais (AD-12 / LGPD).',
                  actions: [
                    SecondaryButton(
                      label: 'Atualizar',
                      icon: Icons.refresh,
                      onPressed: _carregando ? null : _carregar,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                _buildCorpo(isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCorpo(bool isMobile) {
    if (_carregando && _indicadores == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            LoadingSkeleton(height: 60),
            SizedBox(height: AppSpacing.s12),
            LoadingSkeleton(height: 140),
            SizedBox(height: AppSpacing.s12),
            LoadingSkeleton(height: 140),
          ],
        ),
      );
    }

    if (_acessoNegado) {
      return const ErrorState(
        title: 'Acesso negado',
        message:
            'Você não tem autorização para consultar os indicadores de retenção.',
        icon: Icons.lock_outline,
      );
    }

    if (_erro != null && _indicadores == null) {
      return ErrorState(
        title: 'Falha ao carregar conformidade',
        message: _erro!,
        onRetry: _carregar,
      );
    }

    final indicadores = _indicadores;
    if (indicadores == null) {
      return const EmptyState(
        title: 'Sem indicadores disponíveis',
        message: 'Não há dados de retenção para exibir no momento.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_erro != null) ...[
          _buildBannerErro(),
          const SizedBox(height: AppSpacing.s16),
        ],
        _buildPolitica(indicadores),
        const SizedBox(height: AppSpacing.s20),
        Text('Indicadores de Retenção', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.s12),
        _buildMetricas(indicadores, isMobile),
        const SizedBox(height: AppSpacing.s20),
        _buildDistribuicao(indicadores),
        const SizedBox(height: AppSpacing.s20),
        _buildAcoes(indicadores),
      ],
    );
  }

  Widget _buildBannerErro() {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('retencao_erro_banner'),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
          border: Border.all(color: AppColors.danger),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Não foi possível atualizar os indicadores',
                    style: AppTypography.label.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              _erro!,
              style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s8),
            SecondaryButton(
              key: const Key('retencao_banner_retry'),
              label: 'Tentar novamente',
              icon: Icons.refresh,
              onPressed: _carregar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolitica(IndicadoresRetencao indicadores) {
    final statusExpurgo = indicadores.expurgoAutomaticoHabilitado
        ? 'Habilitado'
        : 'Desabilitado';
    return SectionCard(
      title: 'Política vigente',
      subtitle: 'Fonte única de minimização e retenção (AD-12).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linhaInfo('Política', indicadores.politicaId),
          _linhaInfo('Retenção', '${indicadores.anosRetencao} anos'),
          _linhaInfo('Prazo de rascunho', '${indicadores.diasRascunho} dias'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                indicadores.expurgoAutomaticoHabilitado
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
                size: 18,
                color: indicadores.expurgoAutomaticoHabilitado
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.body,
                    children: [
                      const TextSpan(
                        text: 'Expurgo automático semanal: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: statusExpurgo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(rotulo, style: AppTypography.label),
          ),
          Expanded(
            child: Text(valor, style: AppTypography.body),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricas(IndicadoresRetencao indicadores, bool isMobile) {
    final cards = [
      MetricCard(
        title: 'Total de Fichas',
        value: indicadores.totalFichas.toString(),
        icon: Icons.folder_outlined,
        variant: MetricVariant.primary,
      ),
      MetricCard(
        title: 'Fichas Anonimizadas',
        value: indicadores.fichasAnonimizadas.toString(),
        icon: Icons.visibility_off_outlined,
        variant: MetricVariant.neutral,
      ),
      MetricCard(
        title: 'Fichas Ativas',
        value: indicadores.fichasAtivas.toString(),
        icon: Icons.verified_outlined,
        variant: MetricVariant.success,
      ),
      MetricCard(
        title: 'Elegíveis à Anonimização',
        value: indicadores.fichasElegiveisAnonimizacao.toString(),
        icon: Icons.auto_delete_outlined,
        variant: MetricVariant.warning,
      ),
      MetricCard(
        title: 'Rascunhos Elegíveis ao Expurgo',
        value: indicadores.rascunhosElegiveisExpurgo.toString(),
        icon: Icons.cleaning_services_outlined,
        variant: MetricVariant.danger,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: c,
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth > 1100
            ? 5
            : (constraints.maxWidth > 700 ? 3 : 2);
        final largura =
            (constraints.maxWidth - ((colunas - 1) * AppSpacing.s16)) / colunas;
        return Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: cards
              .map((c) => SizedBox(width: largura, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildDistribuicao(IndicadoresRetencao indicadores) {
    if (indicadores.porEstado.isEmpty) {
      return const EmptyState(
        title: 'Sem distribuição por estado',
        message: 'Nenhuma ficha cadastrada para distribuir por situação.',
        icon: Icons.pie_chart_outline,
      );
    }
    final entradas = indicadores.porEstado.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SectionCard(
      title: 'Distribuição por situação',
      subtitle: 'Somente contagens agregadas.',
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: entradas
            .map(
              (entrada) => StatusChip(
                status: entrada.key,
                label: '${entrada.key}: ${entrada.value}',
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAcoes(IndicadoresRetencao indicadores) {
    final resultado = _resultado;
    return SectionCard(
      title: 'Rotina de retenção',
      subtitle:
          'Simule antes de executar. A execução é auditada sem PII e nunca exibe IDs de voluntários.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              SecondaryButton(
                key: const Key('retencao_simular_button'),
                label: 'Simular',
                icon: Icons.play_circle_outline,
                isLoading: _processando,
                onPressed: _processando ? null : () => _executar(dryRun: true),
              ),
              DangerButton(
                key: const Key('retencao_executar_button'),
                label: 'Executar rotina',
                icon: Icons.auto_delete_outlined,
                isLoading: _processando,
                onPressed: _processando ? null : _confirmarExecucao,
              ),
            ],
          ),
          if (_erroAcao != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              liveRegion: true,
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
                      child: Text(_erroAcao!, style: AppTypography.body),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_mensagemAcao != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(_mensagemAcao!, style: AppTypography.body),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (resultado != null) ...[
            const SizedBox(height: AppSpacing.s16),
            Container(
              key: const Key('retencao_resultado'),
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.neutral150,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resultado.dryRun
                        ? 'Resultado da simulação'
                        : 'Resultado da execução',
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  _linhaInfo('Analisadas', resultado.totalAnalisadas.toString()),
                  _linhaInfo(
                    'Anonimizadas',
                    resultado.totalAnonimizadas.toString(),
                  ),
                  _linhaInfo('Expurgadas', resultado.totalExpurgadas.toString()),
                  _linhaInfo('Ignoradas', resultado.ignoradas.toString()),
                  if (resultado.repetido)
                    Text(
                      'Comando já processado anteriormente (no-op).',
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Fichas elegíveis à anonimização nesta política: '
            '${indicadores.fichasElegiveisAnonimizacao}. Rascunhos elegíveis ao expurgo: '
            '${indicadores.rascunhosElegiveisExpurgo}.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

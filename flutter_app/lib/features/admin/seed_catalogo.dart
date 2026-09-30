import 'package:flutter/material.dart';

import '../../comando.dart';
import '../../ui/identidade.dart';
import '../auth/auth_service.dart';

/// Tela para disparar o seed inicial do catálogo de igrejas e equipes.
/// Chama a callable `semearCatalogoInicial` com `commandId` opaco.
class SeedCatalogo extends StatefulWidget {
  const SeedCatalogo(this.gateway, {super.key});

  final SeedGateway gateway;

  @override
  State<SeedCatalogo> createState() => _SeedCatalogoState();
}

class _SeedCatalogoState extends State<SeedCatalogo> {
  bool _executando = false;
  SeedResultado? _resultado;
  String? _erro;

  /// Identificador opaco da tentativa atual. Uma retentativa após falha reusa
  /// o mesmo `commandId` para que o backend devolva o recibo já gravado em vez
  /// de reexecutar. Só um disparo novo (após sucesso) recebe outro id.
  late String _commandId = comandoOpaco();

  Future<void> _executar() async {
    final commandId = _commandId;
    setState(() {
      _executando = true;
      _erro = null;
      _resultado = null;
    });
    try {
      final resultado = await widget.gateway.semearCatalogo(commandId);
      if (mounted) {
        setState(() {
          _resultado = resultado;
          _executando = false;
          _commandId = comandoOpaco();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível executar o seed. Tente novamente.';
          _executando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  title: 'Seed do catálogo',
                  subtitle:
                      'Cria as igrejas e equipes iniciais do Maanaim a partir do '
                      'dataset canônico. A operação é idempotente: registros já '
                      'existentes não são alterados.',
                ),
                const SizedBox(height: 20),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Operação de Carga Inicial',
                        style: AppTypography.h3,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dispare o povoamento automático do catálogo com todas as '
                        'igrejas e equipes canônicas cadastradas.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        onPressed: _executando ? null : _executar,
                        isLoading: _executando,
                        icon: Icons.cloud_upload_outlined,
                        label: _executando
                            ? 'Executando…'
                            : 'Semear catálogo inicial',
                      ),
                    ],
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: AppGeometry.cardBorderRadius,
                        border: Border.all(
                          color: AppColors.border,
                          width: AppGeometry.borderWidth,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _erro!,
                              style: AppTypography.body
                                  .copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    onPressed: _executar,
                    icon: Icons.refresh,
                    label: 'Tentar novamente',
                  ),
                ],
                if (_resultado != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: AppGeometry.cardBorderRadius,
                        border: Border.all(
                          color: AppColors.border,
                          width: AppGeometry.borderWidth,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: AppColors.success),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _resultado!.repetido
                                      ? 'Seed já executado (idempotente)'
                                      : 'Seed concluído',
                                  style: AppTypography.h3
                                      .copyWith(color: AppColors.success),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _resultado!.resumo,
                            style: AppTypography.body
                                .copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

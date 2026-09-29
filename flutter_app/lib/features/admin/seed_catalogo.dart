import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../../comando.dart';

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
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Seed do catálogo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cria as igrejas e equipes iniciais do Maanaim a partir do '
                  'dataset canônico. A operação é idempotente: registros já '
                  'existentes não são alterados.',
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _executando ? null : _executar,
                  icon: _executando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                      _executando ? 'Executando…' : 'Semear catálogo inicial'),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color:
                                    Theme.of(context).colorScheme.onErrorContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _erro!,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _executar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
                if (_resultado != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _resultado!.repetido
                                        ? 'Seed já executado (idempotente)'
                                        : 'Seed concluído',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _resultado!.resumo,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
                            ),
                          ],
                        ),
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

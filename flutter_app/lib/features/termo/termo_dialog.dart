import 'package:flutter/material.dart';

import 'termo_adesao_model.dart';
import 'termo_adesao_widget.dart';

/// Exibe o diálogo responsivo para leitura e impressão do Termo de Adesão.
Future<void> exibirTermoAdesaoDialog(
  BuildContext context,
  TermoAdesaoModel model,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Termo de Adesão de Voluntário'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          body: TermoAdesaoWidget(
            model: model,
            onFechar: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
    },
  );
}

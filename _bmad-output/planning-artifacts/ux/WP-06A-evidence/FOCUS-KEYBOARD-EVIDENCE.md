# WP-06A — Evidência de foco e navegação por teclado

Data: 13/10/2026

## Cenário verificado

- Tela: Fila de Conclusão do Coordenador.
- Viewport: 1024 × 768 px.
- Sequência exercitada: eventos reais de tecla `Tab` enviados pelo `WidgetTester`.
- Resultado esperado: o foco alcança `Analisar`, `Recusar` e `Homologar e Ativar` sem ocultar qualquer ação.

## Evidência automatizada

Teste: `WP-06A: teclado percorre as três ações do Coordenador em 1024px`, em `flutter_app/test/fila_coordenador_test.dart`.

Comando executado:

```text
flutter test test/fila_coordenador_test.dart --plain-name 'WP-06A: teclado percorre as três ações do Coordenador em 1024px'
```

Resultado:

```text
00:00 +0: WP-06A: teclado percorre as três ações do Coordenador em 1024px
00:01 +1: All tests passed!
```

O teste percorre até 30 posições de foco, registra quais das três ações recebem foco e exige o conjunto exato `{Analisar, Recusar, Homologar e Ativar}`.

## Limitação registrada

A tentativa de inspeção visual interativa no navegador não iniciou porque o serviço local `codex app-server` não estava disponível (`No such file or directory`). Nenhum foco visual foi fabricado. A evidência deste lote é, portanto, a navegação automatizada por teclado acima, complementada pela captura real da tela em 1024 px.

---
title: 'Dashboard de Boas-Vindas do Administrador'
type: 'feature'
created: '2026-10-19'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Ao fazer login como Administrador, o sistema direciona automaticamente para a tela de gestão de igrejas (`_indice = 0`), gerando desorientação e atrito na navegação pelas demais áreas do sistema.

**Approach:** Criar a tela de boas-vindas `AdminDashboardScreen` organizada em cards temáticos para navegação rápida (Cadastros, Operação e Governança/Sistema) e integrá-la como a aba inicial padrão (`Início`) do `AdminShell`, mantendo o Design System institucional e acessibilidade WCAG 2.2 AA.

</frozen-after-approval>

## Implementation Notes

- Criado `AdminDashboardScreen` (`lib/features/admin/admin_dashboard_screen.dart`) com seções temáticas (Cadastros, Operação, Governança & Sistema), cards interativos com foco visível, touch target ≥ 44px e layout responsivo adaptativo (1, 2 ou 3 colunas conforme largura).
- Integrado `AdminDashboardScreen` como aba 0 (`Início`) em `AdminShell` (`lib/features/admin/admin_shell.dart`), repassando o callback canônico `_navegarPara` e sinalizadores de filas opcionais disponíveis.
- Atualizado `admin_shell_test.dart` com finders semânticos para discriminar `AppSidebar` e `AdminDashboardScreen`, validando a navegação via cards da dashboard e via menu lateral.
- Criada suíte de testes dedicada `admin_dashboard_screen_test.dart` cobrindo renderização de seções, acessibilidade Semantics, toque mínimo, responsividade e invocação de callbacks.
- Verificado via `dart analyze` (0 erros) e testes unitários/widget (100% de sucesso).
- Conectado via DTD com hot reload acionado em tempo real na aplicação web ativa.

## Review Triage Log

- finding: Área de toque e navegação por teclado nos cards.
  verdict: high (verificado e atendido)
  evidence: `minHeight: AppGeometry.minTouchTarget + 16` (60px) com anel de foco `_emFoco` e Semantics button.
- finding: Responsividade em larguras móveis estreitas (<400px).
  verdict: medium (verificado e atendido)
  evidence: `LayoutBuilder` com coluna única no celular, `Wrap` flexível e `SingleChildScrollView` sem overflow.
- finding: Consistência de tokens de cores Maanaim.
  verdict: low (verificado e atendido)
  evidence: Uso exclusivo de tokens institucionais (`AppColors.surface`, `AppColors.border`, `AppColors.blue50`, `AppColors.blue600`, etc.).

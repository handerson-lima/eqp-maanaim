---
title: '8.2 — Corrigir tokens acessíveis e componentes compartilhados'
type: 'refactor'
created: '2026-10-09'
status: 'in-progress'
route: 'dispatch'
baseline_commit: 19288a73614c40f89c46e0c986f14cb698597069
review_loop_iteration: 0
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os tokens semânticos anteriores (#16A34A, #F59E0B, #EF4444) e bordas neutras (#DDE3EA) apresentam contraste insuficiente contra fundos claros em conformidade estrita WCAG 2.2 AA (<4,5:1 para texto normal e <3:1 para limites de controle interativo), botões carecem de especificação explícita de todos os estados (default, hover, focus, pressed, disabled, loading), inexiste componente compartilhado de input com labels persistentes e foco visível, e remanescem gradientes decorativos no painel de autenticação.

**Approach:** Atualizar `AppColors` para a escala semântica acessível (#16794A, #9A6700, #B42318, #667085) e novos tokens de foco/borda interativa; aprimorar `temaMaanaim()` e `PrimaryButton`, `SecondaryButton`, `ApproveButton`, `DangerButton`/`RejectButton` para cobrir todos os 6 estados e suportar redimensionamento a 200% sem truncamento de texto essencial; criar componente compartilhado de inputs acessíveis com rótulo persistente, foco reforçado e alvos ≥44px; refinar `StatusChip` com contraste e ícones semânticos; e remover gradientes decorativos em favor do navy institucional #082C49 sólido.

## Boundaries & Constraints

**Always:**
- Cumprir WCAG 2.2 AA: contraste de texto normal ≥ 4,5:1; controles/foco visível ≥ 3:1 contra superfícies adjacentes aplicáveis.
- Alvos de toque interativos ≥ 44x44 px.
- Status chips devem sempre incluir texto e ícone (nunca depender exclusivamente de cor).
- Inputs devem possuir rótulo persistente acima do campo, mensagem de erro associada e foco visível (espessura ≥ 2px).
- Botões devem suportar texto com escala de 200% sem truncar o rótulo de ação essencial.
- Preservar identidade institucional: Navy #082C49, Azul #0B6FE8, superfícies claras, cantos com raios padronizados (`AppGeometry`).

**Never:**
- Não usar gradientes decorativos, tons de roxo ou glassmorphism.
- Não usar borda decorativa sutil (#DDE3EA) como único delimitador de controle interativo sem foco ou borda interativa.
- Não alterar contratos de domínio, autenticação Firebase, Cloud Functions ou regras do Firestore.
- Não usar opacidade que degrade a legibilidade de foco ou textos em botões desabilitados.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Contraste de texto semântico | Textos e chips com success, warning, danger | Contraste calculado ≥ 4,5:1 contra os fundos semânticos e superfícies (#EAF8EF, #FFF6DE, #FDECEC, #FFFFFF) | Cores normalizadas em AppColors |
| Estados completos de botões | Interação do usuário (default, hover, focus, pressed, disabled, loading) | Feedback visual imediato em cada estado; foco exibe anel/borda azul nítida (≥2px); loading exibe spinner acessível com Semantics; disabled bloqueia cliques sem quebrar contraste | Cliques bloqueados em disabled e loading |
| Rótulo persistente em inputs | Campo vazio, com foco, preenchido ou com erro | Rótulo permanece visível acima do campo em todos os momentos; se houver erro, mensagem em vermelho exibida abaixo e associada semanticamente | Validação visual inline acessível |
| Escala de texto 200% | TextScaler(2.0) em botões e inputs | Alvos crescem e rótulos expandem sem truncamento de ação essencial | Layout flexível vertical com minHeight 44px |
| Remoção de gradiente | Renderização de PainelAcesso no desktop | Fundo navy sólido #082C49 sem LinearGradient | N/A |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/ui/tokens.dart` -- Atualizar AppColors (success, warning, danger, borderInteractive, focusLight, focusDark) e validar geometria e tipografia.
- `flutter_app/lib/ui/theme.dart` -- Atualizar temaMaanaim() para refletir novas cores de outline, foco, inputDecorationTheme, button themes e estados.
- `flutter_app/lib/ui/components/buttons.dart` -- Padronizar PrimaryButton, SecondaryButton, ApproveButton, DangerButton, RejectButton e IconActionButton para cobrir default, hover, focus, pressed, disabled, loading e texto com escala 200%.
- `flutter_app/lib/ui/components/inputs.dart` -- Novo componente compartilhado AppTextField (e AppDropdownField) com label persistente, foco visível (≥2px), erro acessível e alvo ≥44px.
- `flutter_app/lib/ui/components/components.dart` -- Exportar novos componentes de inputs.
- `flutter_app/lib/ui/components/status_chips.dart` -- Reforçar contraste e semântica com os novos tokens acessíveis.
- `flutter_app/lib/ui/identidade.dart` -- Remover gradiente do PainelAcesso, substituindo por AppColors.navy900 sólido.
- `flutter_app/test/ui/theme_tokens_test.dart` -- Testar os novos tokens e conferir contrastes matemáticos sRGB/WCAG.
- `flutter_app/test/ui_components_test.dart` -- Testar estados completos de botões, inputs com labels persistentes, alvos de 44px e escala de 200%.

## Tasks & Acceptance

**Execution:**
- [ ] `flutter_app/lib/ui/tokens.dart` -- Atualizar AppColors com success #16794A, warning #9A6700, danger #B42318, borderInteractive #667085, focusLight #0B6FE8, focusDark #FFFFFF -- Garantir pares WCAG 2.2 AA.
- [ ] `flutter_app/lib/ui/theme.dart` -- Refinar temaMaanaim() com inputDecorationTheme, focusColor, outlineVariant e button themes alinhados ao contrato visual -- Propagação consistente do tema.
- [ ] `flutter_app/lib/ui/components/buttons.dart` -- Implementar suporte completo aos 6 estados (default, hover, focus, pressed, disabled, loading) e flexibilidade para texto 200% -- Atendimento ao AC 2 e AC 3.
- [ ] `flutter_app/lib/ui/components/inputs.dart` -- Criar AppTextField e AppDropdownField com label persistente, foco visível, erro associado e minHeight ≥ 44px -- Atendimento ao AC 4.
- [ ] `flutter_app/lib/ui/components/components.dart` -- Exportar inputs.dart -- Integrar ao catálogo compartilhado.
- [ ] `flutter_app/lib/ui/components/status_chips.dart` -- Garantir que status sempre exibem texto e ícone com os novos tokens acessíveis -- Atendimento ao AC 2.
- [ ] `flutter_app/lib/ui/identidade.dart` -- Substituir LinearGradient por navy900 sólido -- Atendimento ao AC 5 (sem gradientes).
- [ ] `flutter_app/test/ui/theme_tokens_test.dart` -- Atualizar suite de testes de tokens para cobrir novos valores e fórmulas matemáticas de contraste -- Validação de AC 1 e AC 5.
- [ ] `flutter_app/test/ui_components_test.dart` -- Adicionar testes de widgets para estados de botões, inputs, foco e texto 200% -- Validação de AC 2, AC 3 e AC 4.

**Acceptance Criteria:**
- Given os tokens em AppColors, when calculados os contrastes sRGB, then todos os pares normativos alcançam ≥ 4,5:1 para texto normal e ≥ 3:1 para limites interativos/foco.
- Given qualquer botão compartilhado (Primary, Secondary, Approve, Danger), when renderizado nos estados default, hover, focus, pressed, disabled e loading, then cada estado tem apresentação distinta, foco visível e alvo ≥ 44px.
- Given um botão compartilhado renderizado com textScaler 2.0, when medido seu conteúdo, then o texto essencial da ação é mantido sem truncamento indevido.
- Given o componente AppTextField, when renderizado, then exibe label persistente acima do campo, contorno de foco com espessura ≥ 2px e erro acessível quando presente.
- Given PainelAcesso, when renderizado, then utiliza fundo navy sólido sem gradientes decorativos.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `cd flutter_app && flutter test test/ui/theme_tokens_test.dart` -- expected: Todos os testes de tokens e contraste passam.
- `cd flutter_app && flutter test test/ui_components_test.dart` -- expected: Todos os testes de componentes passam.
- `cd flutter_app && flutter analyze` -- expected: No issues found.

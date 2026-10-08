---
title: 'Story 6.5: Acesso inclusivo e responsivo às superfícies do voluntariado'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_commit: '56fd15b40b731631a5f2e5e87bb75ac62f134c38'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Embora o sistema possua componentes base institucionais, diversas superfícies operacionais (fichas, filas de aprovação, relatórios, auditoria e dashboards) precisam garantir conformidade rigorosa com WCAG 2.2 AA em todos os viewports (celular 390x844, tablet 768x1024 e desktop 1280x800). Faltam: garantia de que estados de aprovação/cancelamento/vigência/erro nunca dependam somente de cor (exigindo texto + ícone + orientação para a próxima ação), adaptação canônica de tabelas para cartões touch-friendly no mobile, foco visível de alto contraste e operabilidade completa via teclado e leitor de tela com alvos mínimos de 44 px.

**Approach:** Padronizar e aprimorar o sistema de design e componentes Flutter (`StatusChip` com ícones semânticos para cada estado, `FeedbackOrientacaoCard` para orientações acionáveis com a mensagem canônica para decisões desfavoráveis, e `AppDataTable`/`ResponsiveRecordList` para adaptação automática de tabelas em cards verticais no mobile); refinar o `ThemeData` institucional com foco visível de alto contraste (halo/outline 2px) e suporte a navegação por teclado/leitor de tela; e cobrir com testes automatizados de responsividade e acessibilidade em todas as superfícies principais.

## Boundaries & Constraints

**Always:**
- Mobile-first: interface desenhada primariamente para celular (390x844), adaptando-se fluidamente para tablet (600–1023px) e desktop (≥1024px); sem overflow horizontal ou quebra de texto.
- WCAG 2.2 AA: foco visível com contraste mínimo de 3:1 em todos os elementos interativos; nenhum estado comunicado unicamente por cor (sempre texto + ícone semântico explícito); alvos de toque com dimensão mínima de 44x44 px (`AppGeometry.minTouchTarget`).
- Decisão negativa ou cancelamento: mensagem voltada ao voluntário deve ser exatamente "Procure o Pastor da igreja local para mais informações", sem expor motivo interno, ator ou termos desnecessários.
- Fidelidade aos tokens institucionais (`navy-900`, `blue-600`, `surface`, etc.), sem introduzir gradientes decorativos ou glassmorphism.
- Semântica e leitores de tela: todo botão, link, chip de status e campo de formulário deve possuir rótulo semântico e anúncio de estado via `Semantics`.

**Never:**
- Não usar cores isoladas para indicar aprovação, pendência, cancelamento ou vigência.
- Não permitir alvos de toque inferiores a 44x44 px em qualquer botão, ícone de ação, item de menu ou controle de formulário.
- Não forçar rolagem horizontal de tabelas no mobile quando uma representação em cartões (`ResponsiveRecordList`) puder apresentar os dados de forma legível e empilhada.
- Não introduzir dados ou enums hardcoded de igrejas e equipes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visualização de status sem depender de cor | `status: 'ATIVA'`, `'REJEITADA'`, `'EM_RENOVACAO'`, `'EXPIRADA'` | Renderiza `StatusChip` com texto em caixa alta, ícone semântico correspondente e container semântico acessível (`Semantics`) | Tipo desconhecido exibe ícone informativo neutro e texto original |
| Orientação de decisão negativa ao voluntário | Decisão desfavorável ou cancelamento de participação | `FeedbackOrientacaoCard` exibe ícone de alerta/bloqueio, texto de status e orientação exata: "Procure o Pastor da igreja local para mais informações" | N/A |
| Visualização em tela pequena (mobile < 600px) | Viewport 390x844 (celular) | `AppShell` converte sidebar em Drawer acionado por menu hambúrguer; tabelas (`AppDataTable`) alternam para cartões verticais empilhados; zero overflow | Conteúdo longo empilha verticalmente com rolagem fluida |
| Navegação por teclado em formulários e tabelas | Tecla Tab / Shift+Tab em campos e botões | Foco visual evidente com halo/borda contrastante de 2px; ordem lógica de foco respeitada; botões operáveis via Enter/Espaço | Elementos desabilitados não recebem foco ativo |
| Alvo de toque em botões e ícones | Interação de toque ou clique | Todos os botões, ícones de ação e chips interativos mantêm área de toque ≥ 44x44 px | N/A |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/ui/tokens.dart` -- Tokens institucionais de cor, espaçamento, tipografia e `AppGeometry.minTouchTarget` (44.0).
- `flutter_app/lib/ui/theme.dart` -- Configuração do `ThemeData` institucional com foco visível de alto contraste, tamanhos mínimos de toque e Material 3.
- `flutter_app/lib/ui/components/status_chips.dart` -- `StatusChip` e `StatusConfig` com ícone semântico obrigatório por estado (`showIcon: true`) e semântica acessível.
- `flutter_app/lib/ui/components/feedback_orientacao_card.dart` -- Componente canônico de feedback/orientação acessível com ícone, texto e orientação para a próxima ação.
- `flutter_app/lib/ui/components/responsive_data_table.dart` -- `AppDataTable` e `ResponsiveRecordList` para alternância automática tabela/cartões conforme o viewport.
- `flutter_app/lib/ui/components/app_shell.dart` -- Shell institucional com Drawer no mobile, sidebar compacta no tablet e fixa no desktop.
- `flutter_app/lib/ui/components/components.dart` -- Exportação unificada dos componentes do Design System.
- `flutter_app/test/acesso_inclusivo_responsivo_test.dart` -- Suite de testes automatizados de responsividade e acessibilidade WCAG 2.2 AA.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/lib/ui/components/status_chips.dart` -- Adicionar ícone canônico para cada `StatusType` em `StatusConfig`, renderizar ícone + texto no `StatusChip` e encapsular em `Semantics` -- Atender WCAG 1.4.1 (não depender apenas de cor).
- [x] `flutter_app/lib/ui/components/feedback_orientacao_card.dart` -- Criar `FeedbackOrientacaoCard` para exibir status, ícone e orientação para próxima ação (incluindo texto canônico pastoral para decisões negativas) -- Cumprir critério de orientação acessível da Story 6.5.
- [x] `flutter_app/lib/ui/components/responsive_data_table.dart` -- Criar `AppDataTable<T>`, `ResponsiveRecordList<T>` e `FilterBar` com layout fluido, alvos ≥ 44px e adaptação tabela/card conforme viewport -- Atender especificação de dados operacionais do COMPONENT-CATALOG.
- [x] `flutter_app/lib/ui/components/components.dart` -- Exportar os novos componentes `feedback_orientacao_card.dart` e `responsive_data_table.dart` -- Manter catálogo modular e limpo.
- [x] `flutter_app/lib/ui/theme.dart` -- Refinar `temaMaanaim` adicionando indicadores visíveis de foco de alto contraste para botões, campos e chips, e reforçando densidade acessível -- Cumprir WCAG 2.4.7 e 2.4.13.
- [x] `flutter_app/test/acesso_inclusivo_responsivo_test.dart` -- Implementar testes de widget e acessibilidade cobrindo: 1) visualização sem overflow em mobile (390x844), tablet (768x1024) e desktop (1280x800); 2) status textual + ícone; 3) alvos ≥ 44px; 4) foco e navegação por teclado; 5) mensagens com orientação à próxima ação -- Garantir verificação automatizada completa.

**Acceptance Criteria:**
- Given as superfícies de ficha, participações, fila, detalhe, renovação, administração e relatórios, when são exibidas em celular, tablet ou desktop, then aplicam tokens Material 3, escala de espaçamento e estados textual+ícone definidos no DESIGN.md, and navegação lateral/tabelas adaptam-se para menu compacto/cartões conforme o viewport.
- Given uma pessoa navega somente com teclado ou leitor de tela, when interage com ações, estados, filtros, formulários e confirmações críticas, then encontra foco visível, ordem de foco lógica, nomes/estados anunciados e ações operáveis sem ponteiro, and controles de toque têm ao menos 44 px.
- Given uma informação de aprovação, cancelamento, vigência ou erro, when é apresentada na interface, then atende WCAG 2.2 AA e não depende apenas de cor, and mantém texto, ícone e orientação para a próxima ação.

## Implementation Notes

- StatusChip agora inclui ícone canônico obrigatório em cada StatusConfig e exclui semântica duplicada interna (`excludeSemantics: true`), garantindo leitura límpida em leitores de tela e conformidade estrita com WCAG 1.4.1 (estados nunca apenas por cor).
- Criado `FeedbackOrientacaoCard` com fábrica `decisaoDesfavoravel` implementando a orientação canônica textual exata: "Procure o Pastor da igreja local para mais informações" (invariante do domínio Maanaim).
- Criados `AppDataTable`, `ResponsiveRecordList` e `FilterBar` no catálogo unificado de componentes, permitindo alternância automática de tabelas complexas para cartões verticais no mobile (<768px ou configurável).
- Refinado o tema institucional (`temaMaanaim`) com `focusColor`, `focusedBorder` de alto contraste (2.0px), `iconButtonTheme` respeitando `AppGeometry.minTouchTarget` (44px) e `tooltipTheme`.
- Suite automatizada `test/acesso_inclusivo_responsivo_test.dart` criada com 11 testes cobrindo todos os critérios de aceite; suite completa do projeto executada com 278 testes passando.

## Spec Change Log

## Review Triage Log

- finding: 'Garantir que StatusChip não duplique anúncios em leitores de tela quando envolvido em Semantics'
  verdict: 'resolved'
  evidence: 'Adicionado excludeSemantics: true ao Semantics do StatusChip, validado por teste automatizado.'
- finding: 'Verificar suporte à orientação canônica para decisões desfavoráveis conforme SPEC'
  verdict: 'resolved'
  evidence: 'FeedbackOrientacaoCard.decisaoDesfavoravel provê exatamente "Procure o Pastor da igreja local para mais informações".'
- finding: 'Verificar alvos de toque mínimos de 44x44px em botões, campos e tabela'
  verdict: 'resolved'
  evidence: 'ThemeData, IconActionButton, buttons e AppDataTable utilizam AppGeometry.minTouchTarget (44.0).'

## Design Notes

- Ícones canônicos por estado:
  - `ATIVA` / `APROVADA`: `Icons.check_circle_outline` (verde success)
  - `AGUARDANDO` / `EM_APROVACAO`: `Icons.hourglass_top_outlined` (âmbar warning)
  - `EM_RENOVACAO`: `Icons.sync_outlined` (âmbar warning)
  - `REJEITADA`: `Icons.cancel_outlined` (vermelho danger)
  - `CANCELADA`: `Icons.do_not_disturb_on_outlined` (vermelho danger)
  - `EXPIRADA`: `Icons.timer_off_outlined` (vermelho danger)
  - `INATIVA` / `RASCUNHO`: `Icons.pause_circle_outline` (neutro)
- Orientação canônica para decisão desfavorável/cancelamento por liderança: "Procure o Pastor da igreja local para mais informações" (invariante de privacidade e acolhimento do domínio).

## Verification

**Commands:**
- `flutter test test/acesso_inclusivo_responsivo_test.dart` -- expected: All accessibility and responsive tests pass
- `flutter test` -- expected: All 267+ tests pass without regressions

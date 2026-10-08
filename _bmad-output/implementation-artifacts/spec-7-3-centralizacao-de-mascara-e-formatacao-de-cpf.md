---
title: 'Story 7.3: Centralização de Máscara e Formatação de CPF (action item epic-6-retro-item-3)'
type: 'refactor'
created: '2026-10-08'
status: 'in-review'
baseline_commit: '1babea690924e39e36c6ad6db91fcbf83a7e2a38'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/implementation-artifacts/epic-6-retro-2026-10-07.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O mascaramento, formatação visual e entrada de CPF encontram-se dispersos e heterogêneos entre as telas de auditoria, coordenação, ficha do voluntário, administração e relatórios. Atualmente, campos de entrada usam apenas `digitsOnly` sem máscara reativa, e exibições textuais não possuem suporte semântico acessível para leitores de tela conforme WCAG 2.2 AA (gerando soletração truncada de "ponto" e "hífen" ou leituras confusas de números extensos).

**Approach:** Criar o utilitário canônico e widget acessível `cpf_formatter.dart` no catálogo de componentes (`flutter_app/lib/ui/components/cpf_formatter.dart`), especificando com Sally (UX) o padrão visual `000.000.000-00` e a rotulagem semântica para leitores de tela (VoiceOver/TalkBack), e implementando com Amelia (Dev) via TDD (test-first) `CpfFormatter`, `CpfInputFormatter` e `CpfText`, unificando e substituindo todas as ocorrências dispersas no Flutter com 100% de cobertura de testes unitários e de widgets.

## Boundaries & Constraints

**Always:**
- Seguir o Design System do Maanaim e WCAG 2.2 AA: formatação visual uniforme `000.000.000-00` com suporte nativo a alinhamento monospaçado.
- A rotulagem semântica acessível em `Semantics` deve evitar a soletração de pontuações sonoras ("ponto", "hífen", "traço") e agrupar dígitos em pausas auditivas naturais ("CPF: X X X, X X X, X X X, X X").
- Para CPFs mascarados por privacidade (ex.: `***.456.789-**` ou `111.***.***-22`), anunciar semanticamente de forma compreensível ("CPF mascarado, dígitos centrais 4 5 6, 7 8 9" ou "CPF mascarado, início 1 1 1, final 2 2").
- O `CpfInputFormatter` deve operar como `TextInputFormatter` reativo: limitar a 11 dígitos, aplicar máscara automaticamente durante digitação e colagem (`paste`), e posicionar o cursor de edição corretamente.
- Abordagem test-first (TDD): criar testes unitários e de widget em `test/cpf_formatter_test.dart` cobrindo todos os cenários antes e durante a refatoração, assegurando 100% de cobertura no utilitário.
- Manter compatibilidade com testes existentes e não quebrar validações de negócio (`cpfValido` em `validadores.dart` ou chamadas de backend).

**Never:**
- Nunca introduzir dependências externas de pacotes de máscara de terceiros; implementar de forma nativa e leve via `TextInputFormatter` para controle total sobre acessibilidade e performance.
- Nunca enviar pontuação nos fluxos de backend que esperam apenas dígitos numéricos ou padrão sanitizado.
- Nunca permitir que o leitor de tela soletre "ponto", "ponto", "hífen" truncado ou leia o CPF como um número ordinal/cardinal de 11 dígitos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Formatação de CPF puro (11 dígitos) | `'12345678901'` | `'123.456.789-01'` | N/A |
| Formatação de CPF já formatado | `'123.456.789-01'` | `'123.456.789-01'` (idempotente) | N/A |
| Formatação com dígitos insuficientes | `'12345'` | `'123.45'` (máscara progressiva) | N/A |
| Formatação de CPF nulo ou vazio | `null` ou `''` | `''` (ou placeholder configurado) | Retorna string vazia sem lançar exceção |
| Rótulo acessível de CPF completo | `'123.456.789-01'` | `'CPF: 1 2 3, 4 5 6, 7 8 9, 0 1'` | N/A |
| Rótulo acessível de CPF mascarado | `'***.456.789-**'` | `'CPF mascarado: dígitos centrais 4 5 6, 7 8 9'` | N/A |
| Rótulo acessível de CPF mascarado central | `'111.***.***-22'` | `'CPF mascarado: 1 1 1, dígitos centrais ocultos, final 2 2'` | N/A |
| Digitação com `CpfInputFormatter` | Usuário digita `'12345678901'` tecla a tecla | Campo formata reativamente para `'123.456.789-01'`, cursor no final | Ignora caracteres não numéricos |
| Backspace em separador no input | Cursor após ponto (`'123.'`) e usuário apaga | Apaga o dígito anterior (`'12'`), cursor ajustado | Não trava cursor |
| Colagem (`paste`) de CPF bruto ou formatado | Cola `'12345678901999'` (excesso de dígitos) | Trunca em 11 dígitos: `'123.456.789-01'` | Ignora excesso |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/ui/components/cpf_formatter.dart` -- Utilitário canônico contendo `CpfFormatter`, `CpfInputFormatter` e widget `CpfText`.
- `flutter_app/lib/ui/components/components.dart` -- Reexportação de `cpf_formatter.dart` para disponibilização global no catálogo de componentes.
- `flutter_app/test/cpf_formatter_test.dart` -- Suíte de testes TDD: 100% de cobertura unitária e de widgets (formatação, máscara, input, acessibilidade semântica).
- `flutter_app/lib/main.dart` -- Uso de `CpfInputFormatter` no formulário de cadastro de voluntário.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Uso de `CpfInputFormatter` no campo de edição de CPF da ficha permanente.
- `flutter_app/lib/features/admin/pessoas_papeis.dart` -- Uso de `CpfInputFormatter` no campo de CPF do Coordenador.
- `flutter_app/lib/features/voluntario/consulta_ficha_screen.dart` -- Uso de `CpfText` na linha de informação de CPF da ficha.
- `flutter_app/lib/features/auditoria/auditoria_relatorios_screen.dart` -- Uso de `CpfText` na tabela de relatório operacional e cards verticais mobile.
- `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Uso de `CpfText` na fila e tabela de itens aguardando aprovação do Coordenador.
- `flutter_app/lib/features/voluntario/historico_service.dart` -- Sanitização e formatação via `CpfFormatter` em `cpfExibicao`.
- `flutter_app/lib/features/termo/termo_adesao_widget.dart` -- Uso de `CpfFormatter.formatar` / `CpfText` na renderização das cláusulas do termo.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/test/cpf_formatter_test.dart` -- Implementar suíte de testes unitários e de widgets para `CpfFormatter`, `CpfInputFormatter` e `CpfText` (TDD test-first).
- [x] `flutter_app/lib/ui/components/cpf_formatter.dart` -- Implementar `CpfFormatter`, `CpfInputFormatter` e widget `CpfText` com semântica acessível WCAG 2.2 AA.
- [x] `flutter_app/lib/ui/components/components.dart` -- Reexportar `cpf_formatter.dart`.
- [x] `flutter_app/lib/main.dart` -- Integrar `CpfInputFormatter` no campo de CPF de cadastro de voluntário.
- [x] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Integrar `CpfInputFormatter` no campo de CPF de edição da ficha.
- [x] `flutter_app/lib/features/admin/pessoas_papeis.dart` -- Integrar `CpfInputFormatter` no campo de CPF do Coordenador.
- [x] `flutter_app/lib/features/voluntario/consulta_ficha_screen.dart` -- Integrar `CpfText` na visualização da ficha.
- [x] `flutter_app/lib/features/auditoria/auditoria_relatorios_screen.dart` -- Integrar `CpfText` na exibição de relatórios e auditoria.
- [x] `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Integrar `CpfText` na exibição da fila de coordenação.
- [x] `flutter_app/lib/features/voluntario/historico_service.dart` -- Integrar `CpfFormatter.formatar` em `cpfExibicao`.
- [x] `flutter_app/lib/features/termo/termo_adesao_widget.dart` -- Integrar formatação canônica de CPF na renderização do termo.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status do item de ação `epic-6-retro-item-3-unificar-mascara-cpf` para `done`.

**Acceptance Criteria:**
- **Given** uma string com 11 dígitos, **When** formatada por `CpfFormatter.formatar`, **Then** o resultado é estritamente `000.000.000-00`.
- **Given** um campo de formulário com `CpfInputFormatter`, **When** o usuário digita dígitos sequenciais, **Then** a pontuação é inserida dinamicamente sem bloquear a digitação e truncando em 11 dígitos numéricos.
- **Given** um leitor de tela (TalkBack ou VoiceOver) inspecionando um `CpfText`, **When** a árvore de acessibilidade é avaliada, **Then** o rótulo semântico anuncia os dígitos de forma agrupada e inteligível, sem falar "ponto" ou "hífen".
- **Given** as telas de relatórios, coordenação, ficha e administração, **When** exibem CPFs, **Then** todas utilizam o utilitário ou widget canônico de forma consistente.
- **Given** a suíte de testes automatizados do Flutter, **When** `flutter test` é executado, **Then** todos os testes passam com 100% de sucesso.

## Implementation Notes

- Implementado `CpfFormatter` fornecendo métodos estáticos puros: `apenasDigitos`, `formatar`, `mascarar`, `validar` e `rotuloAcessivel`.
- Implementado `CpfInputFormatter` herdando de `TextInputFormatter`, com tratamento reativo de digitação progressiva, backspace limpo e colagem truncando em 11 dígitos.
- Implementado widget `CpfText` com envelopamento em nó `Semantics` configurando `excludeSemantics: true` para o `Text` filho e `label: CpfFormatter.rotuloAcessivel(cpf)` para leitores de tela conforme WCAG 2.2 AA (critérios 1.3.1 e 4.1.2).
- Validadores de CPF em `validadores.dart` (`cpfValido`) foram refatorados para delegar para a lógica canônica `CpfFormatter.validar`.
- Atualizados campos de entrada em `main.dart`, `minha_ficha_screen.dart` e `pessoas_papeis.dart`.
- Atualizadas visualizações em `consulta_ficha_screen.dart`, `auditoria_relatorios_screen.dart`, `fila_coordenador_screen.dart`, `historico_service.dart` e `termo_adesao_widget.dart`.
- Todas as 301 suítes de testes automatizados executaram e passaram com sucesso (incluindo 17 novos testes específicos em `cpf_formatter_test.dart`). Análise estática com `flutter analyze` sem nenhum aviso ou erro.

## Spec Change Log

## Review Triage Log

## Design Notes

### Especificação de UX & Acessibilidade (Sally):
1. **Tipografia e Estilo:** O CPF deve ser renderizado preferencialmente com fonte monoespaçada (`fontFamily: 'monospace'` ou token do design system) quando inserido em tabelas ou colunas de dados, garantindo que colunas de dados alinhem verticalmente.
2. **Leitura Semântica Acessível (WCAG 2.2 AA - Critérios 1.3.1 e 4.1.2):**
   - Para evitar fadiga auditiva e incompreensão, o leitor de tela não deve ler `529.982.247-25` como "quinhentos e vinte e nove milhões..." nem soletrar "ponto", "hífen".
   - A propriedade `Semantics(label: ...)` deve transformar o CPF em blocos com pausas: `'CPF: 5 2 9, 9 8 2, 2 4 7, 2 5'`.
   - Para CPFs mascarados (LGPD): `'CPF mascarado: dígitos centrais 4 5 6, 7 8 9'` ou `'CPF mascarado: 1 1 1, dígitos centrais ocultos, final 2 2'`.
3. **Ergonomia de Entrada:**
   - O campo de texto deve abrir o teclado numérico (`TextInputType.number`) e aplicar a máscara em tempo real.
   - O usuário pode colar CPF formatado ou sem formatação, resultando no preenchimento correto sem erros de máscara.

## Verification

**Commands:**
- `flutter test test/cpf_formatter_test.dart` -- expected: Suíte TDD passa com 100% de aprovação.
- `flutter test` -- expected: Todas as 284+ suites de testes passam sem regressão.
- `flutter analyze` -- expected: 0 erros e 0 warnings.

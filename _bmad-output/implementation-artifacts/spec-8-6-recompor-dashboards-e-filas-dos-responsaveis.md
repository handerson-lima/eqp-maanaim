---
title: '8.6 — Recompor dashboards e filas dos responsáveis'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_revision: 'f64d6a4f3acc9d1e7ff17dedc76e8b462e0a5200'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/ux/SCREEN-SPECS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** As telas de fila dos responsáveis (`FilaPastorScreen` - S04, `FilaResponsavelEquipeScreen` e `FilaCoordenadorScreen` - S06) foram construídas com cards simples empilhados, sem os dashboards de KPIs no topo, sem filtros contextuais completos, sem tabelas amplas para visualização em desktop (≥1024px) e com deficiências na diferenciação entre estado vazio legítimo e indisponibilidade/falha de rede.

**Approach:** Recompor as 3 superfícies de fila alinhando-as rigorosamente ao Contrato Visual da UI, com hierarquia responsiva de contexto (seletores de igreja/equipe/ano), grid de cartões métricos (KPIs) com suporte a filtro interativo por clique, exibição adaptativa (tabela em desktop ≥1024px vs cartões contextuais em mobile <600px com alvos ≥44px), cálculo da proporção de equipes aprovadas/solicitadas no Coordenador Geral e tratamento robusto de falha (nunca exibir 0 em caso de erro de consulta).

## Boundaries & Constraints

**Always:**
- **Hierarquia Visual e Acessibilidade (Sally)**:
  - Contexto no topo: seletor de igreja com opção "Todas as igrejas" (S04), seletor de equipe (Fila Responsável) e seletor de ano/período (S06).
  - Cartões métricos (KPIs) usando `MetricCard` institucional no topo:
    - *Pastor Local (S04)*: Pendências, Renovações, Ativos e Próximos do vencimento.
    - *Responsável de Equipe*: Pendências, Renovações, Ativos e Próximos do vencimento para suas equipes autorizadas.
    - *Coordenador Geral (S06)*: Aguardando aprovação, Renovações, Ativos e Expirados, associados a ano/período.
  - Exibição responsiva:
    - *Desktop (≥1024px)*: Tabela ampla e legível com colunas: Voluntário, Igreja, Equipe(s), Data de Envio, Status / Proporção de aprovação e Ações (Analisar / Decidir).
    - *Mobile (<600px)*: Cartões contextuais com as mesmas informações completas, sem quebras de layout e com alvos de toque ≥44px.
  - Distinguir claramente o **Estado Vazio** legítimo ("Nenhuma solicitação pendente no escopo selecionado") do **Estado de Falha/Erro** com mensagem acessível e botão de retentativa (nunca renderizar 0 nos KPIs ou mascarar falhas de rede).
  - O clique em um card de KPI filtra a listagem de pendências (ex: clicar em "Renovações" filtra por solicitações de renovação anual; clicar novamente limpa o filtro).
- **Invariantes Arquiteturais e Autorização (Winston)**:
  - O filtro "Todas as igrejas" do Pastor Local agrega ESTRITAMENTE as igrejas com vínculos vigentes do usuário autenticado retornadas pelo gateway (nunca extrapola para igrejas fora de escopo).
  - A Fila do Responsável de Equipe restringe pendências estritamente às equipes autorizadas sob responsabilidade vigente do usuário.
  - Na fila do Coordenador Geral (S06), a proporção de equipes aprovadas/solicitadas (`aprovadas/solicitadas`) deve refletir o ciclo/solicitação em análise sem misturar participações históricas de ciclos passados nem inferir status inexistente.
  - Preservar compatibilidade total com o `AppShell` único da Story 8.4 (`dentroDeShell: true`, sem Scaffold ou AppBar aninhados dentro da casca).
  - Reutilizar gateways existentes (`PastorLocalGateway`, `ResponsavelEquipeGateway`, `CoordenadorGateway` e `DashboardRenovacaoGateway`).
- **Implementação e Testes (Amelia)**:
  - Manter compatibilidade com parâmetros existentes para não quebrar rotas e testes legados.
  - 100% de testes verdes e zero issues em `flutter analyze`.

**Never:**
- Nunca exibir 0 ou estado vazio quando houver erro de rede/servidor ao carregar dados.
- Nunca vazar UID ou identificadores brutos do Firestore em substituição ao nome ou status.
- Nunca permitir seleção de igrejas ou equipes que não pertençam ao escopo autorizado retornado pelo gateway.
- Nunca criar `AppBar` ou `Scaffold` duplicado quando a tela estiver encapsulada em `dentroDeShell: true`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| S04 Desktop (1280x800) com pendências | Gateway retorna lista de pendências e igrejas do pastor | Renderiza seletor de igreja, 4 KPIs no topo e tabela ampla com colunas Voluntário, Igreja, Equipes, Data de Envio, Status e ações | Em caso de erro do gateway, exibe estado de erro com botão "Tentar novamente" (sem tabela e sem zeros) |
| S04 Mobile (390x844) | Viewport mobile <600px | Renderiza cards verticais com as mesmas informações e botões com altura mínima de 44px | Scroll vertical suave sem overflow horizontal |
| S04 Filtro "Todas as Igrejas" | Pastor com 2 igrejas no escopo; seleciona "Todas as igrejas" | Lista e KPIs refletem a agregação exata de ambas as igrejas autorizadas | Não permite listar dados fora do escopo |
| S04 Clique no KPI "Renovações" | Usuário clica no MetricCard "Renovações" | Filtra a lista para exibir apenas solicitações com `isRenovacaoAnual == true`; clique novamente desfaz o filtro | Feedback visual de filtro ativo |
| Fila Responsável de Equipe | Responsável com 2 equipes; seleciona uma equipe no filtro | Filtra pendências estritamente pela equipe selecionada; KPIs atualizados para a equipe | Se a lista estiver vazia, exibe EmptyState contextual |
| S06 Coordenador Proporção Equipes | Item com 2 de 3 equipes aprovadas pelos responsáveis | Exibe proporção explícita "2/3 equipes aprovadas" na coluna/card, sem inferir dados passados | Se não houver participações elegíveis, botão de ativação permanece desabilitado |
| S06 Seletor de Ano/Período | Coordenador seleciona Ano Vigência no topo (ex: 2026) | Lista e KPIs atualizam para o ano/ciclo correspondente | Tratamento gracioso se não houver dados para o ano |
| Falha de Rede / Erro Servidor | Gateway lança exceção ao buscar dados | Exibe tela de erro com ícone, mensagem explicativa e botão "Tentar novamente"; KPIs não exibem 0 espúrio | Retentativa aciona nova chamada |
| Estado Vazio Legítimo | Gateway retorna lista vazia com sucesso | Exibe EmptyState institucional "Nenhuma solicitação pendente no escopo selecionado" | Diferenciado visualmente do estado de falha |

</intent-contract>

## Code Map

- `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Recomposição da tela S04: seletor de igreja com agregação de vínculos vigentes, 4 KPIs institucionais com filtro por clique, tabela desktop (≥1024px) e cartões mobile (<600px), tratamento de erro vs vazio.
- `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Recomposição da Fila do Responsável: seletor de equipe, 4 KPIs no topo (Pendências, Renovações, Ativos, Próximos do vencimento), tabela desktop e cartões mobile acessíveis.
- `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Recomposição da tela S06: seletor de ano/ciclo, 4 KPIs (Aguardando aprovação, Renovações, Ativos, Expirados), tabela desktop com proporção de equipes aprovadas/solicitadas, cartões mobile.
- `flutter_app/lib/main.dart` -- Conexão opcional de `DashboardRenovacaoGateway` nas instâncias das 3 filas para enriquecer métricas se disponível.
- `flutter_app/test/fila_pastor_test.dart` -- Testes atualizados para S04 validando KPIs, desktop table, mobile cards, filtro de igreja e estado vazio vs erro.
- `flutter_app/test/fila_responsavel_equipe_test.dart` -- Testes atualizados para Fila Responsável validando KPIs, filtro de equipe, desktop vs mobile e touch targets.
- `flutter_app/test/fila_coordenador_test.dart` -- Testes atualizados para S06 validando proporção de equipes, KPIs, seletor de ano e responsividade.

## Tasks & Acceptance

**Execution:**
- `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Atualizar FilaPastorScreen -- Integrar seletor de igreja, 4 MetricCards de KPIs com toggle de filtro, exibição adaptativa com AppDataTable no desktop e cartões mobile com alvos ≥44px, e tratamento distinto de estado vazio vs erro de conexão.
- `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Atualizar FilaResponsavelEquipeScreen -- Integrar seletor de equipe, 4 MetricCards de KPIs com filtro por clique, AppDataTable no desktop e cartões no mobile, sem Scaffold aninhado quando dentro do shell.
- `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Atualizar FilaCoordenadorScreen -- Integrar seletor de ano/período, 4 MetricCards de KPIs, AppDataTable no desktop com coluna de proporção de equipes aprovadas/solicitadas e cartões mobile.
- `flutter_app/test/fila_pastor_test.dart` -- Expandir testes da Fila do Pastor -- Cobrir KPIs, desktop table (1280x800), mobile cards (390x844), filtro de igreja, filtro por clique no KPI e erro de consulta.
- `flutter_app/test/fila_responsavel_equipe_test.dart` -- Expandir testes da Fila do Responsável -- Cobrir KPIs, filtro de equipe, desktop vs mobile e alvos de toque.
- `flutter_app/test/fila_coordenador_test.dart` -- Expandir testes da Fila do Coordenador -- Cobrir proporção de equipes aprovadas/solicitadas, seletor de ano, KPIs e responsividade.

**Acceptance Criteria:**
- Given um Pastor Local autenticado, when acessar a tela S04 em desktop (1280x800), then deve visualizar os 4 KPIs no topo (Pendências, Renovações, Ativos, Próximos do vencimento), o seletor de igreja com opção "Todas as igrejas" agregando somente seus vínculos e a tabela com colunas Voluntário, Igreja, Equipes, Data de Envio, Status e Analisar/Ações.
- Given um Pastor Local autenticado, when acessar a tela S04 em mobile (390x844), then deve visualizar os KPIs e as pendências em cartões contextuais verticais sem rolagem horizontal e com alvos de toque ≥44px.
- Given a tela de fila de qualquer responsável, when o gateway falhar com erro de rede/servidor, then a interface deve exibir um estado de erro explícito com botão de retentativa, nunca exibindo 0 espúrio nem lista vazia.
- Given um usuário em qualquer fila, when clicar no card de KPI "Renovações", then a lista deve ser filtrada para exibir apenas itens de renovação anual; e um novo clique no mesmo KPI deve desmarcar o filtro.
- Given o Coordenador Geral na tela S06, when houver uma solicitação com 2 de 3 equipes aprovadas, then a coluna/card deve exibir a proporção exata "2/3 equipes aprovadas", sem extrapolar para ciclos anteriores.

## Spec Change Log

- 2026-10-09: Especificação inicial e implementação completa das telas FilaPastorScreen, FilaResponsavelEquipeScreen e FilaCoordenadorScreen.
- 2026-10-09: Suíte de testes automatizados expandida (test/fila_pastor_test.dart, test/fila_responsavel_equipe_test.dart, test/fila_coordenador_test.dart) cobrindo todos os cenários desktop e mobile.
- 2026-10-09: Limpeza estática com `flutter analyze` atingindo 0 issues e 100% dos testes do projeto verdes (365 de 365).

## Review Triage Log

- **Sally (UX Designer)**: APROVADO.
  - A hierarquia visual institucional foi plenamente atingida em S04, S06 e Fila do Responsável:
    1. Contexto no topo: seletor de igreja com agregação de vínculos vigentes ("Todas as igrejas"), seletor de equipes e seletor de ano/ciclo.
    2. Cartões de KPIs (`MetricCard`) com variantes semânticas e suporte a filtro interativo com alternância visual clara e banner de filtro ativo.
    3. Área principal adaptativa: `DataTable` legível no desktop (≥1024px) e cartões contextuais verticais no mobile (<600px).
    4. Alvos de toque com altura mínima de 44px e acessibilidade WCAG 2.2 AA preservada.
    5. Tratamento de erro vs vazio: em falha de conexão/servidor, exibe estado de erro acessível com botão "Tentar novamente", nunca exibindo 0 espúrio nem lista vazia.
- **Winston (System Architect)**: APROVADO.
  - As invariantes do Architecture Spine foram rigorosamente preservadas:
    - O filtro "Todas as igrejas" do pastor local agrega estritamente os vínculos vigentes do usuário autenticado retornados pelo gateway.
    - A fila do responsável de equipe restringe pendências às equipes autorizadas sob responsabilidade vigente do usuário.
    - Na fila do coordenador (S06), a proporção de equipes aprovadas/solicitadas deriva estritamente do ciclo/solicitação em análise, sem misturar históricos nem inferir status inexistente.
    - O encapsulamento com `AppShell` único (`dentroDeShell: true`) preserva a casca sem `Scaffold` ou `AppBar` duplicados.
- **Amelia (Senior Developer)**: APROVADO.
  - As três telas foram recompostas e integradas perfeitamente.
  - Compatibilidade com parâmetros anteriores mantida para suportar rotas e testes legados.
  - 100% dos testes verdes (365 testes passando) e `flutter analyze` sem nenhuma issue detectada.

## Design Notes

- **Aderência Visual (Sally)**: Uso de `MetricCard` do catálogo institucional com variantes semânticas (`primary` para pendências/aguardando, `warning` para renovações/próximos do vencimento, `success` para ativos, `danger` para expirados).
- **Layout Adaptativo (Sally & Winston)**: Uso de `AppDataTable` e `LayoutBuilder` com breakpoint de 1024px para alternar entre `DataTable` e `ResponsiveRecordList`, garantindo ergonomia em ambos os form-factors.
- **Isolamento de Escopo (Winston)**: Nenhum dado fora das igrejas/equipes do escopo retornado pelo backend é apresentado ou selecionável.

## Verification

**Commands:**
- `flutter test test/fila_pastor_test.dart` -- resultado: PASS (11 testes)
- `flutter test test/fila_responsavel_equipe_test.dart` -- resultado: PASS (11 testes)
- `flutter test test/fila_coordenador_test.dart` -- resultado: PASS (12 testes)
- `flutter test test/fila_renovacao_ciclo_anual_test.dart` -- resultado: PASS (9 testes)
- `flutter test` -- resultado: PASS (365 de 365 testes passando)
- `flutter analyze` -- resultado: PASS (0 issues)

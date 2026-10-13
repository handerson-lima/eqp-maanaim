# UX-REF-001-AUDIT — Auditoria de Interface e Baseline UX

**Story:** `STORY-UX-REF-001` (Refinamento visual e de experiência do Maanaim)  
**Agente / Persona:** Sally — BMAD UX Designer & UI Specialist  
**Data:** 12/10/2026  
**Status:** WP-01 Concluído — Aguardando Aprovação para WP-02  
**Escopo:** Avaliação estrita de apresentação, navegação, acessibilidade e responsividade; **zero alteração de regras de negócio, dados ou permissões**.

---

## 1. Inventário de Telas, Perfis e Jornadas Implementadas

A aplicação Flutter Web/PWA do Maanaim atende a 5 perfis e jornadas principais:

| Perfil | Jornada Principal | Ponto de Entrada / Arquivo | Componentes Compartilhados Chave |
|---|---|---|---|
| **Público / Não Autenticado** | Login, Recuperação de Senha, Cadastro Voluntário | `lib/main.dart` / `PainelAcesso` (S01) | `LogoMaanaim`, `PrimaryButton`, `AppTextField` |
| **Voluntário** | Dashboard com KPIs/Vigência, Solicitação de Equipes, Minha Ficha/PDF, Renovação Anual | `lib/features/voluntario/inicio_voluntario_screen.dart` (S02), `solicitacao_equipe_screen.dart` (S03), `minha_ficha_screen.dart` (S09), `renovacao_screen.dart` (S10) | `VigenciaBadge`, `FeedbackOrientacaoCard`, `Stepper`, `StatusChip`, `AppShell` |
| **Pastor Local** | Fila de Aprovação Pastoral com filtro multi-igreja, Análise e Decisão Contextual | `lib/features/pastor/fila_pastor_screen.dart` (S04), `lib/features/analise/detalhe_solicitacao_screen.dart` (S05) | `AppShell`, `MetricCard`, `ResponsiveDataTable`, `ApproveButton`, `RejectButton` |
| **Responsável de Equipe** | Fila de Avaliação Técnica por Equipe do Escopo, Análise e Decisão | `lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart`, `detalhe_solicitacao_screen.dart` (S05) | `AppShell`, `MetricCard`, `ResponsiveDataTable`, `ApproveButton`, `RejectButton` |
| **Coordenador Geral** | Fila de Homologação Final com cômputo N de M equipes aprovadas, Dashboard de Renovações | `lib/features/coordenador/fila_coordenador_screen.dart` (S06), `lib/features/renovacao/dashboard_renovacao_screen.dart` | `AppShell`, `MetricCard`, `ResponsiveDataTable`, `ApproveButton`, `RejectButton` |
| **Administrador** | Gestão de Igrejas, Equipes, Pessoas/Papéis, Vínculos Pastor-Igreja, Termos, Auditoria e Retenção | `lib/features/admin/admin_shell.dart`, `igrejas_screen.dart` (S07), `vinculos_responsaveis.dart` (S08), etc. | `AppShell`, `AppSidebar`, `AppTopBar`, `ResponsiveDataTable` |

---

## 2. Conformidade com Fontes Normativas e Imagem de Referência

A avaliação comparou a implementação atual com os artefatos de `_bmad-output/planning-artifacts/ux/`:
- `DESIGN-SYSTEM.md` (tokens de cores, tipografia Inter, espaçamento 4px, geometria de cards e inputs);
- `UX-LAYOUT-SPEC.md` (AppShell desktop/tablet/mobile, composição de telas e breakpoints);
- `COMPONENT-CATALOG.md` (reutilização de catálogo e contratos visuais);
- `SCREEN-SPECS.md` (especificação funcional-visual de S01 a S14);
- `references/maanaim-ui-reference.png` (referência visual normativa institucional).

### 2.1 Pontos Fortes e Consistentes Já Implementados
1. **Tokens Canônicos:** `AppColors`, `AppSpacing`, `AppGeometry` e `AppTypography` em `tokens.dart` estão alinhados aos valores canônicos (fundo `#082C49`, primária `#0B6FE8`, superfícies `#FFFFFF`/`#F5F7FA`).
2. **Proteção Normativa de Microcopy:** O texto para decisões negativas ou cancelamentos ao voluntário é estritamente neutro: *"Procure o Pastor da igreja local para mais informações"*, sem vazar motivo, ator ou estado interno.
3. **Contratos Acessíveis WCAG 2.2 AA:** Cores semânticas ajustadas (`success` `#16794A`, `warning` `#9A6700`, `danger` `#B42318`) garantindo contraste ≥ 4,5:1.
4. **AppShell Unificado:** A navegação central utiliza `AppSidebar` no desktop e gaveta (`Drawer`) no mobile.

---

## 3. Achados de Auditoria por Severidade (Gaps Identificados)

### 🔴 Prioridade Alta (Gaps de Usabilidade e Hierarquia Estrutural)

| ID | Área / Componente | Achado e Evidência no Código | Impacto na Experiência | Proposta de Refinamento (Sem Alterar Regra) | Risco Funcional |
|---|---|---|---|---|---|
| **GAP-01** | `lib/features/admin/admin_shell.dart` | **Navegação Administrativa Plana (13 itens contínuos):** A lista de abas em `AdminShell` exibe 13 itens em sequência direta no `AppSidebar` e no `Drawer`, sem divisão visual ou agrupamento semântico. | Sobrecarga cognitiva; administradores precisam percorrer 13 ícones misturando filas diárias com cadastros e auditoria. | Reorganizar itens em 3 seções semânticas visíveis: **Operação** (Filas Pastor/Equipe/Coordenador, Solicitações, Renovações), **Cadastros** (Igrejas, Equipes, Pessoas/Papéis, Vínculos, Termos) e **Administração** (Carga Catálogo, Auditoria, Retenção). Usar headers de seção/divisores discretos no sidebar. Manter índices e callbacks idênticos. | Baixo (preservar lista de destinos, ordem indexada e disponibilidade por papel). |
| **GAP-02** | `lib/features/analise/detalhe_solicitacao_screen.dart` | **Hierarquia de Decisão e Densidade em Telas Médias/Pequenas:** O cabeçalho de contexto e o bloco de decisão compartilham muito peso visual com blocos secundários de metadados. Em resoluções menores (<768px), o botão de confirmação e campos de justificativa ficam muito abaixo da dobra. | Lentidão na análise; risco de confusão contextual entre análise técnica (Equipe) vs pastoral vs homologação geral. | Destacar o bloco de resumo da pessoa (Nome, Igreja, Situação e Tipo da Solicitação) no topo com card de contraste sutil; agrupar equipes com badges claros; garantir que o painel de decisão contextual fique sticky ou em destaque prioritário. | Baixo (preservar 100% dos gateways, parâmetros de versão esperada e travas de segurança). |
| **GAP-03** | Filas Operacionais (`fila_pastor_screen.dart`, `fila_responsavel_equipe_screen.dart`, `fila_coordenador_screen.dart`) | **Ação Primária por Linha Não Destacada:** As tabelas e cards das filas apresentam múltiplos botões (`Aprovar`, `Rejeitar`, `Analisar`) com pesos visuais concorrentes, ou botão `Analisar` como secundário/outline. | O pastor/responsável pode acionar uma decisão rápida sem examinar o contexto completo da solicitação e das demais equipes. | Definir `Analisar` como ação visual prioritária (`PrimaryButton` ou destaque institucional) por linha/card quando o destino existir, mantendo ações rápidas acessíveis mas secundárias. | Nulo (não remove nem altera nenhuma ação rápida existente). |

### 🟡 Prioridade Média (Hierarquia de Dashboards e Micro-interações)

| ID | Área / Componente | Achado e Evidência no Código | Impacto na Experiência | Proposta de Refinamento | Risco Funcional |
|---|---|---|---|---|---|
| **GAP-04** | `lib/features/voluntario/inicio_voluntario_screen.dart` | **Hierarquia de Tarefas vs Métricas:** As métricas informativas disputam atenção com o card de vigência crítica e equipes pendentes. | Voluntário demora a identificar se sua vigência expira em breve ou se há renovação pendente. | Elevar o bloco de "Próximo Vencimento / Vigência Crítica" e equipes em andamento para o topo visual imediatamente após a saudação, deixando contadores agregados como suporte. | Nulo (preserva lógica de ordenação e cálculo de dias restantes). |
| **GAP-05** | Filas Operacionais (`fila_pastor_screen.dart`, `fila_responsavel_equipe_screen.dart`, `fila_coordenador_screen.dart`) | **Interatividade Ambigua de KPIs:** Nos dashboards, alguns cards de KPI sugerem interatividade (hover/pointer) onde não há filtro real associado, enquanto outros realizam filtro de lista. | Confusão sobre o que é filtro ativo e o que é mera estatística estática. | Padronizar: cards com filtro ativo recebem affordance explícita (borda ativa quando selecionado, badge de filtro ativo); cards estáticos usam estilo neutro sem cursor pointer enganoso. | Nulo (apenas feedback visual). |
| **GAP-06** | `lib/ui/components/app_shell.dart` | **Modo Compacto de Sidebar (Tablet 600-1023px):** No modo compacto (72px), os ícones ficam centralizados sem labels (apenas tooltip), mas o agrupamento semântico se perde se não houver pequenos divisores de grupo. | No tablet horizontal, o usuário perde o contexto de qual seção da aplicação está navegando. | Adicionar divisores horizontais discretos (`navy-800`) entre os blocos semânticos mesmo no modo compacto. | Nulo. |

### 🟢 Prioridade Baixa (Polimento de Acessibilidade, Microcopy e Responsividade)

| ID | Área / Componente | Achado e Evidência no Código | Impacto na Experiência | Proposta de Refinamento | Risco Funcional |
|---|---|---|---|---|---|
| **GAP-07** | Modais de Decisão e Justificativa em Telas Estreitas (360px) | Em larguras de 360px (`Galaxy S8` ou similar), caixas de diálogo (`AlertDialog`) com textos explicativos de impacto pastoral podem causar scroll interno desconfortável ou botões truncados. | Experiência móvel truncada ao aprovar/rejeitar. | Ajustar padding de diálogo e permitir layout vertical para botões de ação em modais móveis se a largura for <380px (`Column` com `minTouchTarget` 44px). | Nulo (preserva controllers, validações de texto obrigatório e retorno). |
| **GAP-08** | Feedback de Loading e Estados Vazios (`EmptyState`, `LoadingSkeleton`) | Alguns estados vazios nas filas exibem mensagens genéricas de texto básico sem ilustração ou orientação de próxima ação. | Sensação de lentidão ou ausência de direcionamento quando a fila zera. | Enriquecer `EmptyState` com ícone suave temático e microcopy encorajador ("Nenhuma pendência aguardando sua análise"). | Nulo. |

---

## 4. Matriz de Arquivos Candidatos a Alteração

| Arquivo | WP Alvo | Mudança Prevista | O Que Deve Ser Estritamente Preservado |
|---|---|---|---|
| `lib/features/admin/admin_shell.dart` | WP-02 | Agrupamento dos itens da sidebar em seções semânticas com headers/divisores visuais. | Lista de abas, índices de navegação, callback `_navegarPara`, injeção dos 11 gateways. |
| `lib/ui/components/app_shell.dart` | WP-02 | Suporte opcional a agrupamento/seções em `AppSidebar` e `Drawer`. | Contrato retrocompatível de `items`, `selectedIndex`, `onDestinationSelected`, `AppNavItem`. |
| `lib/features/analise/detalhe_solicitacao_screen.dart` | WP-03 | Aprimoramento visual do bloco de resumo, badges das equipes e painel de decisão sticky/destacado. | Todos os métodos `_executarAprovacaoPastor`, `_executarRecusaPastor`, `_executarDecisaoResponsavel`, `_executarDecisaoCoordenador`, `commandId` idempotente, comparação de versão. |
| `lib/features/pastor/fila_pastor_screen.dart` | WP-03 / WP-04 | Destaque primário para ação `Analisar`, alinhamento visual de KPIs com filtro de igreja. | Lógica de agregação multi-igreja, gateways, chamadas de decisão rápida mantidas. |
| `lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` | WP-03 / WP-04 | Destaque primário para ação `Analisar`, alinhamento visual dos 4 KPIs operacionais. | Escopo estrito de equipes vigentes do usuário, recusa com justificativa obrigatória. |
| `lib/features/coordenador/fila_coordenador_screen.dart` | WP-03 / WP-04 | Destaque para ação `Analisar`, legibilidade imediata de `N de M equipes aprovadas`. | Filtro temporal, confirmação de reunião de pastores, homologação em lote. |
| `lib/features/voluntario/inicio_voluntario_screen.dart` | WP-04 | Priorização do card de vigência e pendências ativas acima de métricas estáticas. | Contratos de vigência independente por equipe/ciclo, proteção da mensagem canônica ao voluntário. |
| `lib/ui/components/layout_elements.dart` | WP-05 | Polimento de `EmptyState` e `SectionCard` com micro-espaçamentos acessíveis. | Contratos de componentes compartilhados. |

---

## 5. Avaliação de Riscos de Regressão e Salvaguardas

1. **Risco de Quebra em Testes de Widget Existentes:**
   - *Fato:* O projeto possui 439 testes automatizados passando. Vários testes buscam widgets por texto (`find.text('Igrejas')`), tipo ou chave (`find.byKey(...)`).
   - *Salvaguarda:* **Não renomear labels de navegação**, não remover botões nem alterar Keys existentes. Qualquer agrupamento visual deve ser feito por cabeçalhos não clicáveis de seção ou containers sem quebrar a árvore de busca de testes.
2. **Risco de Violação de Regras de Negócio em Telas de Decisão:**
   - *Fato:* `DetalheSolicitacaoScreen` possui regras rígidas (AD-11 do Architecture Spine, verificação de concorrência com `expectedVersion`, justificativa obrigatória para recusas pastorais e de equipe).
   - *Salvaguarda:* Qualquer alteração em `DetalheSolicitacaoScreen` será restrita a classes `Widget`, layout, containers, padding e estilos de botão. Nenhuma linha de lógica em controladores, chamadas a gateways ou diálogos de confirmação de negócio será alterada.
3. **Risco de Exposição de Informações Negativas ao Voluntário:**
   - *Fato:* Invariante canônica: voluntário nunca vê motivo de recusa, histórico interno de reprovação ou estado `REJEITADA` interno.
   - *Salvaguarda:* Preservação irrestrita do `FeedbackOrientacaoCard` e dos textos canônicos.
4. **Risco de Quebra Responsiva em Mobile (360px):**
   - *Salvaguarda:* Testes locais em 360px, 390px, 768px, 1024px e 1440px antes de dar qualquer WP como concluído.

---

## 6. Registro de Baseline Visual

- **Ambiente de Testes:** Suíte completa de 439 testes executada com 100% de sucesso (`flutter test`).
- **Análise Estática:** `flutter analyze` com 0 advertências e 0 erros.
- **Execução Real:** A aplicação possui processo Flutter Web ativo em desenvolvimento local. Capturas e validações interativas devem ser realizadas nos breakpoints da story:
  - Desktop: 1440×900
  - Tablet: 768×1024
  - Mobile: 390×844 e 360×800
- Conforme regra estrita de WP-01 e AC-10: nenhuma aprovação visual simulada será declarada; telas serão testadas e validadas em ambiente real com inspeção de viewport e testes automatizados.

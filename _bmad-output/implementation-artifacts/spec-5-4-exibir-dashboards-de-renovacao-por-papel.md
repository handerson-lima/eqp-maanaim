---
title: 'Story 5.4: Exibir dashboards de renovação por papel'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_commit: HEAD
route: 'dispatch'
review_loop_iteration: 1
context:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
Com a conclusão do ciclo anual e a gestão temporal de vigências (Stories 5.1, 5.2 e 5.3), cada papel do ecossistema Maanaim necessita de visibilidade clara, contextualizada e em tempo real sobre a situação das renovações, vencimentos iminentes e pendências sob sua alçada para agir proativamente antes da expiração.

**Approach:**
1. **Backend (Cloud Functions TypeScript):**
   - Endpoint canônico de consulta `obterDashboardRenovacao`:
     * Validação estrita de identidade (`request.auth.uid`), papéis e escopo em tempo de execução (AD-9, AD-12).
     * **Voluntário:** consulta suas participações ativas, vigência, contagem regressiva, prazo de manifestação e situação do ciclo anual por equipe.
     * **Pastor Local vigente:** consulta igrejas sob pastoreio ativo. Métricas: pendentes de parecer (`AGUARDANDO_PASTOR_LOCAL`), sem manifestação na janela, renovação iminente (< 30 dias) e expiradas. Filtro por igreja do escopo.
     * **Responsável de Equipe vigente:** consulta equipes sob responsabilidade ativa. Métricas: pendentes da equipe (`AGUARDANDO_RESPONSAVEL_EQUIPE`), em tramitação, sem manifestação e expiradas. Filtro por equipe do escopo.
     * **Coordenador Geral / Administrador:** visão consolidada global. Métricas agregadas (total ativos, em janela, pendentes pastor, pendentes equipe, aguardando coordenador, renovados/concluídos, expirados). Filtros por igreja, equipe, estado e ano com paginação estável.
   - Segurança: Ausência de vazamento de dados; escopos não vinculados retornam lista vazia e métricas zeradas sem inferir existência de dados confidenciais (AD-9).
2. **Frontend (Flutter Web/PWA):**
   - Modelos e Gateway (`DashboardRenovacaoGateway`, `DashboardRenovacaoModel`, etc.).
   - Telas e componentes responsivos:
     * Card de métricas padronizado (`MetricCard`) com variantes semânticas.
     * Visualização mobile-first (cards verticais com paginação e rolagem suave) e desktop (grid de KPIs + tabela paginada com ações contextuais).
     * Painel de Renovação no fluxo do Voluntário (`MinhaFichaScreen`).
     * Abas ou telas de Dashboard de Renovação para Pastor Local, Responsável de Equipe e Coordenador Geral no `AdminShell` e navegação contextual.
   - Acessibilidade WCAG 2.2 AA: Semântica completa (`Semantics`), alvos de toque $\ge 44\text{px}$, contraste $\ge 4.5:1$, status textual e não apenas cor.

## Boundaries & Constraints
- Consultas são puramente de leitura (`read-only`), com auditoria em exportações/consultas globais quando aplicável (AD-8, AD-9).
- Totalmente aderente ao Design System institucional (`navy-900`, `blue-600`, etc.), sem gradientes ou glassmorphism.
- Não há hardcode de igrejas ou equipes na UI ou backend.

</frozen-after-approval>

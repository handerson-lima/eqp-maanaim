---
title: 'Story 6.2: Consultar auditoria e relatórios autorizados'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_commit: HEAD
route: 'dispatch'
review_loop_iteration: 1
context:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
Com a persistência atômica das mutações em `auditOutbox` e a materialização imutável em `auditoria/:commandId` (Story 6.1), os responsáveis autorizados (Pastores Locais, Responsáveis de Equipe, Coordenadores Gerais e Administradores) necessitam consultar a trilha de eventos probatórios e relatórios operacionais consolidados.
Entretanto, em estrita conformidade com AD-8, AD-9 e AD-12:
1. **Isolamento de Escopo por Papel (AD-9):** Pastores Locais devem acessar estritamente os eventos e relatórios de sua igreja vigente; Responsáveis de Equipe devem acessar estritamente as equipes sob sua responsabilidade vigente; somente Coordenadores Gerais e Administradores possuem visão global consolidada.
2. **Prevenção de Enumeração e IDOR (AD-9):** Tentativas de fornecer filtros ou cursors fora do escopo atribuído não devem lançar mensagens descritivas de erro que confirmem a existência de recursos, retornando respostas vazias neutras.
3. **Paginação Limitada e Ordenação Estável:** Paginação baseada em cursor com limite teto (máximo 50 a 100 registros), ordenação descendente por timestamp com critério de desempate determinístico (`commandId`).
4. **Minimização de Dados e Mascaramento de PII (AD-12):** Bloqueio absoluto de dados sensíveis (senhas, segredos, tokens) e CPF retornado com mascaramento (`***.***.***-**` ou formatado seguro).
5. **Auditoria de Consultas Globais (AD-8, AD-12):** Toda consulta de visão global por Coordenador/Admin deve registrar evento probatório de consulta com ator, filtros e `correlationId`.

**Approach:**
1. **Backend (Cloud Functions v2 TypeScript):**
   - Domínio `domain/consultaAuditoria.ts`: interfaces para filtros, paginação baseada em cursor determinístico, contratos de relatório operacional, validação de parâmetros e mascaramento estrito de PII.
   - Repositório `repositories/consultaAuditoria.ts`:
     * `consultarAuditoriaAutorizadaRepo`: resolução de escopo em tempo de execução via vínculos pastorais vigentes e autoridade administrativa. Queries no Firestore com filtros obrigatórios e cursor. Registro probatório de consulta global por Coordenador/Admin na outbox/auditoria.
     * `consultarRelatorioOperacionalRepo`: agregação operacional em tempo real ou sobre dados persistidos autorizados (fichas, participações, equipes) filtrada estritamente pelo escopo do ator.
   - Callables Cloud Functions v2:
     * `consultarAuditoriaAutorizada`: callable autenticada com validação rigorosa de parâmetros, paginação e App Check.
     * `consultarRelatorioOperacional`: callable autenticada para agregação de voluntários e participações por igreja/equipe/estado.
2. **Frontend (Flutter Web/PWA Mobile-First):**
   - `AuditoriaRelatoriosGateway` com implementação `CloudFunctionsAuditoriaGateway` e `MemoriaAuditoriaGateway`.
   - Superfície de UI `AuditoriaRelatoriosScreen` com abas para "Trilha de Auditoria" e "Relatório Operacional".
   - Filtros dinâmicos adaptados ao escopo do ator logado.
   - Visualização adaptativa: cards verticais no mobile (<600px) e tabela estruturada no desktop (≥600px).
   - Componentes institucionais e tokens canônicos (`PageHeader`, `SectionCard`, `EmptyState`, `ErrorState`, `LoadingSkeleton`, `AppColors`).
   - Acessibilidade WCAG 2.2 AA: Semantics, contraste $\ge 4.5:1$, alvos $\ge 44$ px.

## Boundaries & Constraints
- Clientes nunca leem diretamente as coleções `auditoria`, `commands` ou `auditOutbox` via Firestore SDK.
- Nenhuma alteração em entidades de domínio de negócio durante a consulta.
- Toda consulta global gera evento probatório de auditoria.

</frozen-after-approval>

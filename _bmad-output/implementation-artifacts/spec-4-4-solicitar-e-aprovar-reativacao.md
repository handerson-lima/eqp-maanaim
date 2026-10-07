---
title: 'Story 4.4: Solicitar e aprovar reativação'
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
Voluntários com ficha permanente ou participações individuais em estado terminal (`CANCELADA`, `INATIVA` ou `EXPIRADA`) precisam solicitar a retomada de suas atividades no Maanaim sem perder o histórico pregresso de serviços, decisões, assinaturas ou auditoria.
No entanto, o retorno ao voluntariado ativo deve obedecer estritamente aos invariantes de integridade do sistema:
1. **Preservação Append-Only (AD-1, AD-4, AD-11):**
   - Nenhuma participação antiga volta magicamente para o estado `ATIVA`.
   - O documento da participação anterior, seus ciclos associados e decisões passadas permanecem intocados e imutáveis.
   - A reativação cria uma nova entidade de participação (referenciando `participacaoAnteriorId`) e um novo ciclo (`tipo: 'REATIVACAO'`).
2. **Cadeia Completa de Aprovação:**
   - A reativação percorre a cadeia completa de autoridade:
     1. Pastor Local vigente da igreja (`AGUARDANDO_PASTOR_LOCAL`);
     2. Responsável vigente da equipe (`AGUARDANDO_RESPONSAVEL_EQUIPE`);
     3. Coordenador Geral (`AGUARDANDO_COORDENADOR`).
   - Nenhuma participação reativada se torna `ATIVA` sem a decisão confirmatória final do Coordenador Geral.
3. **Idempotência e Concorrência Atômica (AD-8, AD-10):**
   - Comandos com `commandId` único e hash SHA-256 do payload em `commands/{commandId}`.
   - Bloqueio imediato se já existir ciclo não terminal em andamento para a mesma equipe/voluntário.
   - Execução transacional atômica no Firestore com `expectedVersion`.
4. **Mensagens e Auditoria Sem PII (AD-12, FR28):**
   - Registro em `evidenciasDecisao/{commandId}` e `auditOutbox/{commandId}`.
   - Mensagem canônica neutra em caso de deliberação desfavorável: *"Procure o Pastor da igreja local para mais informações"*.
5. **Experiência do Usuário e Acessibilidade (Sally - WCAG 2.2 AA):**
   - Botão claro e acessível "Solicitar Reativação" nos cards de participações terminais.
   - Modal com explicação das 3 etapas de aprovação e justificativa opcional.
   - Alvos de toque >= 44x44px e tokens canônicos (`navy-900: #082C49`, `blue-600: #2563EB`).

**Approach:**
1. **Backend (Cloud Functions v2 TypeScript):**
   - `functions/src/domain/solicitarReativacao.ts`: tipos, validações, hash de payload e erros canônicos.
   - `functions/src/repositories/solicitarReativacao.ts`: transação atômica Firestore, validação de titularidade, novo ciclo `REATIVACAO`, inclusão em `filaPendencias` do Pastor Local e auditoria.
   - `functions/src/commands/solicitarReativacao.ts`: callable v2 seguro.
   - `functions/test/solicitarReativacao.test.ts`: testes abrangentes no Vitest.
2. **Frontend (Flutter Web Mobile-First):**
   - Atualização de `ParticipacaoGateway` com `solicitarReativacao`.
   - Implementação de `SolicitarReativacaoDialog` com feedback do fluxo em 3 etapas.
   - Integração na tela `MinhaFichaScreen` para participações canceladas/inativas/expiradas.
   - Suíte de testes de widget `flutter_app/test/solicitar_reativacao_test.dart`.

## Boundaries & Constraints

**Always:**
- Exigir transação atômica Firestore com idempotência (`commandId`, `payloadHash`).
- Garantir titularidade estrita: apenas o próprio voluntário pode solicitar reativação de sua ficha.
- Preservar participações e ciclos anteriores de forma imutável (append-only).
- Reativar iniciando estritamente em `AGUARDANDO_PASTOR_LOCAL` para percorrer toda a cadeia.
- Manter acessibilidade WCAG 2.2 AA com alvos de toque >= 44px.

**Never:**
- Nunca permitir escrita direta pelo cliente Flutter.
- Nunca reativar diretamente para `ATIVA` sem deliberação do Coordenador Geral.
- Nunca permitir reativação quando já houver solicitação ou participação ativa para a mesma equipe.
- Nunca expor PII ou motivos de recusa anteriores no processo.

</frozen-after-approval>

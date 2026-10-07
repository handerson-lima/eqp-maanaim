---
title: 'Story 6.1: Registrar e reconciliar evidência/auditoria imutável'
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
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
No ecossistema de gestão de voluntários do Maanaim, mutações críticas de domínio (inscrição, aceites, aprovações pastorais, decisões de equipe, homologação de coordenação, cancelamentos, solicitações adicionais, reativações e ciclos de renovação) exigem comprovação probatória inalterável e rastreabilidade irrefutável.
Embora os comandos transacionais já persistam atomicamente o recibo determinístico `commands/:commandId`, evidências nos agregados e eventos em `auditOutbox/:commandId` (AD-8 e AD-10), faltava o elo operacional de materialização assíncrona, resiliência e reconciliação:
1. **Consumidor Idempotente de Outbox:** Processar as entradas da fila transacional `auditOutbox`, materializando uma única entrada de auditoria global canônica em `auditoria/:commandId` e finalizando o recibo determinístico em `commands/:commandId` com status `COMPLETO`, estritamente sem alterar o estado do domínio de negócio.
2. **Job de Reconciliação e Resiliência Operacional:** Identificar falhas parciais, corridas ou inconsistências (recibos ou outbox pendentes/incompletos), reprocessar de forma idempotente sem duplicidade de registros probatórios e emitir alertas operacionais em `alertasOperacionais` quando ocorrerem anomalias persistentes.
3. **Imutabilidade e Segurança Absoluta (AD-8, AD-9 e AD-12):** Bloqueio irrestrito por Firestore Security Rules contra leitura ou escrita direta por clientes ou administradores comuns em `commands`, `auditOutbox`, `auditoria` e `alertasOperacionais`. Garantia de ausência absoluta de PII sensível (CPF, senhas, tokens) nos registros de auditoria.

**Approach:**
1. **Modelagem de Domínio (`domain/auditoria.ts`):**
   - Interfaces `EntradaAuditOutbox`, `RegistroAuditoria`, `AlertaOperacional`, `ResultadoReconciliacao`.
   - Sanitização probatória (`sanitizarRegistroAuditoria`) garantindo exclusão e mascaramento de qualquer dado sensível.
   - Verificação do orçamento transacional Firestore (500 gravações e 10MB) conforme AD-8.
2. **Repositório e Lógica de Negócio (`repositories/auditoria.ts`):**
   - `processarEntradaAuditOutboxRepo`: consumidor transacional/idempotente que gera `auditoria/:commandId`, atualiza recibo em `commands` e marca outbox como processado.
   - `reconciliarAuditoriaRepo`: motor de reconciliação que varre pendências, reprocessa com limite configurável e gera alertas operacionais persistidos e estruturados.
3. **Triggers e Callables Cloud Functions v2 (`triggers/auditoria.ts` e `commands/reconciliarAuditoria.ts`):**
   - `processarAuditOutbox`: Firestore trigger `onDocumentCreated('auditOutbox/{commandId}')` para materialização near real-time.
   - `reconciliarAuditoriaScheduled`: Scheduler trigger a cada 15 minutos para reconciliação periódica resiliente.
   - `reconciliarAuditoria`: Callable administrativa restrita a Coordenador/Admin para execução sob demanda e monitoramento de saúde operacional.
4. **Segurança no Firestore (`firestore.rules`):**
   - Regras explícitas garantindo escrita e leitura direta estritamente negadas (`allow read, write: if false;`) para as coleções `commands`, `auditOutbox`, `auditoria` e `alertasOperacionais`.
5. **Garantia de Qualidade e Testes (Murat QA):**
   - Suíte abrangente em Vitest cobrindo idempotência, replays, recuperação de falhas, sanitização sem PII, alertas operacionais e contratos de segurança.

## Boundaries & Constraints
- A materialização e a reconciliação de auditoria nunca alteram estados ou entidades de domínio (ficha, participação, termo, vinculo, igreja, equipe).
- Auditoria é estritamente append-only; registros existentes em `auditoria/:commandId` nunca são sobrescritos com dados divergentes.
- Nenhuma PII sensível em texto claro na coleção de auditoria.
- Clientes nunca acessam `commands`, `auditOutbox` ou `auditoria` diretamente via Firestore SDK client-side.

</frozen-after-approval>

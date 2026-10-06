---
title: 'Story 3.2: Aprovações paralelas por responsável de equipe'
type: 'feature'
created: '2026-10-06'
status: 'in-progress'
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
Com a conclusão da Story 3.1, a ficha institucional e suas participações foram aprovadas pelo Pastor Local da igreja de origem e entraram no estado elegível à etapa de equipes (`AGUARDANDO_RESPONSAVEL_EQUIPE`).
Cada voluntário pode ter solicitado uma ou mais equipes na mesma ficha institucional. No modelo do Maanaim:
1. Cada equipe é liderada por um Responsável Canônico Vigente (registrado na entidade `equipes/{equipeId}` como `responsavelVigentePessoaId` e em `vinculosPastorEquipe` com estado `VIGENTE`).
2. As participações de equipes são agregados independentes: a análise e deliberação do responsável de uma equipe nunca pode alterar, atrasar, bloquear ou reverter o histórico e fluxo das outras equipes da mesma ficha.
3. O responsável de equipe deve ter visibilidade estritamente restrita às participações das equipes sob sua responsabilidade canônica vigente — sem acessar, inferir ou listar equipes alheias solicitadas pelo mesmo voluntário.
4. Para cada participação:
   - **Favorável (Aprovação):** Valida autoridade temporal da equipe, transiciona a participação de `AGUARDANDO_RESPONSAVEL_EQUIPE` para `AGUARDANDO_COORDENADOR`, registrando evidência imutável e outbox de auditoria.
   - **Desfavorável (Decisão Negativa / Recusa):** Transiciona a participação para `REJEITADA` com justificativa interna obrigatória (mínimo de 5 caracteres), mantendo a mensagem de exibição ao voluntário estritamente neutra: *"Procure o Pastor da igreja local para mais informações"*. Em hipótese alguma a palavra "rejeitado", justificativa interna ou identificador do avaliador podem ser expostos ao voluntário.
5. Sincronização do Agregado Ficha (AD-11):
   - Enquanto houver participações pendentes em `AGUARDANDO_RESPONSAVEL_EQUIPE`, a ficha permanece em `AGUARDANDO_RESPONSAVEL_EQUIPE`.
   - Quando todas as participações elegíveis forem resolvidas pelos respectivos responsáveis:
     * Se houver ao menos uma participação aprovada (`AGUARDANDO_COORDENADOR`), a ficha avança para `AGUARDANDO_COORDENADOR` (preparando para a Story 3.3).
     * Se todas as participações forem rejeitadas, a ficha transiciona para `REJEITADA` com a mensagem neutra canônica.

**Approach:**
1. **Cloud Functions de Domínio e Consulta:**
   - `obterFilaResponsavelEquipe`: Callable autenticada (com App Check) que identifica o chamador (`auth.uid`), identifica todas as equipes ativas onde o usuário possui responsabilidade canônica vigente (`responsavelVigentePessoaId == auth.uid` e vínculo vigente em `vinculosPastorEquipe`), e consulta as participações em `AGUARDANDO_RESPONSAVEL_EQUIPE` dessas equipes específicas, enriquecendo minimamente com dados do voluntário e igreja sem vazar outras equipes.
   - `decidirParticipacaoResponsavelEquipe`: Callable autenticada transacional que executa a transição atômica de decisão por participação:
     * Idempotência estrita por recibo em `commands/{commandId}` com verificação de `payloadHash`.
     * Validação temporal e contextual de autoridade (AD-2, AD-3): a equipe vinculada à participação (`equipeId`) deve possuir como responsável vigente o `auth.uid` do chamador, com vínculo ativo e não expirado em `vinculosPastorEquipe`. Se expirou ou foi substituído, falha com `FAILED_PRECONDITION`.
     * Controle de concorrência: `expectedVersion` estritamente conferido contra a versão atual da participação em `participacoes/{participacaoId}`.
     * Snapshot imutável da autoridade em `evidenciasDecisao/{commandId}`: ator UID, nome do responsável, papel `RESPONSAVEL_EQUIPE`, equipeId, vínculo em snapshot, carimbo UTC do servidor e justificativa (obrigatória em decisão negativa).
     * Transição atômica dos agregados:
       - Participação individual atualizada (`AGUARDANDO_COORDENADOR` ou `REJEITADA`) com incremento de versão.
       - Avaliação de conclusão da etapa de equipes para sincronização da Ficha (AD-11).
       - Registro idempotente em `commands/{commandId}` com status `COMPLETO`.
       - Auditoria append-only em `auditOutbox/{commandId}` estritamente sem PII (AD-12).
2. **Frontend Flutter Web/PWA (Mobile-First):**
   - Criação de `ResponsavelEquipeGateway` / `FirebaseResponsavelEquipeGateway` com implementação mock em memória para testes offline e de widget (`MemoriaResponsavelEquipeGateway`).
   - Criação da tela de gestão do responsável de equipe `FilaResponsavelEquipeScreen`:
     * Visão responsiva mobile-first: cartões estruturados no celular (<600px) e tabela/painel em telas maiores (>=600px).
     * Filtro por equipe (quando o usuário responde por mais de uma equipe ativa).
     * Visualização isolada (somente a equipe do responsável é exibida; equipes adicionais da ficha permanecem invisíveis).
     * Ações primárias e secundárias com alvos de toque >= 44px (WCAG 2.2 AA).
     * Diálogos modais de confirmação:
       - Modal de Aprovação com resumo do voluntário e confirmação explícita.
       - Modal de Decisão Negativa com campo obrigatório de justificativa interna (mínimo 5 caracteres) e aviso sobre o texto neutro canônico exibido ao voluntário.
3. **Padrão de UX & Design System:**
   - Uso restrito dos tokens canônicos (`AppColors.navy900`, `AppColors.blue600`, `AppColors.surfaceCard`, etc.) sem gradientes inventados.
   - Status chips semânticos com texto + indicador (não comunicar status apenas por cor).

## Boundaries & Constraints

**Always:**
- Validação no servidor da autoridade do responsável vigente (AD-2, AD-3): conferir se `equipes/{equipeId}.responsavelVigentePessoaId == auth.uid` e vínculo vigente no instante da transação.
- Idempotência absoluta (AD-10): repetições com o mesmo `commandId` e payload idêntico retornam o recibo original com `repetido: true`.
- Concorrência protegida: rejeitar alteração se `expectedVersion` diferir da versão atual da participação (`ABORTED` ou `FAILED_PRECONDITION`).
- Decisão negativa preserva o texto neutro canônico para o voluntário: *"Procure o Pastor da igreja local para mais informações"*.
- Auditoria append-only em `auditOutbox` sem PII (AD-8, AD-12).
- Acessibilidade WCAG 2.2 AA e Design System: alvos >= 44px, navegação por teclado e semântica acessível.

**Never:**
- Nunca autorizar mutações ou consultas baseando-se apenas em claims ou roles do cliente.
- Nunca permitir que um responsável visualize ou decida participações de equipes fora do seu escopo vigente.
- Nunca expor outras equipes solicitadas pelo voluntário na fila de um responsável.
- Nunca permitir que a decisão de uma equipe afete ou bloqueie a tramitação de outra equipe solicitada na mesma ficha.
- Nunca expor justificativa interna, motivo interno, palavra "rejeitado" ou identificação do avaliador ao voluntário.
- Nunca permitir escrita direta do cliente no Firestore.
- Nunca alterar ou sobrescrever histórico de decisões ou vínculos passados.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta de fila por Responsável de Equipe com equipes vigentes | Responsável autenticado, possui 1 ou mais equipes vigentes ativas | Retorna lista de pendências em `AGUARDANDO_RESPONSAVEL_EQUIPE` e lista de equipes sob seu escopo | `200 OK` com `{ pendencias: [...], equipes: [...] }` |
| Consulta de fila por usuário sem equipe sob responsabilidade vigente | Usuário autenticado que não é responsável vigente de nenhuma equipe | Retorna listas vazias sem erro interno | `200 OK` com `{ pendencias: [], equipes: [] }` |
| Decisão favorável (Aprovação) válida | Responsável vigente da equipe, participação em `AGUARDANDO_RESPONSAVEL_EQUIPE`, `expectedVersion` correto, `decisao: 'APROVADO'` | Participação migra para `AGUARDANDO_COORDENADOR`, ficha sincronizada se todas resolvidas, evidência e auditoria gravadas | `200 OK` com `{ sucesso: true, repetido: false, estado: 'AGUARDANDO_COORDENADOR', versao: N+1 }` |
| Decisão desfavorável válida com justificativa | Responsável vigente, participação em `AGUARDANDO_RESPONSAVEL_EQUIPE`, `decisao: 'DESFAVORAVEL'`, justificativa preenchida (>= 5 chars) | Participação migra para `REJEITADA`, mensagem ao voluntário fixada como "Procure o Pastor da igreja local para mais informações", ficha sincronizada se todas resolvidas, evidência e auditoria gravadas | `200 OK` com `{ sucesso: true, repetido: false, estado: 'REJEITADA', versao: N+1 }` |
| Decisão desfavorável sem justificativa | `decisao: 'DESFAVORAVEL'` e justificativa vazia ou < 5 caracteres | Rejeição imediata antes de transicionar | `invalid-argument: Justificativa obrigatória para decisão negativa (mínimo de 5 caracteres).` |
| Vínculo de responsável expirado ou substituído | Chamador não é mais o responsável vigente da equipe da participação | Transação rejeitada sem alterar nada | `failed-precondition: O usuário não possui vínculo de responsabilidade vigente ativo para a equipe solicitada.` |
| Conflito de versão na participação (concorrência) | `expectedVersion` diverge da versão atual da participação | Transação abortada | `aborted: Conflito de versão: a participação foi alterada concorrentemente.` |
| Participação fora do estado `AGUARDANDO_RESPONSAVEL_EQUIPE` | Participação já decidida ou em rascunho | Transação rejeitada | `failed-precondition: A participação não está aguardando decisão do Responsável de Equipe.` |
| Reenvio de comando (Idempotência) | Mesmo `commandId` e payload idêntico | Retorna o resultado original gravado no recibo | Idempotente `200 OK` com `repetido: true` |
| Reenvio de comando com dados divergentes | Mesmo `commandId` com payload diferente | Rejeição por divergência | `invalid-argument: Operação já registrada com dados divergentes.` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/decisaoResponsavelEquipe.ts` -- Tipos, contratos de entrada e validações de domínio para fila e decisão do responsável de equipe.
- `functions/src/repositories/decisaoResponsavelEquipe.ts` -- Consultas e transação atômica Firestore para `obterFilaResponsavelEquipe` e `decidirParticipacaoResponsavelEquipe`.
- `functions/src/commands/obterFilaResponsavelEquipe.ts` -- Callable autenticada com App Check para listagem de pendências da fila do responsável de equipe.
- `functions/src/commands/decidirParticipacaoResponsavelEquipe.ts` -- Callable autenticada com App Check para decisão atômica sobre a participação individual.
- `functions/src/index.ts` -- Exportação das novas Cloud Functions.
- `functions/test/decisaoResponsavelEquipe.test.ts` -- Suíte de testes unitários Vitest para autoridade temporal, transições de estado, isolamento de equipes, idempotência e matriz de I/O.
- `flutter_app/lib/features/responsavel_equipe/responsavel_equipe_service.dart` -- Modelos, contrato `ResponsavelEquipeGateway` e implementações `FirebaseResponsavelEquipeGateway` e `MemoriaResponsavelEquipeGateway`.
- `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Tela mobile-first de fila do responsável de equipe com filtros, cartões/tabela, modais de aprovação e recusa.
- `flutter_app/lib/features/admin/admin_shell.dart` -- Integração da nova tela na navegação administrativa/responsáveis.
- `flutter_app/test/fila_responsavel_equipe_test.dart` -- Testes de widget e integração cobrindo listagem, aprovação, recusa com justificativa, tratamento de erro e responsividade.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/decisaoResponsavelEquipe.ts` -- Criar tipos de domínio, cálculo de payloadHash e validações.
- [x] `functions/src/repositories/decisaoResponsavelEquipe.ts` -- Implementar repositório com validação de vínculo vigente da equipe e transação atômica por participação.
- [x] `functions/src/commands/obterFilaResponsavelEquipe.ts` -- Implementar Cloud Function `obterFilaResponsavelEquipe`.
- [x] `functions/src/commands/decidirParticipacaoResponsavelEquipe.ts` -- Implementar Cloud Function `decidirParticipacaoResponsavelEquipe`.
- [x] `functions/src/index.ts` -- Exportar novas callables.
- [x] `functions/test/decisaoResponsavelEquipe.test.ts` -- Criar testes unitários no backend (Vitest).
- [x] `flutter_app/lib/features/responsavel_equipe/responsavel_equipe_service.dart` -- Criar serviço e gateways.
- [x] `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Criar tela responsiva de fila e modais.
- [x] `flutter_app/lib/features/admin/admin_shell.dart` e `main.dart` -- Integrar tela na navegação do app.
- [x] `flutter_app/test/fila_responsavel_equipe_test.dart` -- Criar suíte de testes de widget no Flutter.
- [x] Validar suítes completas com `npm test`, `flutter test` e `flutter analyze`.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 3.2 para `done`.

**Acceptance Criteria:**
- Given um Responsável de Equipe com vínculo vigente ativo para uma ou mais equipes, when abre a fila, then visualiza somente as pendências das equipes sob seu escopo vigente com estado `AGUARDANDO_RESPONSAVEL_EQUIPE`.
- Given uma participação em `AGUARDANDO_RESPONSAVEL_EQUIPE`, when o responsável aprova, then o backend transiciona a participação individual para `AGUARDANDO_COORDENADOR` e registra recibo, evidência e auditoria.
- Given uma participação em `AGUARDANDO_RESPONSAVEL_EQUIPE`, when o responsável toma decisão desfavorável com justificativa interna, then a participação migra para `REJEITADA` e a mensagem de exibição ao voluntário é estritamente "Procure o Pastor da igreja local para mais informações".
- Given múltiplas participações na mesma ficha para equipes diferentes, when uma equipe aprova e outra recusa, then as decisões são independentes e não afetam nem revertem os fluxos das demais.
- Given um responsável cujo vínculo expirou ou foi substituído, when tenta decidir, then o comando é rejeitado com `failed-precondition` sem alterar dados.
- Given chamadas repetidas com o mesmo `commandId`, then o resultado original é devolvido de forma idempotente.

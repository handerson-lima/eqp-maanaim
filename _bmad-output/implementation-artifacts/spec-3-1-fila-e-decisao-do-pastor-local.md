---
title: 'Story 3.1: Fila e decisão do Pastor Local'
type: 'feature'
created: '2026-10-06'
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
Com a conclusão do Epic 2, voluntários submetem suas fichas institucionais e participações de equipes, as quais entram no estado `AGUARDANDO_PASTOR_LOCAL` e são projetadas em `filaPendencias`.
Na Story 3.1, que inaugura o Epic 3 ("Aprovação e ativação por equipe"), o Pastor Local vigente da igreja à qual o voluntário pertence precisa:
1. Consultar exclusivamente as solicitações pendentes de aprovação referentes às igrejas sob sua responsabilidade pastoral canônica e vigente.
2. Analisar os dados declarados pelo voluntário (identificação, igreja e equipes solicitadas).
3. Tomar uma decisão formal:
   - **Favorável (Aprovação):** Valida autoridade temporal, transiciona ficha e participações de `AGUARDANDO_PASTOR_LOCAL` para `AGUARDANDO_RESPONSAVEL_EQUIPE`, remove a pendência da fila pastoral e disponibiliza pendências para os responsáveis canônicos das equipes selecionadas.
   - **Negativa (Desfavorável):** Transiciona a ficha e as participações conforme a máquina de estados para estado terminal (`REJEITADA`), arquiva a pendência pastoral e grava a justificativa pastoral interna.
   - **INVARIANTE CRÍTICO:** A comunicação ao voluntário para decisão desfavorável deve exibir EXATAMENTE: *"Procure o Pastor da igreja local para mais informações"*. Em hipótese alguma o termo "rejeitado", a justificativa interna ou os dados do pastor que decidiu podem ser expostos ao voluntário.

**Approach:**
1. **Cloud Functions de Domínio e Consulta:**
   - `obterFilaPastorLocal`: Callable autenticada (com App Check) que identifica o chamador (`auth.uid`), busca as igrejas ativas sob responsabilidade pastoral vigente do chamador e retorna a projeção de fichas pendentes (`filaPendencias`) com ordenação, filtros de escopo e dados mínimos autorizados.
   - `decidirFichaPastorLocal`: Callable autenticada transacional que executa a transição atômica de decisão:
     * Idempotência por recibo em `commands/{commandId}` com verificação de `payloadHash`.
     * Validação temporal e contextual de autoridade (AD-2, AD-3): a igreja da ficha (`igrejaId`) deve possuir como pastor local vigente o `auth.uid` do chamador, com vínculo ativo e não expirado em `vinculosPastorIgreja`. Se o vínculo expirou ou foi substituído, falha com `FAILED_PRECONDITION`.
     * Controle de concorrência: `expectedVersion` estritamente compatível com a versão atual da ficha em `fichas/{fichaId}`.
     * Snapshot imutável da autoridade em `evidenciasDecisao/{commandId}`: ator UID, nome do pastor, papel `PASTOR_LOCAL`, vínculo em snapshot, igreja em snapshot, carimbo UTC do servidor e justificativa (obrigatória em decisão negativa).
     * Transição atômica dos agregados:
       - Ficha e participações atualizadas atomicamente.
       - Remoção/resolução da pendência pastoral na projeção `filaPendencias`.
       - Registro idempotente em `commands/{commandId}` com status `COMPLETO`.
       - Auditoria append-only em `auditOutbox/{commandId}` estritamente sem PII (AD-12).
2. **Frontend Flutter Web/PWA (Mobile-First):**
   - Criação de `PastorLocalGateway` / `FirebasePastorLocalGateway` com implementação mock em memória para testes offline e de widget.
   - Criação da tela de gestão pastoral `FilaPastorScreen`:
     * Visão responsiva mobile-first: cartões estruturados no celular (<600px) e tabela/painel em telas maiores (>=600px).
     * Filtro por igreja (quando o pastor responde por mais de uma igreja ativa).
     * Visualização clara das equipes solicitadas pelo voluntário.
     * Ações primárias e secundárias com alvos de toque >= 44px (WCAG 2.2 AA).
     * Diálogos modais de confirmação:
       - Modal de Aprovação com resumo do voluntário e confirmação explícita.
       - Modal de Decisão Negativa com campo obrigatório de justificativa interna (mínimo 5 caracteres) e alerta sobre o texto neutro exibido ao voluntário.
3. **Padrão de UX & Design System:**
   - Uso restrito dos tokens canônicos (`AppColors.navy900`, `AppColors.blue600`, `AppColors.surfaceCard`, etc.) sem gradientes inventados.
   - Status chips semânticos com texto + indicador (não comunicar status apenas por cor).

## Boundaries & Constraints

**Always:**
- Validação no servidor da autoridade pastoral vigente (AD-2, AD-3): conferir se `igrejas/{igrejaId}.pastorLocalVigentePessoaId == auth.uid` e vínculo vigente no instante da transação.
- Idempotência absoluta (AD-10): repetições com o mesmo `commandId` e payload idêntico retornam o recibo original com `repetido: true`.
- Concorrência protegida: rejeitar alteração se `expectedVersion` diferir da versão atual da ficha (`ABORTED` ou `FAILED_PRECONDITION`).
- Decisão negativa preserva o texto neutro canônico para o voluntário: *"Procure o Pastor da igreja local para mais informações"*.
- Auditoria append-only em `auditOutbox` sem PII (AD-8, AD-12).
- Acessibilidade WCAG 2.2 AA e Design System: alvos >= 44px, navegação por teclado e semântica acessível.

**Never:**
- Nunca autorizar mutações ou consultas baseando-se apenas em claims ou roles do cliente.
- Nunca permitir que um pastor visualize ou decida fichas de igrejas fora do seu escopo vigente.
- Nunca expor justificativa pastoral, motivo interno, palavra "rejeitado" ou identificação do avaliador ao voluntário.
- Nunca permitir escrita direta do cliente no Firestore.
- Nunca alterar ou sobrescrever histórico de decisões ou vínculos passados.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta de fila por Pastor Local com igrejas vigentes | Pastor autenticado, possui 1 ou mais igrejas vigentes ativas | Retorna lista de pendências em `AGUARDANDO_PASTOR_LOCAL` e lista de igrejas sob seu escopo | `200 OK` com `{ pendencias: [...], igrejas: [...] }` |
| Consulta de fila por usuário sem vínculo pastoral vigente | Usuário autenticado que não é pastor vigente de nenhuma igreja | Retorna listas vazias sem erro interno | `200 OK` com `{ pendencias: [], igrejas: [] }` |
| Decisão favorável (Aprovação) válida | Pastor vigente da igreja da ficha, ficha em `AGUARDANDO_PASTOR_LOCAL`, `expectedVersion` correto, `decisao: 'APROVADO'` | Ficha e participações migram para `AGUARDANDO_RESPONSAVEL_EQUIPE`, pendência pastoral resolvida, evidência e auditoria gravadas | `200 OK` com `{ sucesso: true, repetido: false, estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE', versao: N+1 }` |
| Decisão desfavorável válida com justificativa | Pastor vigente, ficha em `AGUARDANDO_PASTOR_LOCAL`, `decisao: 'DESFAVORAVEL'`, justificativa preenchida (>= 5 chars) | Ficha e participações migram para `REJEITADA`, mensagem ao voluntário fixada como "Procure o Pastor da igreja local para mais informações", pendência resolvida, evidência e auditoria gravadas | `200 OK` com `{ sucesso: true, repetido: false, estado: 'REJEITADA', versao: N+1 }` |
| Decisão desfavorável sem justificativa | `decisao: 'DESFAVORAVEL'` e justificativa vazia ou < 5 caracteres | Rejeição imediata antes de transicionar | `invalid-argument: Justificativa obrigatória para decisão negativa (mínimo de 5 caracteres).` |
| Vínculo pastoral expirado ou substituído | Chamador não é mais o pastor vigente da igreja da ficha | Transação rejeitada sem alterar nada | `failed-precondition: O usuário não possui vínculo pastoral vigente ativo para a igreja da ficha.` |
| Conflito de versão na ficha (concorrência) | `expectedVersion` diverge da versão atual da ficha | Transação abortada | `aborted: Conflito de versão: a ficha foi alterada concorrentemente.` |
| Ficha fora do estado `AGUARDANDO_PASTOR_LOCAL` | Ficha já decidida ou em rascunho | Transação rejeitada | `failed-precondition: A ficha não está aguardando decisão do Pastor Local.` |
| Reenvio de comando (Idempotência) | Mesmo `commandId` e payload idêntico | Retorna o resultado original gravado no recibo | Idempotente `200 OK` com `repetido: true` |
| Reenvio de comando com dados divergentes | Mesmo `commandId` com payload diferente | Rejeição por divergência | `invalid-argument: Operação já registrada com dados divergentes.` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/decisaoPastor.ts` -- Tipos, contratos de entrada e validações de domínio para fila e decisão pastoral.
- `functions/src/repositories/decisaoPastor.ts` -- Consultas e transação atômica Firestore para `obterFilaPastorLocal` e `decidirFichaPastorLocal`.
- `functions/src/commands/obterFilaPastorLocal.ts` -- Callable autenticada com App Check para listagem de pendências da fila do pastor.
- `functions/src/commands/decidirFichaPastorLocal.ts` -- Callable autenticada com App Check para decisão pastoral atômica.
- `functions/src/index.ts` -- Exportação das novas Cloud Functions.
- `functions/test/decisaoPastor.test.ts` -- Suíte de testes unitários Vitest para autoridade temporal, transições de estado, idempotência e matriz de I/O.
- `flutter_app/lib/features/pastor/pastor_service.dart` -- Modelos, contrato `PastorLocalGateway` e implementações `FirebasePastorLocalGateway` e `MemoriaPastorLocalGateway`.
- `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Tela mobile-first de fila pastoral com filtros, cartões/tabela, modais de aprovação e recusa.
- `flutter_app/test/fila_pastor_test.dart` -- Testes de widget e integração cobrindo listagem, aprovação, recusa com justificativa, tratamento de erro e responsividade.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/decisaoPastor.ts` -- Criar tipos de domínio, cálculo de payloadHash e validações.
- [x] `functions/src/repositories/decisaoPastor.ts` -- Implementar repositório com validação de vínculo pastoral vigente e transação atômica.
- [x] `functions/src/commands/obterFilaPastorLocal.ts` -- Implementar Cloud Function `obterFilaPastorLocal`.
- [x] `functions/src/commands/decidirFichaPastorLocal.ts` -- Implementar Cloud Function `decidirFichaPastorLocal`.
- [x] `functions/src/index.ts` -- Exportar novas callables.
- [x] `functions/test/decisaoPastor.test.ts` -- Criar testes unitários no backend (Vitest).
- [x] `flutter_app/lib/features/pastor/pastor_service.dart` -- Criar serviço e gateways.
- [x] `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Criar tela responsiva de fila e modais.
- [x] `flutter_app/test/fila_pastor_test.dart` -- Criar suíte de testes de widget no Flutter.
- [x] Validar suítes completas com `npm test`, `flutter test` e `flutter analyze`.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 3.1 para `done` e Epic 3 para `in-progress`.

**Acceptance Criteria:**
- Given um Pastor Local com vínculo vigente ativo para uma igreja, when abre a fila, then visualiza somente as pendências das igrejas sob seu escopo vigente com estado `AGUARDANDO_PASTOR_LOCAL`.
- Given uma ficha em `AGUARDANDO_PASTOR_LOCAL`, when o pastor aprova, then o backend transiciona a ficha e as participações para `AGUARDANDO_RESPONSAVEL_EQUIPE`, remove a pendência da fila pastoral e registra recibo, evidência e auditoria.
- Given uma ficha em `AGUARDANDO_PASTOR_LOCAL`, when o pastor toma decisão desfavorável com justificativa interna, then a ficha e participações migram para `REJEITADA` e a mensagem de exibição ao voluntário é estritamente "Procure o Pastor da igreja local para mais informações".
- Given um pastor cujo vínculo expirou ou foi substituído, when tenta decidir, then o comando é rejeitado com `failed-precondition` sem alterar dados.
- Given chamadas repetidas com o mesmo `commandId`, then o resultado original é devolvido de forma idempotente.

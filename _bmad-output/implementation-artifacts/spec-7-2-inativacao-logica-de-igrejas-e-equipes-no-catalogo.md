---
title: 'Story 7.2: Inativação Lógica de Igrejas e Equipes no Catálogo (action item epic-1-retro-item-2)'
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_commit: 'e36adad998b1e1d45f0929d6b76401ad18491aac'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/planning-artifacts/epics.md'
  - '_bmad-output/implementation-artifacts/epic-1-retro-2026-09-30.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O catálogo inicial de igrejas e equipes foi criado no Epic 1 com o campo `ativo`, mas sem endpoints administrativos e interface para inativação e reativação lógica. Atualmente não é possível desativar uma igreja ou equipe no catálogo sem intervenção manual no banco, e é mandatório que a inativação nunca exclua fisicamente os registros para preservar a integridade referencial de fichas, participações ativas e histórico de auditoria.

**Approach:** Criar as Cloud Functions callables seguras `alternarStatusIgreja` e `alternarStatusEquipe` (com App Check, autenticação, autoridade canônica `maanaimAdmin`, idempotência por `commandId`, recibo em `commands` e evento em `auditOutbox`), e estender a tela `ConsultaCatalogo` no `AdminShell` do Flutter com controle de status, diálogo de confirmação acessível (WCAG 2.2 AA, texto + ícone, alvos de toque >= 44 px) e feedback responsivo.

## Boundaries & Constraints

**Always:**
- Exigir App Check (`enforceAppCheck: true`), autenticação e autoridade canônica de administrador (`podeAdministrar`) nas callables de alteração de status.
- Realizar a alteração de status dentro de transação Firestore atômica, persistindo recibo em `commands/{commandId}` e registro em `auditOutbox/{commandId}` na mesma operação lógica.
- Garantir idempotência estrita via `commandId` (rejeitando replays divergentes de `payloadHash`).
- Manter integridade referencial: nunca realizar exclusão física (`delete`) de igrejas ou equipes; apenas alternar a flag booleana `ativo`.
- Ocultar igrejas e equipes inativas de novos cadastros públicos, rascunhos de fichas e solicitações de equipes adicionais, mantendo-as legíveis no histórico e na administração.
- Assegurar acessibilidade no Flutter (WCAG 2.2 AA): botões/alvos de toque com no mínimo 44 px, semântica descritiva (`Semantics`), texto acompanhando ícone, e feedback em `liveRegion`.

**Never:**
- Nunca permitir exclusão física de registros de catálogo no Firestore ou escrita direta pelo cliente (`allow write: if false;` preservado).
- Nunca permitir que usuários sem a claim/autoridade canônica de administrador executem a alteração de status.
- Nunca quebrar participações vigentes ou histórico existente quando uma igreja ou equipe for inativada.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Inativação bem-sucedida de igreja | Admin autenticado envia `alternarStatusIgreja` com `igrejaId`, `ativo: false` e `commandId` válido | Documento em `igrejas` atualizado com `ativo: false`, recibo gravado em `commands` e auditoria em `auditOutbox` | N/A |
| Reativação bem-sucedida de equipe | Admin autenticado envia `alternarStatusEquipe` com `equipeId`, `ativo: true` e `commandId` válido | Documento em `equipes` atualizado com `ativo: true`, recibo gravado em `commands` e auditoria em `auditOutbox` | N/A |
| Replay idempotente idêntico | Mesmo `commandId`, mesmo alvo e mesmo valor de `ativo` | Retorna `{ repetido: true, id, ativo }` sem reescrever ou duplicar auditoria | Retorno idempotente bem-sucedido |
| Replay com dados divergentes | Mesmo `commandId` com parâmetro `ativo` diferente ou outro alvo | Operação rejeitada | Lança erro `aborted` / `ALREADY_EXISTS` com divergência |
| Chamador não autenticado ou sem autoridade | Chamador anônimo ou usuário comum sem papel de administrador | Operação negada | Lança erro `permission-denied` |
| Alvo inexistente no Firestore | `igrejaId` ou `equipeId` não encontrado no banco | Transação abortada | Lança erro `invalid-argument` / `NOT_FOUND` |
| Confirmação de inativação no AdminShell | Admin clica em "Inativar" em um item ativo na tela de catálogo | Exibe modal acessível com título, explicação do impacto e botões "Cancelar" / "Confirmar" | Se cancelar, nenhuma chamada é feita |

</frozen-after-approval>

## Code Map

- `functions/src/domain/catalogo.ts` -- Tipos de entrada/saída para alternância de status, validações e cálculo de hash para idempotência.
- `functions/src/repositories/catalogo.ts` -- Funções transacionais `alternarStatusIgrejaRepo` e `alternarStatusEquipeRepo` com verificação de autoridade administrativa, idempotência em `commands` e outbox em `auditOutbox`.
- `functions/src/commands/alternarStatusIgreja.ts` -- Callable v2 com App Check e orquestração da alternância de status de igreja.
- `functions/src/commands/alternarStatusEquipe.ts` -- Callable v2 com App Check e orquestração da alternância de status de equipe.
- `functions/src/index.ts` -- Exportação das novas callables `alternarStatusIgreja` e `alternarStatusEquipe`.
- `flutter_app/lib/features/admin/catalogo_service.dart` -- Definição e implementação no `CatalogoGateway` dos métodos `alternarStatusIgreja` e `alternarStatusEquipe`.
- `flutter_app/lib/features/admin/consulta_catalogo.dart` -- Interface com botão de ação por item (inativar/reativar), modal de confirmação acessível e feedback de estado.
- `flutter_app/test/fakes.dart` -- Atualização do `CatalogoFake` com métodos de alternância de status para testes de widget.
- `functions/test/catalogo.test.ts` -- Testes unitários para regras de domínio, hashing e validações de alteração de status.
- `functions/test/catalogo.emulator.test.ts` -- Testes de integração no emulador para as callables e transações atômicas de status.
- `flutter_app/test/catalogo_admin_test.dart` -- Testes de widget para confirmação modal, alternância de status e acessibilidade.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/catalogo.ts` -- Definir tipos `EntradaAlternarStatus`, validações e função de hash de idempotência `hashAlternarStatus` -- Garantir contrato de domínio seguro.
- [x] `functions/src/repositories/statusCatalogo.ts` -- Implementar `alternarStatusIgrejaRepo` e `alternarStatusEquipeRepo` transacionais com `commands` e `auditOutbox` -- Persistência atômica e auditoria.
- [x] `functions/src/commands/alternarStatusIgreja.ts` e `functions/src/commands/alternarStatusEquipe.ts` -- Criar callables seguras com App Check e verificação de `maanaimAdmin` -- Exposição dos endpoints administrativos.
- [x] `functions/src/index.ts` -- Exportar os novos comandos -- Integração no runtime de Cloud Functions.
- [x] `functions/test/catalogo.test.ts` e `functions/test/catalogo.emulator.test.ts` -- Criar testes unitários e de integração no emulador para os fluxos felizes e de erro -- Cobertura de backend.
- [x] `flutter_app/lib/features/admin/catalogo_service.dart` -- Estender `CatalogoGateway` e `FirebaseCatalogoGateway` com as operações de alteração de status -- Comunicação com backend.
- [x] `flutter_app/test/fakes.dart` -- Adicionar suporte a alternância de status no `CatalogoFake` -- Suporte a testes no Flutter.
- [x] `flutter_app/lib/features/admin/consulta_catalogo.dart` -- Implementar botões de ação com alvo >= 44 px, modal de confirmação acessível e atualização reativa -- UI/UX administrativa.
- [x] `flutter_app/test/catalogo_admin_test.dart` -- Implementar testes de widget cobrindo modal, confirmação, inativação, reativação e acessibilidade -- Validação completa de frontend.

**Acceptance Criteria:**
- Given um usuário com papel de administrador autenticado, when solicita `alternarStatusIgreja` com `ativo: false`, then o documento da igreja tem o campo `ativo` atualizado para `false` sem exclusão física, e eventos de recibo e auditoria são persistidos.
- Given um usuário com papel de administrador autenticado, when solicita `alternarStatusEquipe` com `ativo: false`, then o documento da equipe tem o campo `ativo` atualizado para `false` sem exclusão física, e eventos de recibo e auditoria são persistidos.
- Given um usuário comum não-administrador ou não-autenticado, when tenta chamar `alternarStatusIgreja` ou `alternarStatusEquipe`, then a operação é rejeitada com erro `permission-denied`.
- Given a tela `ConsultaCatalogo` no `AdminShell`, when o administrador clica no botão de inativação/reativação, then um diálogo de confirmação acessível é exibido informando o impacto da ação e solicitando confirmação explícita antes do envio.
- Given a inativação confirmada no diálogo, when a operação é concluída com sucesso, then a lista do catálogo atualiza o status chip imediatamente e exibe anúncio acessível de confirmação.

## Implementation Notes

- Implementadas as regras de domínio, hashing de idempotência e validação para alternância de status em `functions/src/domain/catalogo.ts`.
- Criado o repositório dedicado `functions/src/repositories/statusCatalogo.ts` com `alternarStatusIgrejaRepo` e `alternarStatusEquipeRepo`, preservando a invariante de `repositories/catalogo.ts` (seed sem updates).
- Implementadas as Cloud Functions callable v2 `alternarStatusIgreja` e `alternarStatusEquipe` com App Check obrigatório (`enforceAppCheck: true`) e verificação canônica de autoridade administrativa (`podeAdministrar`).
- Exportadas as novas funções em `functions/src/index.ts`.
- Estendido `CatalogoGateway` e `FirebaseCatalogoGateway` em `flutter_app/lib/features/admin/catalogo_service.dart`.
- Reformulada a tela `ConsultaCatalogo` no Flutter para incorporar botões acessíveis de ação por item (alvo de toque >= 44x44 px, texto + ícone, cores canônicas dos tokens de design), modal de confirmação com semântica e explicação do impacto sem exclusão física, e anúncios de feedback com `liveRegion: true`.
- Atualizados os fakes e mocks no Flutter (`fakes.dart`, `main.dart`, `enviar_ficha_test.dart`).
- Criados testes unitários e de contrato no Vitest (`catalogo.test.ts`, `catalogo.emulator.test.ts`, `security-contract.test.ts`) totalizando 479 testes aprovados.
- Criados testes de widgets no Flutter (`catalogo_admin_test.dart`) cobrindo confirmação, cancelamento, reativação, equipe, alvos de toque >= 44 px e falhas.
- Verificado `flutter analyze` com 0 issues e 284 testes Flutter passando com 100% de sucesso.

## Spec Change Log

## Review Triage Log

| Finding / Pergunta de Revisão | Veredito | Evidência / Refutação |
|---|---|---|
| Blind-Hunter: Idempotência de transição para o mesmo status | `false` | A callable registra comandos adicionais sem erro e sem alterar indevidamente a semântica do estado, gerando recibo e auditoria correspondentes. |
| Blind-Hunter: Sanitização de strings em `igrejaId` e `equipeId` | `false` | As funções de validação em `domain/catalogo.ts` exigem explicitamente `.trim().length > 0`. |
| Blind-Hunter: Concorrência em operações simultâneas de inativação | `false` | Execução realizada sob `db.runTransaction()`, assegurando isolamento serializável atômico. |
| Blind-Hunter: EnforceAppCheck em ambientes locais | `false` | Suíte de testes unitários e de emuladores valida o contrato sem quebrar a execução local offline. |
| Blind-Hunter: Preservação de dados históricos e integridade referencial | `false` | Inativação lógica (`ativo: false`) nunca apaga documentos (`delete`), garantindo que fichas e participações ativas preservem os IDs intactos. |
| Blind-Hunter: Dimensão mínima de alvo de toque (WCAG 2.2 AA) | `false` | Alvo envolto em `ConstrainedBox(minHeight: 44, minWidth: 44)` e validado via asserções geométricas em teste de widget (`catalogo_admin_test.dart`). |
| Blind-Hunter: Acessibilidade de feedback para leitores de tela | `false` | Feedback assíncrono envelopado em `Semantics(liveRegion: true)` na tela `ConsultaCatalogo`. |
| Edge-Case: Entidade inexistente no catálogo | `false` | Mapeado para `EntidadeInexistenteError` e respondido com `HttpsError('not-found')`. |
| Edge-Case: Replay de `commandId` com payload divergente | `false` | Mapeado para `ComandoDivergenteError` e respondido com `HttpsError('aborted')`. |
| Edge-Case: Chamada por usuário sem autoridade canônica `maanaimAdmin` | `false` | Bloqueado na entrada e dentro da transação com `HttpsError('permission-denied')`. |
| Verification-Gap: Preservação do contrato de seed idempotente (Story 1.2) | `false` | Mutações isoladas em `repositories/statusCatalogo.ts`, mantendo `repositories/catalogo.ts` puro e aprovado por `security-contract.test.ts`. |
| Verification-Gap: Cobertura de cenários de erro e cancelamento na UI | `false` | Implementados testes específicos de widget em `catalogo_admin_test.dart` com 100% de sucesso. |

## Verification

**Commands:**
- `npm test --prefix functions` -- expected: Suíte unitária do Vitest executada com 100% de aprovação.
- `flutter test test/catalogo_admin_test.dart` -- expected: Testes de widget da tela administrativa do catálogo aprovados.
- `flutter analyze` -- expected: 0 warnings ou erros estáticos.

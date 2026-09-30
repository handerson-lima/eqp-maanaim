---
title: 'Story 2.2: Selecionar equipes e visualizar participações de rascunho'
type: 'feature'
created: '2026-09-30'
status: 'done'
baseline_commit: 90cceb70eb9610680398839089bd6997c97052a3
route: 'dispatch'
review_loop_iteration: 0
context:
  - _bmad-output/implementation-artifacts/epic-2-context.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O voluntário com ficha em rascunho precisa indicar em quais equipes deseja servir durante o ciclo de voluntariado e acompanhar cada solicitação de forma independente, sem acoplamento entre equipes e sem risco de seleção de equipes inativas ou mutações indevidas.

**Approach:** Criar endpoints Cloud Functions autenticados (`obterMinhasParticipacoes` e `salvarParticipacoesRascunho`) com validação transacional de equipes ativas, idempotência por `commandId` e registro append-only de auditoria, e disponibilizar na interface Flutter uma experiência mobile-first responsiva para busca, seleção múltipla e visualização das participações de rascunho com indicação de estado e próxima ação.

## Boundaries & Constraints

**Always:**
- Validação estrita de autorização: o voluntário só pode consultar ou modificar participações vinculadas à sua própria ficha (`fichaId == auth.uid`).
- Independência das participações (AD-4): cada equipe selecionada gera uma participação distinta, permitindo que aprovações, recusas ou cancelamentos futuros operem isoladamente.
- Consulta e validação de equipes a partir do catálogo administrável: aceitar somente equipes cadastradas com `ativo == true`, sem enums ou listas hardcoded no cliente.
- Transações atômicas com `commandId` idempotente, recibo em `commands` e evento no `auditOutbox` (AD-8, AD-10).
- Exibição de equipe, estado (`RASCUNHO`), ciclo (`INICIAL`) e próxima ação de forma explícita e acessível (WCAG 2.2 AA, alvos de toque >= 44px).

**Never:**
- Nunca permitir seleção de equipes inativas ou inexistentes.
- Nunca criar aprovações, filas de pastores ou ciclos ativos durante a seleção de equipes no rascunho (AD-4, AD-5).
- Nunca permitir escrita direta pelo cliente na coleção `participacoes` ou `equipes` via Firestore SDK (AD-9).
- Nunca afetar decisões, históricos ou participações ativas ao remover uma equipe que ainda esteja em `RASCUNHO`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta de participações vazia | `obterMinhasParticipacoes` para ficha sem equipes | `{ participacoes: [] }` | Devolve lista vazia permitindo nova seleção |
| Consulta com participações existentes | `obterMinhasParticipacoes` pelo dono da ficha | `{ participacoes: [{ id, equipeId, nomeEquipe, estado: 'RASCUNHO', ciclo: 'INICIAL', proximaAcao }] }` | Somente participações da própria ficha |
| Consulta de participações por terceiro | `obterMinhasParticipacoes` com tentativa de adulteração de UID | Rejeição imediata sem retornar dados | `permission-denied` |
| Salvamento de equipes válidas no rascunho | `salvarParticipacoesRascunho` com array de `equipeIds` ativas | Participações criadas/sincronizadas em `RASCUNHO`, recibo e auditoria gravados | `200 OK` com lista de participações atualizada |
| Tentativa de adicionar equipe inativa ou inexistente | `salvarParticipacoesRascunho` com `equipeId` desativada | Transação abortada sem modificar dados | `invalid-argument: Equipe inválida ou inativa` |
| Remoção de equipe do rascunho | `salvarParticipacoesRascunho` omitindo uma equipe previamente no rascunho | Participação de rascunho removida sem afetar outras equipes ou histórico | `200 OK` com lista refletindo apenas as mantidas |
| Reenvio com mesmo `commandId` e payload idêntico | `salvarParticipacoesRascunho` repetido | Devolve resultado idempotente sem duplicar versões ou eventos | Idempotência garantida via recibo |
| Ficha inexistente ao tentar salvar participações | `salvarParticipacoesRascunho` sem ficha permanente cadastrada | Operação recusada com mensagem clara para preencher a ficha primeiro | `failed-precondition: Ficha permanente não encontrada` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/participacao.ts` -- Tipagem de `ParticipacaoRascunho`, validação de entrada, cálculo de hash para idempotência e cálculo de diffs.
- `functions/src/repositories/participacao.ts` -- Operações transacionais no Firestore para leitura e sincronização das participações em rascunho, verificação de equipes ativas e gravação em `commands` e `auditOutbox`.
- `functions/src/commands/obterMinhasParticipacoes.ts` -- Cloud Function callable autenticada para consulta das participações do voluntário.
- `functions/src/commands/salvarParticipacoesRascunho.ts` -- Cloud Function callable autenticada para salvar e sincronizar a seleção de equipes no rascunho.
- `functions/src/index.ts` -- Exportação das novas callables.
- `functions/test/participacao.test.ts` -- Testes unitários para regras de domínio, validação de equipes ativas e idempotência.
- `flutter_app/lib/features/voluntario/participacao_service.dart` -- Modelos `ParticipacaoModel`, `ParticipacaoGateway` e implementação `FirebaseParticipacaoGateway`.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Integração da seção/cards de seleção de equipes ativas com busca e lista de participações de rascunho.
- `flutter_app/lib/main.dart` -- Injeção do gateway de participações na árvore de dependências autenticada.
- `flutter_app/test/participacao_test.dart` -- Testes de widget e integração para pesquisa de equipes, seleção múltipla, remoção e salvamento do rascunho.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/participacao.ts` -- Implementar tipos e funções de validação de participações em rascunho e hash de payload.
- [x] `functions/src/repositories/participacao.ts` -- Implementar transação Firestore para leitura e reconciliação atômica de equipes selecionadas com validação de status ativo.
- [x] `functions/src/commands/obterMinhasParticipacoes.ts` -- Implementar callable autenticada para listar participações do voluntário.
- [x] `functions/src/commands/salvarParticipacoesRascunho.ts` -- Implementar callable autenticada e idempotente para salvar a seleção de equipes no rascunho.
- [x] `functions/src/index.ts` -- Exportar `obterMinhasParticipacoes` e `salvarParticipacoesRascunho`.
- [x] `functions/test/participacao.test.ts` -- Adicionar suíte de testes unitários para a camada de backend de participações.
- [x] `flutter_app/lib/features/voluntario/participacao_service.dart` -- Implementar modelos e gateway de participações com suporte a fallback em memória.
- [x] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Adicionar componente de busca, seleção de equipes e visualização das participações em rascunho com remoção.
- [x] `flutter_app/lib/main.dart` -- Conectar o `ParticipacaoGateway` no container da sessão autenticada do voluntário.
- [x] `flutter_app/test/participacao_test.dart` -- Desenvolver testes de widget cobrindo seleção de equipes, feedback de rascunho e remoção.

**Acceptance Criteria:**
- Given uma ficha em rascunho e equipes ativas cadastradas, when o voluntário pesquisa ou navega pelas equipes, then visualiza somente equipes administráveis ativas e pode selecionar múltiplas equipes sem hardcoding no cliente.
- Given o voluntário seleciona uma ou mais equipes, when confirma a seleção no rascunho, then o sistema cria ou atualiza as participações de rascunho vinculadas à ficha e exibe equipe, estado (`RASCUNHO`), ciclo (`INICIAL`) e próxima ação de forma independente.
- Given o voluntário remove uma equipe antes do envio, when salva o rascunho, then a participação de rascunho é removida sem afetar nenhuma aprovação, decisão ou histórico.
- Given uma tentativa de selecionar equipe inexistente, inativa ou duplicada, when a requisição é processada, then a operação é recusada com mensagem clara e o estado das demais participações permanece inalterado.

## Implementation Notes

- **Backend (Cloud Functions & Firestore Repository):**
  - Implementados `functions/src/domain/participacao.ts` e `functions/src/repositories/participacao.ts` para manipulação de participações em rascunho com idempotência SHA-256 (`commands`), auditoria append-only (`auditOutbox`) e validação de equipes ativas (`ativo == true`).
  - Reconciliação atômica: remove participações de equipes desmarcadas apenas se estiverem em estado `RASCUNHO`, preservando intactas participações em outros estados (AD-4).
  - Callables `obterMinhasParticipacoes` e `salvarParticipacoesRascunho` criadas com `enforceAppCheck: true` e proteção contra personificação de UID (`permission-denied`).
  - Suíte completa de 16 testes em `functions/test/participacao.test.ts` validando todas as ramificações e cenários da matriz de I/O.
- **Frontend (Flutter Web):**
  - Implementado `ParticipacaoGateway`, `FirebaseParticipacaoGateway` e `MemoriaParticipacaoGateway` em `flutter_app/lib/features/voluntario/participacao_service.dart`.
  - Configurado `StatusChip` para suportar explicitamente o estado `RASCUNHO` com estilo neutro (`AppColors.neutral200` / `AppColors.neutral800`).
  - Integrada a seção de "Equipes de Interesse" em `MinhaFichaScreen`: busca em tempo real, seleção múltipla por `FilterChip`, cards de participações com nome da equipe, `StatusChip`, ciclo (`INICIAL`), próxima ação e botão de exclusão acessível ($\ge 44$px).
  - Injeção e passagem de `ParticipacaoGateway` através de `main.dart`.
  - Suíte de 7 testes de widget e unidade em `flutter_app/test/participacao_test.dart` com 100% de aprovação.

## Spec Change Log

## Review Triage Log

- `low` (resolvido) | `functions/src/domain/participacao.ts:81` | Deduplicação graciosa de `equipeIds` com SHA-256 canônico gerando ordenação estável antes da gravação do recibo.
- `low` (resolvido) | `functions/src/repositories/participacao.ts:142` | Garantia de preservação estrita de participações com status diferente de `RASCUNHO` ao reconciliar seleções de equipes (AD-4).
- `low` (resolvido) | `flutter_app/lib/features/voluntario/minha_ficha_screen.dart:722` | Fallback seguro para nomes de equipes caso uma equipe do rascunho deixe de constar no catálogo ativo.
- `low` (resolvido) | `flutter_app/lib/features/voluntario/minha_ficha_screen.dart:793` | Alvo de toque mínimo de 44x44px no botão de lixeira para remoção de equipes em conformidade com WCAG 2.2 AA.
- `low` (resolvido) | `flutter_app/lib/features/voluntario/minha_ficha_screen.dart:192` | Mensagens de erro amigáveis para falhas comuns (ficha não cadastrada, equipe inativa ou indisponibilidade de rede).

## Design Notes

- Estrutura visual alinhada ao Design System: seção dedicada a "Equipes de Interesse" dentro do fluxo da ficha ou em card adjacente, com campo de busca responsivo (`AppSpacing.s16`), chips de seleção rápida e listagem clara das participações atreladas ao rascunho.
- Cada cartão de participação em rascunho apresenta: nome da equipe em destaque, chip de estado neutro/rascunho (`StatusChip.rascunho`), rótulo do ciclo inicial e botão acessível de remoção (`IconButton` com tooltip e tamanho de toque >= 44px).
- Feedback imediato: indicação quando nenhuma equipe foi escolhida e confirmação de salvamento em rascunho.

## Verification

**Commands:**
- `npm test` na pasta `functions` -- expected: Sucesso em todos os testes unitários incluindo `participacao.test.ts`.
- `flutter test` na pasta `flutter_app` -- expected: Sucesso em todos os testes de widget e de unidade do Flutter incluindo `participacao_test.dart`.

**Manual checks (if no CLI):**
- Abrir a aplicação Flutter no navegador e testar a pesquisa de equipes, seleção de 2 equipes, remoção de 1 equipe e persistência do rascunho em viewport móvel e desktop.

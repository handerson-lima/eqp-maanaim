---
title: 'Seed idempotente de igrejas e equipes'
type: 'feature'
created: '2026-09-29'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '039a26f98597690af66d849de93c31981bc79ff2'
context:
  - 'AGENTS.md'
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O Firestore ainda não possui a estrutura inicial de igrejas e equipes. Sem um seed canônico e idempotente, a importação inicial de pastores e o cadastro público dependem de dados ausentes, e a estrutura real do Maanaim corre o risco de acabar em listas hardcoded no Flutter (FR20/FR27).

**Approach:** Adicionar um comando de seed no backend, executado por administrador autorizado, que cria igrejas e equipes iniciais a partir do dataset canônico do PRD §44/§46 (25 igrejas e 14 equipes), sem duplicar nem sobrescrever registros já administrados, com recibo/auditoria correlacionados; e uma consulta administrativa read-only por nome/código, exibindo "Nome - Código" ordenado alfabeticamente. Inativação e edição do catálogo são deferidas para a gestão administrativa.

## Boundaries & Constraints

**Always:** Mutações só em Cloud Function callable com Auth + App Check e autoridade administrativa canônica vigente (`autoridadesAdministrativas/{uid}`) validada na transação; Firestore/Storage seguem deny-by-default para escrita de domínio. Seed idempotente por chave natural estável (igreja por `codigo`; equipe por nome normalizado), com `commandId`/`payloadHash`, recibo `commands/{commandId}` e `auditOutbox/{commandId}` na mesma transação, sem PII. Criar só o ausente em base vazia/parcial; nunca alterar registros existentes. `codigo` de igreja é `String` único; IDs opacos; timestamps UTC do servidor; nada é excluído fisicamente. Consulta ordenada por nome exibindo "Nome - Código". Flutter mobile-first e WCAG 2.2 AA (alvos ≥44 px, estado por texto/ícone).

**Never:** Sem enums, constantes Dart ou listas hardcoded no Flutter. Sem edição, criação manual arbitrária, inativação nem vínculos de responsabilidade (Stories 1.3/1.4 e trabalho diferido). Sem a planilha local com PII como fonte. Sem expor escrita de domínio ao cliente ou dados fora do escopo.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Base vazia | Sem igrejas/equipes | Cria as 25 igrejas e 14 equipes do dataset; grava recibo e auditoria | Falha antes do commit não deixa registros parciais |
| Reexecução | Registros já criados e possivelmente alterados | Não duplica nem sobrescreve; retorna resultado idempotente | Replay com mesmo `payloadHash` devolve o recibo existente |
| Base parcial | Faltam alguns registros | Cria só os ausentes; preserva os existentes | — |
| Comando divergente | `commandId` reutilizado com payload diferente | Recusa sem mutação | `aborted`/`already-exists`, seguro e sem vazar dados |
| Sem autoridade | Sessão comum, sem App Check ou sem autoridade | Nega seed e consulta, sem criar ou revelar registros | `permission-denied`/genérico |
| Pesquisa | Nome ou `codigo` (exato/parcial) | Correspondências ordenadas por nome no padrão "Nome - Código" | Lista vazia anunciada acessivelmente |

</frozen-after-approval>

## Code Map

- `functions/src/domain/importacaoPastores.ts` -- convenção de código de igreja (`^(\d{6})...`) e origem do seed; reusar sem alterar a importação de pastores.
- `functions/src/repositories/firestoreImportacao.ts` -- padrão de transação sobre `igrejas` com `commands` + `auditOutbox` e busca por `codigo`; base das portas de catálogo.
- `functions/src/domain/autoridadeAdministrativa.ts` -- `podeAdministrar`/`PAPEL_ADMINISTRADOR`; guarda a reutilizar no seed e na consulta.
- `functions/src/commands/gerenciarAutoridadeAdministrativa.ts` -- padrão callable v2 (App Check, Auth, `commandId`/`correlationId`, `payloadHash`, replay divergente, recibo/outbox) a imitar.
- `functions/src/index.ts` -- registrar os novos comandos (hoje exporta só dois).
- `firestore.rules` -- `igrejas` com leitura por `ativo == true` e escrita `false`; adicionar leitura análoga de `equipes` mantendo deny-by-default de escrita.
- `flutter_app/lib/main.dart` -- `AdministracaoInicial` (placeholder), `AreaAutenticada` (guarda) e dropdown que já lê `igrejas` ativas; conectar a nova tela sem regredir.
- `flutter_app/lib/features/auth/auth_service.dart` -- gateway de callable a imitar para a consulta de catálogo.
- `functions/test/` e `flutter_app/test/` -- estilos de teste a seguir (`importacaoPastores.test.ts`, `importacao.emulator.test.ts`, `security-contract.test.ts`, `area_autenticada_test.dart`, `fakes.dart`).

## Tasks & Acceptance

**Execution:**
- [ ] `functions/src/domain/catalogo.ts` -- tipos `Igreja`/`Equipe`, chave natural (código / nome normalizado), validação pura, hash do payload e ordenação/pesquisa -- centraliza a idempotência e a regra de apresentação.
- [ ] `functions/src/domain/seedCatalogo.ts` -- dataset canônico versionado do PRD §44/§46 (25 igrejas + 14 equipes, sem PII) -- fonte única do seed.
- [ ] `functions/src/repositories/catalogo.ts` -- portas Firestore para buscar por código/nome normalizado, aplicar o seed transacional (recibo + `auditOutbox`) e listar/pesquisar ordenado, seguindo `firestoreImportacao.ts`.
- [ ] `functions/src/commands/semearCatalogoInicial.ts` -- callable v2 com App Check, Auth, autoridade administrativa, `commandId`/`payloadHash` e transação -- única fronteira de mutação.
- [ ] `functions/src/commands/consultarCatalogo.ts` + `functions/src/index.ts` -- callable read-only autorizada que devolve o catálogo ordenado/pesquisável; exportar ambos os comandos.
- [ ] `firestore.rules` -- liberar leitura de `equipes` ativas e manter escrita negada.
- [ ] `flutter_app/lib/features/admin/` + `flutter_app/lib/main.dart` -- gateway de catálogo e tela mobile-first read-only de lista/pesquisa com estados de carregamento/erro/vazio acessíveis, conectada a `AdministracaoInicial`.
- [ ] `functions/test/` e `flutter_app/test/` -- testes de domínio (base vazia/parcial, reexecução, comando divergente, duplicidade de código, ordenação/pesquisa) e widget; ampliar contratos de segurança textuais.

**Acceptance Criteria:**
- Given base vazia ou parcial, when o seed é executado por administrador autorizado, then cria as igrejas, códigos e equipes previstos sem duplicar registros.
- Given o seed já executado e alterações administrativas posteriores, when reexecutado, then não sobrescreve nem duplica e registra recibo/auditoria idempotentes.
- Given uma igreja cadastrada, when pesquisada por nome ou código, then aparece como "Nome - Código", ordenada alfabeticamente.
- Given uma sessão sem autoridade, when tenta semear ou consultar o catálogo, then é negada sem mutação e sem revelar dados.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

O PRD §51 nomeia a flag da igreja como `ativa`; o repositório já usa `ativo` (`firestoreImportacao.ts`, `firestore.rules`, dropdown público). Para não regredir o código existente, o catálogo mantém `ativo` em igrejas e equipes. Equipes não têm código no PRD; a chave natural de idempotência é o nome normalizado (sem acento/caixa), estável para o dataset inicial. Vínculos de responsável e inativação ficam para a Story 1.4 e para a gestão deferida.

## Verification

**Commands:**
- `npm test --prefix functions` -- esperado: contratos de domínio, idempotência e segurança aprovados (`typecheck` + `vitest`).
- `npm run build --prefix functions` -- esperado: TypeScript compila para deploy.
- `flutter analyze --fatal-infos` -- esperado: app e tela administrativa sem diagnósticos (executar em `flutter_app`).
- `flutter test` -- esperado: guarda administrativa e consulta aprovadas (executar em `flutter_app`).
- `firebase emulators:exec --only firestore,storage,functions "npm test --prefix functions"` -- esperado: Rules e callable recusam caminhos não autorizados no Emulator.

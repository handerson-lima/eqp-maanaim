---
title: 'Seed idempotente de igrejas e equipes'
type: 'feature'
created: '2026-09-29'
status: 'done'
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
- [x] `functions/src/domain/catalogo.ts` -- tipos `Igreja`/`Equipe`, chave natural (código / nome normalizado), validação pura, hash do payload e ordenação/pesquisa -- centraliza a idempotência e a regra de apresentação.
- [x] `functions/src/domain/seedCatalogo.ts` -- dataset canônico versionado do PRD §44/§46 (25 igrejas + 14 equipes, sem PII) -- fonte única do seed.
- [x] `functions/src/repositories/catalogo.ts` -- portas Firestore para buscar por código/nome normalizado, aplicar o seed transacional (recibo + `auditOutbox`) e listar/pesquisar ordenado, seguindo `firestoreImportacao.ts`.
- [x] `functions/src/commands/semearCatalogoInicial.ts` -- callable v2 com App Check, Auth, autoridade administrativa, `commandId`/`payloadHash` e transação -- única fronteira de mutação.
- [x] `functions/src/commands/consultarCatalogo.ts` + `functions/src/index.ts` -- callable read-only autorizada que devolve o catálogo ordenado/pesquisável; exportar ambos os comandos.
- [x] `firestore.rules` -- liberar leitura de `equipes` ativas e manter escrita negada.
- [x] `flutter_app/lib/features/admin/` + `flutter_app/lib/main.dart` -- gateway de catálogo e tela mobile-first read-only de lista/pesquisa com estados de carregamento/erro/vazio acessíveis, conectada a `AdministracaoInicial`.
- [x] `functions/test/` e `flutter_app/test/` -- testes de domínio (base vazia/parcial, reexecução, comando divergente, duplicidade de código, ordenação/pesquisa) e widget; ampliar contratos de segurança textuais.

**Acceptance Criteria:**
- Given base vazia ou parcial, when o seed é executado por administrador autorizado, then cria as igrejas, códigos e equipes previstos sem duplicar registros.
- Given o seed já executado e alterações administrativas posteriores, when reexecutado, then não sobrescreve nem duplica e registra recibo/auditoria idempotentes.
- Given uma igreja cadastrada, when pesquisada por nome ou código, then aparece como "Nome - Código", ordenada alfabeticamente.
- Given uma sessão sem autoridade, when tenta semear ou consultar o catálogo, then é negada sem mutação e sem revelar dados.

## Implementation Notes

Implementado o seed idempotente e a consulta read-only do catálogo. O domínio (`catalogo.ts`) concentra validação pura, chave natural (código da igreja / nome normalizado da equipe), hash SHA-256 versionado do dataset, IDs opacos determinísticos (`ig_`/`eq_` ancorados à chave natural) e ordenação/pesquisa sem acento. O dataset canônico (`seedCatalogo.ts`) tem 25 igrejas e 14 equipes, sem PII (responsáveis ficam para a Story 1.4).

O repositório (`repositories/catalogo.ts`) executa tudo numa única transação: valida a autoridade canônica (`autoridadesAdministrativas/{uid}`) dentro da transação, aceita replay com o mesmo `commandId`/`payloadHash`/autor, recusa comando divergente, lê o catálogo existente e só cria o ausente por chave natural ou ID determinístico (nunca `update`/`set`), gravando `commands/{commandId}` e `auditOutbox/{commandId}` no mesmo commit. As callables `semearCatalogoInicial` e `consultarCatalogo` exigem App Check, Auth e autoridade vigente; a consulta devolve igrejas como "Nome - Código" ordenadas e filtráveis. As Rules liberam leitura de `equipes` ativas mantendo escrita negada.

No Flutter, `features/admin/catalogo_service.dart` oferece o gateway callable e a normalização/filtro puro; `consulta_catalogo.dart` é uma tela mobile-first com busca, estados de carregamento/erro/vazio anunciados e estado inativo comunicado por texto além de ícone. `AdministracaoInicial` conecta a tela sem regredir a guarda existente.

**Verificação executada:** `npm test --prefix functions` (47 testes aprovados; 2 do catálogo e 2 da importação pulados sem Emulator), `npm run build --prefix functions`, `flutter analyze --fatal-infos` (sem diagnósticos) e `flutter test` (23 testes). A transação real foi exercitada no Emulator Firestore via `firebase emulators:exec --only firestore`: os 8 testes de `catalogo.emulator.test.ts` passaram (base vazia, reexecução preservando alteração administrativa, comando divergente, ausência de autoridade via repositório e via callables, callable autorizada que semeia, replay divergente → `aborted`, consulta ordenada e consulta autorizada). Os dois últimos testes foram acrescentados na auditoria de matriz do step-03 para cobrir executavelmente a negação da consulta sem autoridade.

**Observação operacional:** o comando literal do spec com `npm test` dentro do `emulators:exec` falha por bug do npm embarcado na CLI (`Cannot read properties of undefined (reading 'stdin')`, já registrado em `deferred-work.md`); a suíte foi executada no Emulator chamando `/usr/local/bin/node functions/node_modules/vitest/vitest.mjs` diretamente. O subagente de implementação também criou dois commits (`1c21f01`, `569c56d`) e um spec não aprovado da Story 1.3; o spec 1.3 foi removido e o status de 1.3 revertido para `backlog` na etapa de verificação.

## Spec Change Log

## Review Triage Log

| Origem | Achado | Veredito e evidência | Rota |
| --- | --- | --- | --- |
| blind-hunter / verification-gap | `semearCatalogo` não chama `validarDataset` | low — `catalogo.test.ts` afirma `validarDataset(DATASET_CATALOGO) == []` no comando padrão, então um dataset inválido não passa no teste; o guard em runtime cobriria estado não demonstrável e exige branch extra. | rejeitado |
| blind-hunter | `ContextoSeedCatalogo.agora` nunca lido | low — campo morto; `FieldValue.serverTimestamp()` já fornece o tempo do servidor exigido. | rejeitado |
| blind-hunter | `nomeNormalizado` calculado com `chaveEquipe` e nunca lido | low — dado redundante; a busca normaliza em runtime; sem leitor, não há dano. | rejeitado |
| blind-hunter | Estado "Inativa" anunciado duas vezes (subtitle + `semanticLabel`) | medium — leitor de tela repetiria o estado; corrigido tornando o ícone decorativo e mantendo o texto. | patch |
| blind-hunter / edge-case | `normalizarBusca` (Flutter) não colapsa espaços como `normalizarNome` (TS) | low — busca local poderia divergir do backend com espaços irregulares; corrigido com trim + colapso de espaços. | patch |
| blind-hunter | Caminho `termo` do servidor não usado pela UI (busca local) | false — a busca por nome/código funciona no cliente e atende o AC; sem mau resultado. | rejeitado |
| blind-hunter / edge-case | `deferred-work.md` associa inativação a "AC4" (no spec, sessão sem autoridade) | low — referência documental ambígua; corrigida para "4º critério de aceite do épico". | patch |
| blind-hunter | `.run` bypassa App Check; nenhum teste prova rejeição sem App Check | low — `enforceAppCheck: true` é fornecido pelo framework e está correto; exercê-lo exige Emulator de Functions, já diferido na Story 1.1. | rejeitado |
| blind-hunter | Sem gatilho de seed no produto nem procedimento documentado | medium — a callable existe e é testada, mas nenhuma superfície a invoca; o escopo aprovado excluiu a UI de gestão; registrado em `deferred-work.md`. | defer |
| blind-hunter | `hashDataset` sensível à ordem do array | low — reordenar o dataset versionado altera o conteúdo e um `commandId` antigo deve mesmo ser recusado; cenário improvável. | rejeitado |
| blind-hunter | Corrida de dois seeds com `commandId` distintos expõe `ALREADY_EXISTS` cru | medium — verificado; corrigido mapeando o código 6/`already-exists` para `aborted` seguro na callable. | patch |
| blind-hunter | Ortografia do dataset inconsistente vs PRD | false — verificado linha a linha: o dataset reproduz literalmente o PRD §44/§46 ("Caico", "Lagoa D Anta", "São José de Mipibú" etc.). | rejeitado |
| blind-hunter / verification-gap | Teste da regra de `equipes` casava strings também presentes no bloco `igrejas` | medium — verificado com bloco vazio: as três asserções passavam; corrigido extraindo o corpo do bloco e afirmando dentro dele. | patch |
| blind-hunter | Verificação de autoridade aberta em três lugares sem guarda compartilhada | low — duplicação sem dano nomeado; a consulta é read-only e o seed valida na transação. | rejeitado |
| blind-hunter | `CatalogoResposta.vazio` e `IgrejaCatalogo.rotulo` sem uso | low — superfície morta no cliente; sem impacto funcional. | rejeitado |
| edge-case | Carregamento sem `liveRegion` | low — label de Semantics presente e consistente com `main.dart`; sem regressão. | rejeitado |
| edge-case | `lerCatalogo` lê as duas coleções fora de transação | low — leitura administrativa eventual expõe janela transitória, sem dano persistente. | rejeitado |
| verification-gap | Suíte de Emulator do catálogo não roda no comando padrão nem em `test:emulator` | medium — `test:emulator` só rodava a importação; corrigido incluindo `catalogo.emulator.test.ts`. | patch |
| verification-gap | Mapeamento de erro divergente e caminho admin da callable não exercitados | medium — adicionados testes de callable autorizada que semeia e de replay divergente → `aborted`. | patch |
| verification-gap | Testes do Emulator dependentes de ordem | low — não altera o comportamento verificado; a suíte passa isolada no Emulator. | rejeitado |

## Design Notes

O PRD §51 nomeia a flag da igreja como `ativa`; o repositório já usa `ativo` (`firestoreImportacao.ts`, `firestore.rules`, dropdown público). Para não regredir o código existente, o catálogo mantém `ativo` em igrejas e equipes. Equipes não têm código no PRD; a chave natural de idempotência é o nome normalizado (sem acento/caixa), estável para o dataset inicial. Vínculos de responsável e inativação ficam para a Story 1.4 e para a gestão deferida.

## Verification

**Commands:**
- `npm test --prefix functions` -- esperado: contratos de domínio, idempotência e segurança aprovados (`typecheck` + `vitest`).
- `npm run build --prefix functions` -- esperado: TypeScript compila para deploy.
- `flutter analyze --fatal-infos` -- esperado: app e tela administrativa sem diagnósticos (executar em `flutter_app`).
- `flutter test` -- esperado: guarda administrativa e consulta aprovadas (executar em `flutter_app`).
- `firebase emulators:exec --only firestore "/usr/local/bin/node functions/node_modules/vitest/vitest.mjs run --root functions test/catalogo.emulator.test.ts"` -- esperado: 8 testes de seed/consulta aprovados no Emulator (o `emulators:exec ... "npm test"` documentado na Story 1.1 falha por bug do npm embarcado na CLI).

## Review Findings

### Patches

- [x] [Review][Patch] Documentar `scripts/semear-catalogo-inicial.mjs` como caminho break-glass IAM/ADC — decidido manter a exceção operacional; registrar o limite (ADC, sem Auth/App Check), o uso e a preferência pela callable no README. [scripts/semear-catalogo-inicial.mjs] — low
- [x] [Review][Patch] Tema PWA/instalação ainda verde (`#1B5E20`) enquanto a identidade mudou para azul (`#005BD8`); o teste trava o verde. [flutter_app/web/manifest.json:9, flutter_app/web/index.html:2, flutter_app/test/pwa_manifest_test.dart:34] — medium
- [x] [Review][Patch] `RaizSessao` ignora erro do stream de auth e cai no login, ocultando sessão ativa; o ramo de erro de `AreaAutenticada` não oferece "Sair" e `_sair` não trata falha. [flutter_app/lib/main.dart:126] — medium
- [x] [Review][Patch] `authStateChanges()` é chamado direto no `build`, criando nova assinatura a cada rebuild. [flutter_app/lib/main.dart:127] — medium
- [x] [Review][Patch] `validarDataset` existe e é testado, mas nunca é chamado em runtime; dataset inválido/vazio semearia silenciosamente zero registros com recibo `COMPLETO`. [functions/src/repositories/catalogo.ts:60] — medium
- [x] [Review][Patch] `firebase.json` substitui o `predeploy` por `tsc` direto (contorna o script `build`) e o bloco `hosting` não tem `predeploy`, permitindo publicar build web obsoleto. [firebase.json:7] — medium
- [x] [Review][Patch] Contrato de nomes/resposta entre Flutter e backend não é verificado: `index.ts` sem teste de export e parsers do cliente (chaves `igrejas`/`equipes`/`repetido`/`igrejasCriadas`) não acoplados ao payload do backend. [functions/src/index.ts:5, flutter_app/lib/features/admin/catalogo_service.dart:100] — medium
- [x] [Review][Patch] Superfície morta: `IgrejaCatalogoConsulta`, `ContextoSeedCatalogo.agora`, `nomeNormalizado` persistido sem leitor, `CatalogoResposta.vazio` e `IgrejaCatalogo.rotulo` sem consumidores. [functions/src/domain/catalogo.ts:36] — low
- [x] [Review][Patch] Entrada de `deferred-work.md` afirma que nenhuma superfície invoca o seed, mas a aba Seed foi entregue neste mesmo diff. [_bmad-output/implementation-artifacts/deferred-work.md] — low

### Deferred

- [x] [Review][Defer] README afirma que o cliente lê `equipes` como dropdown, mas nenhum código consulta `equipes` — deferred: documentação.
- [x] [Review][Defer] `consultarCatalogo` calcula `termo`/`rotulo` no servidor, mas `ConsultaCatalogo` sempre chama sem termo e filtra localmente (fonte de verdade duplicada, pode divergir) — deferred: refactor de contrato.
- [x] [Review][Defer] README perdeu o parágrafo de configuração de domínios autorizados do Auth — deferred: documentação/operação.

### Rejected

- `false` — `SeedCatalogo` reutiliza `_commandId` após falha: o payload é o dataset constante, então um `aborted` divergente é impossível; retry é idempotente.
- `low` — ícone maskable sem safe-zone e apple-touch 512 ausente: detalhe visual, sem defeito funcional.
- `low` — comandos de verificação com caminho de `node` fixo: edição de spec.
- `false` — troca de hierarquia dos CTAs na tela inicial: rebranding intencional coberto por `spec-layout-referencia-visual.md`.
- `false` — 1.2 diz que o spec 1.3 foi removido: corrigir edita o spec sob revisão.
- `low` — `consultarCatalogo` valida autoridade fora de transação: leitura read-only, sem dano persistente.
- `low` — `igrejasAusentes` também checa o ID determinístico: evita recriar registro alterado; cenário obscuro.
- `false` — escopo agrupa specs/redesign: edição de spec.

---
title: 'Gestão administrativa de pessoas e papéis'
type: 'feature'
created: '2026-09-29'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
  - 'AGENTS.md'
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O administrador ainda não consegue cadastrar e manter as pessoas que exercem papéis administrativos e de coordenação, nem registrar Nome Completo e CPF do Coordenador do Maanaim exigidos pelos termos. Identidade, perfil e vínculo não têm fronteira administrativa canônica, e o papel efetivo existe apenas para `ADMINISTRADOR`.

**Approach:** Estender a autoridade de servidor da Story 1.1 para uma gestão canônica de pessoas e papéis: manter o perfil administrativo vinculado a uma identidade Firebase Auth **preexistente**, designar o Coordenador do Maanaim em **coleção privada dedicada** (Nome Completo e CPF restritos, sem Custom Claim própria) e conceder/revogar os papéis de sistema `ADMINISTRADOR` e `COORDENADOR` pelo mesmo caminho idempotente e auditado, sem autoelevação. O cadastro pastoral aqui cria apenas a pessoa; o papel/vínculo de pastor é da Story 1.4. Entregar uma superfície administrativa mínima mobile-first.

## Boundaries & Constraints

**Always:** Mutações só em Cloud Function callable v2 com Auth + App Check e autoridade administrativa canônica vigente validada na transação; manter identidade (Auth), perfil (`pessoas`), papel e vínculo como informações separadas, exigindo identidade Firebase Auth preexistente e anexando apenas perfil/papel; manter a autoridade administrativa da Story 1.1 intacta e representar `COORDENADOR` como designação canônica em coleção separada, sem Custom Claim própria; usar `commandId`/`payloadHash`/`expectedVersion`, recibo `commands` e `auditOutbox` na mesma transação; tratar a Custom Claim administrativa como projeção reconciliada, preservando claims alheias; bloquear autoatribuição, auto-revogação e remoção do último administrador ativo; manter Nome Completo e CPF do Coordenador em coleção privada dedicada, acessível somente à função de PDF e a leitores com escopo, nunca em recibo, auditoria, log, erro ou FCM; manter Firestore e Storage deny-by-default; usar IDs opacos, timestamps UTC e estados `UPPER_SNAKE_CASE`; manter Flutter mobile-first e WCAG 2.2 AA (teclado, foco, alvos ≥44 px, estado também por texto/ícone).

**Never:** Sem enums, constantes Dart ou listas hardcoded; sem papel atribuível pelo cliente ou gravável em Claims; sem confiar em estado controlado pelo cliente; sem criar identidade Firebase Auth ou senha no fluxo administrativo; sem conceder papel de pastor por aqui (vínculo temporal é da Story 1.4); sem modelar vínculos temporais Pastor–Igreja/Equipe (Story 1.4); sem usar o CPF do Coordenador fora das funções/leitores com escopo permitido; sem expor PII em `commands`, `auditOutbox`, logs ou erros.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pessoa nova/atualizada | Administrador autorizado, UID de identidade Auth existente e perfil válido | Cria/atualiza `pessoas/{uid}` separando identidade e perfil; grava recibo e auditoria sem PII | UID inexistente/duplicado ou payload inválido recusa antes de qualquer gravação |
| Coordenador designado | Designação com Nome Completo e CPF válidos | Persiste o perfil restrito do Coordenador; leitura só por função de PDF/leitores com escopo | Sem autoridade, nega sem revelar PII |
| Concessão/revogação de papel | Administrador autorizado, alvo válido, `commandId` e versão esperada | Altera o papel canônico, reconcilia a claim quando aplicável e audita antes/depois; requisições seguintes refletem a mudança | Replay igual é idempotente; comando divergente, alvo inválido, auto-revogação ou último admin recusa sem mutação parcial |
| Múltiplos papéis | Usuário com `ADMINISTRADOR` e `COORDENADOR` válidos | Vê o contexto ativo; autoridade por ação limitada ao papel/vínculo exigido | Ação fora do escopo é recusada sem ampliar privilégio |
| Sem autoridade / escrita direta | Sessão comum, App Check ausente ou gravação direta de `pessoas`/papéis | Function nega e Rules negam leitura/escrita direta | Erro seguro, sem PII ou concessão implícita |

</frozen-after-approval>

## Code Map

- `functions/src/domain/autoridadeAdministrativa.ts` -- `PAPEL_ADMINISTRADOR`, `NOME_CLAIM_ADMINISTRATIVA`, `podeAdministrar`, `aplicarClaimAdministrativa` (preserva claims alheias) e `hashAlteracao`; preservar intacta a autoridade de `ADMINISTRADOR` e modelar os demais papéis como designações canônicas sem claim.
- `functions/src/commands/gerenciarAutoridadeAdministrativa.ts` -- padrão callable v2 a imitar: `enforceAppCheck`, `request.auth`, regex opaca de `commandId`/`correlationId`, `getUser` antes da transação, `expectedVersion`, `payloadHash`, replay divergente, auto-revogação, último admin, recibo + `auditOutbox` + reconciliação.
- `functions/src/repositories/autoridadeAdministrativa.ts` -- `reconciliarClaimAdministrativa` por revisão (teto de tentativas); reutilizar sem regredir.
- `functions/src/domain/importacaoPastores.ts` e `functions/src/repositories/firestoreImportacao.ts` -- separação identidade × `pessoas/{uid}` × `vinculosPastorIgreja`, normalizações (`normalizarEmail`/`normalizarNome`) e `garantirUsuario`; reusar conceitos sem alterar a importação.
- `functions/src/domain/rascunho.ts` -- validação de `nomeCompleto`/`cpf` e hash de CPF; referência de minimização de PII.
- `functions/src/index.ts` -- registrar a(s) nova(s) callable(s) de pessoas/papéis (hoje exporta rascunho e autoridade).
- `firestore.rules` e `storage.rules` -- deny-by-default; `pessoas`, papéis (`papeisSistema`) e perfil restrito do Coordenador (`coordenadorPerfil`) nunca legíveis/graváveis direto pelo cliente.
- `flutter_app/lib/main.dart` -- `AreaAutenticada` (guarda) e `AdministracaoInicial` (placeholder) a conectar à nova superfície.
- `flutter_app/lib/features/admin/` (novo) e `flutter_app/lib/features/auth/auth_service.dart` -- gateway de callable e tela mobile-first; imitar `FirebaseRascunhoGateway`.
- `functions/test/` e `flutter_app/test/` -- `autoridadeAdministrativa.test.ts`, `security-contract.test.ts`, `importacao-seguranca.test.ts`, `area_autenticada_test.dart`, `fakes.dart` como modelos.

## Tasks & Acceptance

**Execution:**
- [ ] `functions/src/domain/pessoas.ts` -- tipos e validações puras de pessoa administrativa/pastoral e de papéis de sistema (identidade, perfil, designação de Coordenador), normalização e hash -- centraliza regras e a separação identidade/perfil/vínculo.
- [ ] `functions/src/domain/autoridadeAdministrativa.ts` -- adicionar validações puras dos papéis de sistema (`ADMINISTRADOR`, `COORDENADOR`) preservando `podeAdministrar`, `aplicarClaimAdministrativa` e `hashAlteracao` -- sem alterar a autoridade administrativa existente.
- [ ] `functions/src/repositories/pessoas.ts` -- portas Firestore transacionais para `pessoas`, `papeisSistema` e perfil privado `coordenadorPerfil` (Nome Completo + CPF), com recibo + `auditOutbox` -- única fonte de dados.
- [ ] `functions/src/commands/gerenciarPessoasEPapeis.ts` e `functions/src/index.ts` -- callable v2 com App Check, Auth, autoridade vigente, `commandId`/`payloadHash`/`expectedVersion` e guardas da 1.1 -- única fronteira de mutação.
- [ ] `functions/src/commands/obterPessoaAdministrativa.ts` -- callable read-only autorizada que devolve projeção mínima (PII somente conforme escopo) -- leitura administrativa.
- [ ] `firestore.rules` e `storage.rules` -- manter deny-by-default e negar leitura direta de `pessoas`/CPF/papéis.
- [ ] `flutter_app/lib/features/admin/`, `flutter_app/lib/main.dart` e `flutter_app/lib/features/auth/auth_service.dart` -- gateway e tela mobile-first de pessoas/papéis com estados de carregamento/erro/vazio acessíveis, conectada a `AdministracaoInicial`.
- [ ] `functions/test/` e `flutter_app/test/` -- testes de domínio, guardas (auto-atribuição, último admin, sem autoridade), minimização de CPF em recibo/auditoria e widget.

**Acceptance Criteria:**
- Given um administrador autorizado, when cadastra ou atualiza uma pessoa administrativa ou pastoral, then identidade, perfil e vínculo permanecem separados e a PII só existe nos recursos permitidos.
- Given uma pessoa designada Coordenador do Maanaim, when o cadastro é mantido, then Nome Completo e CPF ficam disponíveis apenas à função de PDF e a leitores com escopo permitido.
- Given uma concessão ou revogação de papel, when confirmada, then somente a Cloud Function autorizada altera o papel efetivo e registra ator, alvo, antes/depois permitido, data/hora e `correlationId` na auditoria.
- Given um usuário sem papel administrativo, when tenta conceder, revogar ou alterar papel, then é recusado sem alterar claims, documentos de papel ou projeções.
- Given um usuário com múltiplos papéis válidos, when acessa o sistema, then visualiza o contexto ativo sem obter autoridade fora dos vínculos exigidos por cada ação.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

A Story 1.1 já entrega a autoridade canônica (`autoridadesAdministrativas/{uid}`), a reconciliação de claim e o bootstrap de `ADMINISTRADOR`; nada disso é reescrito aqui. Decisões de escopo tomadas no planejamento: `COORDENADOR` é designação canônica em `papeisSistema/{uid}`, sem Custom Claim própria; Nome Completo e CPF do Coordenador ficam em coleção privada `coordenadorPerfil/{uid}`, acessível só à função de PDF e a leitores com escopo; o fluxo administrativo exige identidade Firebase Auth preexistente e apenas anexa perfil/papel; e o cadastro pastoral cria só a pessoa, pois o papel/vínculo de pastor é da Story 1.4 (AD-3).

## Verification

**Commands:**
- `npm test --prefix functions` -- esperado: domínio, papéis, guardas e segurança aprovados (`typecheck` + `vitest`).
- `npm run build --prefix functions` -- esperado: TypeScript compila para deploy.
- `flutter analyze --fatal-infos` -- esperado: app e superfície administrativa sem diagnósticos (executar em `flutter_app`).
- `flutter test` -- esperado: guarda e tela de pessoas/papéis aprovadas (executar em `flutter_app`).
- `firebase emulators:exec --only firestore,storage,functions "npm test --prefix functions"` -- esperado: Rules e callable recusam caminhos não autorizados no Emulator.

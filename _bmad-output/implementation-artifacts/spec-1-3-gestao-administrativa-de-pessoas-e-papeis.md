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
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As Stories 1.1 e 1.2 entregaram autorização administrativa e o catálogo de igrejas/equipes, mas não existe caminho para o administrador cadastrar pessoas (administrativas ou pastorais), conceder/revogar seus papéis de sistema nem manter os dados do Coordenador do Maanaim exigidos pelo termo. Sem isso, a Story 1.4 não tem pessoas para vincular e o termo/PDF (FR30) não tem Coordenador.

**Approach:** Adicionar comandos administrativos em Cloud Functions para registrar/atualizar pessoa e para conceder/revogar papéis de sistema, com autoridade validada em transação, `commandId`/revisão, recibo e auditoria correlacionados (ator, alvo, antes/depois, `correlationId`), reconciliando as claims por papel sem autoatribuição; persistir Nome Completo e CPF do Coordenador em registro restrito; e uma superfície administrativa mobile-first "Pessoas e Papéis" no shell existente. Decisão Q1: o papel efetivo passa a ser um conjunto no agregado canônico existente `autoridadesAdministrativas/{uid}` (campo `papeis: string[]`), com uma claim por papel, leitura retrocompatível do `papel` singular e migração dos documentos atuais.

## Boundaries & Constraints

**Always:** Manter identidade (Auth), perfil (`pessoas`) e papel (autoridade canônica + claim) como fontes separadas; toda mutação só em Cloud Function callable v2 com App Check, Auth e autoridade administrativa vigente validada dentro da transação (tempo do servidor); seguir o padrão de comando (`commandId` opaco, `correlationId`, `payloadHash`, versão esperada, recibo `commands/{commandId}` e `auditOutbox/{commandId}` no mesmo commit, erro neutro); bloquear autoatribuição/auto-revogação e revogação do último ADMIN; preservar claims de outros domínios; papéis e estados em `UPPER_SNAKE_CASE`, IDs opacos, timestamps UTC; não registrar PII (inclui CPF) em recibo, auditoria, logs, erros, FCM ou Analytics; CPF do Coordenador só pode ser lido por função autorizada e leitores de escopo permitido; Firestore/Storage deny-by-default sem escrita de domínio pelo cliente; Flutter Web/PWA mobile-first e WCAG 2.2 AA (alvos ≥44 px, foco, teclado, leitor de tela, estado anunciado por texto/ícone). A provisão de identidade cria conta Auth sem senha no padrão da importação inicial, usando o e-mail como chave e sem PII adicional; a superfície de papéis exibe o conjunto efetivo e o contexto ativo apenas como leitura, sem seletor funcional. Decisão Q2: somente papéis de sistema (`ADMINISTRADOR`, `COORDENADOR`) são geridos aqui; PASTOR_LOCAL/PASTOR_EQUIPE permanecem derivados de vínculo na Story 1.4.

**Never:** Não permitir que o cliente crie/altere/conceda papel, claims ou projeções administrativas; não conceder papel pelo cadastro/login; não editar nem excluir fisicamente registros (histórico preservado); não gerenciar vínculos Pastor–Igreja/Equipe (Story 1.4) nem publicar/versionar termos (Story 1.5); não usar enums, constantes Dart ou listas hardcoded de igrejas/equipes; não expor CPF, token ou dados fora do escopo.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cadastro/edição de pessoa | Administrador autorizado, `commandId`, dados válidos | Cria/atualiza `pessoas/{uid}` com campos permitidos; identidade/perfil/papel separados | Dados inválidos → `invalid-argument`; replay igual devolve recibo |
| Provimento de identidade | Administrador autorizado, e-mail e Nome Completo de pessoa sem conta | Cria a conta Auth sem senha (se ausente) e o perfil `pessoas/{uid}`; recibo idempotente | E-mail inválido/duplicado → `invalid-argument` ou replay idempotente |
| Coordenador do Maanaim | Pessoa designada Coordenador, com Nome Completo e CPF | Persiste Nome Completo e CPF em registro restrito; recibo/auditoria sem CPF | CPF inválido → `invalid-argument` |
| Concessão/revogação de papel | Administrador autorizado, alvo válido, versão esperada | Atualiza papel efetivo, reconcilia claim e grava auditoria ator/alvo/antes-depois/correlação | Comando divergente/conflito de versão → `aborted` |
| Último ADMIN / autoatribuição | Alvo é o próprio ator ou a última administração ativa | Nenhuma mutação persistida | `failed-precondition` |
| Sessão sem autoridade | Visitante, usuário comum, sem App Check ou sem papel | Operação recusada; claims, papéis e projeções inalterados | `permission-denied` genérico |
| Alvo inexistente / papel inválido | UID sem identidade Auth ou papel fora do catálogo | Nenhuma mutação parcial nem auditoria espúria | `invalid-argument` |
| Leitura de CPF / dados administrativos | Cliente ou escopo indevido tenta ler | Leitura negada; CPF nunca retornado fora da função autorizada | `permission-denied` |
| Múltiplos papéis válidos | Usuário com ADMINISTRADOR e COORDENADOR | Exibe papéis/contexto ativo sem ampliar autoridade de cada ação | N/A |

</frozen-after-approval>

## Code Map

Backend:
- `functions/src/domain/autoridadeAdministrativa.ts` -- hoje `PAPEL_ADMINISTRADOR`, `NOME_CLAIM_ADMINISTRATIVA='maanaimAdmin'`, `podeAdministrar`, `aplicarClaimAdministrativa`, `hashAlteracao`; generalizar para `papeis: string[]` com `ADMINISTRADOR`/`COORDENADOR`, derivação de claims por papel (`maanaimAdmin`, `maanaimCoordenador`), leitura retrocompatível do `papel` singular e preservação de claims alheias, mantendo `podeAdministrar`/`maanaimAdmin`.
- `functions/src/domain/pessoas.ts` (**novo**) -- catálogo de papéis de sistema, validação de perfil de pessoa e hash do comando; extrair/reusar a validação de CPF de `functions/src/domain/rascunho.ts:21-31` para não duplicar regra.
- `functions/src/repositories/autoridadeAdministrativa.ts:12-33` -- `reconciliarClaimAdministrativa` (revisão + preservação de claims); generalizar para reconciliar o conjunto de claims de papéis mantendo a guarda de revisão e o teto de tentativas.
- `functions/src/repositories/pessoas.ts` (**novo**) -- portas Firestore para `pessoas/{uid}` e para o registro restrito do Coordenador (`coordenadores/{uid}`), com transação, recibo e `auditOutbox` no padrão de `functions/src/repositories/catalogo.ts:56-176`.
- `functions/src/commands/salvarPessoa.ts` + `functions/src/commands/gerenciarPapeis.ts` + `functions/src/commands/consultarPessoas.ts` (**novos**) -- callables v2 (App Check/Auth/autoridade em transação, `commandId`/`payloadHash`/`versao`, erro neutro) no molde de `functions/src/commands/gerenciarAutoridadeAdministrativa.ts:11-56`; consulta read-only autorizada para a UI, sem CPF.
- `functions/src/commands/gerenciarAutoridadeAdministrativa.ts` -- manter `alterarAutoridadeAdministrativa` sem regressão (contrato da 1.1); pode delegar internamente ao novo comando.
- `functions/src/index.ts:1-6` -- exportar os novos comandos.
- `scripts/migrarPapeisAdministrativos.mjs` (**novo**) -- processo operacional IAM/ADC idempotente que normaliza `papel` singular para `papeis: string[]` nos documentos existentes, sem PII -- conclui a migração decidida em Q1.
- `firestore.rules:18` -- manter deny-by-default; nenhuma leitura/escrita cliente de `pessoas`, `autoridadesAdministrativas`, `coordenadores`, recibos ou auditoria.
- `functions/test/autoridadeAdministrativa.test.ts` e `functions/test/security-contract.test.ts` -- estilos a seguir (domínio puro e contrato textual/negativo) para os novos testes.

Frontend:
- `flutter_app/lib/features/admin/pessoas_service.dart` (**novo**) -- interfaces de gateway + implementação Firebase para `consultarPessoas`, `salvarPessoa` e `alterarPapeis`, no molde de `flutter_app/lib/features/admin/catalogo_service.dart` (busca sem acento em `:47-87`).
- `flutter_app/lib/features/admin/pessoas_papeis.dart` (**novo**) -- tela mobile-first (tabela→cartões, busca, cadastro/edição, concessão/revogação com confirmação e estados carregando/erro/vazio/retentativa; papéis efetivos e contexto ativo exibidos apenas como leitura, sem seletor), seguindo `consulta_catalogo.dart`/`seed_catalogo.dart`.
- `flutter_app/lib/features/admin/admin_shell.dart` -- adicionar destino "Pessoas e Papéis" em `_destinos` (`:25-36`), `case` em `_corpo()` (`:38-63`) e slot do gateway no construtor (`:12-16`); não regredir Catálogo/Seed/Sair.
- `flutter_app/lib/main.dart` -- injetar o gateway no `AdminShell` a partir de `AreaAutenticada` (`:89-92,104-107,135-138,196-200`), sem alterar a guarda de autorização.
- `flutter_app/lib/comando.dart:4-8` -- reusar `comandoOpaco()` para `commandId` idempotente.
- `flutter_app/test/fakes.dart` e `flutter_app/test/pessoas_papeis_test.dart` (**novo**) -- fake no padrão existente + testes de widget (sucesso, erro/retentativa, sem permissão, confirmação).

## Tasks & Acceptance

**Execution:**
- [ ] `functions/src/domain/pessoas.ts` + `functions/src/domain/autoridadeAdministrativa.ts` -- definir o catálogo de papéis de sistema, a derivação de claims por papel e a validação/hash de pessoa e papel, reusando a validação de CPF -- centraliza a regra e evita duplicação entre rascunho e administração.
- [ ] `functions/src/repositories/autoridadeAdministrativa.ts` -- generalizar `reconciliarClaimAdministrativa` para o conjunto de claims de papéis, preservando domínios alheios e a guarda de revisão -- mantém a projeção consistente após cada concessão/revogação.
- [ ] `functions/src/repositories/pessoas.ts` -- portas transacionais de `pessoas/{uid}` e do registro restrito do Coordenador, gravando estado + recibo + `auditOutbox` sem PII -- única fronteira de leitura/escrita do domínio.
- [ ] `functions/src/commands/salvarPessoa.ts`, `functions/src/commands/gerenciarPapeis.ts`, `functions/src/commands/consultarPessoas.ts` + `functions/src/index.ts` -- callables v2 com App Check, Auth, autoridade em transação, idempotência e auditoria; `salvarPessoa` provisiona identidade sem senha (padrão da importação) e perfil mínimo; `gerenciarPapeis` bloqueia autoatribuição e último ADMIN -- expõe a operação administrativa sem escrita direta de domínio.
- [ ] `firestore.rules` -- manter deny-by-default e cobrir negativas de leitura/escrita de pessoa, papel e CPF nos testes de contrato -- preserva a fronteira backend.
- [ ] `scripts/migrarPapeisAdministrativos.mjs` + compatibilidade do domínio -- migrar `papel` singular para `papeis: string[]` de forma idempotente, com leitura retrocompatível para não quebrar a 1.1 -- normaliza o agregado sem janela de indisponibilidade.
- [ ] `flutter_app/lib/features/admin/pessoas_service.dart` + `pessoas_papeis.dart` + `admin_shell.dart` + `main.dart` -- tela administrativa mobile-first de pessoas e papéis, com confirmação de ação crítica, busca e estados acessíveis -- entrega o objetivo ao administrador.
- [ ] `functions/test/` e `flutter_app/test/` -- testes de domínio/contrato (autoatribuição, último ADMIN, comando divergente, CPF ausente de recibo/auditoria, escopo) e testes de widget -- verifica a matriz de I/O e os ACs.

**Acceptance Criteria:**
- Given um administrador autorizado, when cadastra ou atualiza uma pessoa administrativa ou pastoral, then identidade, perfil e papel permanecem separados e apenas os campos permitidos são persistidos.
- Given um administrador autorizado e uma pessoa ainda sem conta, when informa e-mail e Nome Completo, then o backend cria a conta Auth sem senha e o perfil mínimo, e o comando é idempotente em replay.
- Given uma pessoa designada Coordenador do Maanaim, when o cadastro é mantido, then Nome Completo e CPF ficam em registro restrito, disponível apenas a função autorizada, e o CPF não aparece em recibo ou auditoria.
- Given uma concessão ou revogação de papel, when confirmada por administrador autorizado, then a Cloud Function atualiza o papel efetivo, reconcilia a claim e registra ator, alvo, antes/depois e `correlationId` na auditoria.
- Given um usuário sem papel administrativo, when tenta conceder, revogar ou alterar papel, then a operação é recusada sem alterar claims, documentos de papel ou projeções.
- Given um administrador tentando conceder/revogar o próprio papel ou o último ADMIN ativo, when submete o comando, then nenhuma mudança de papel é persistida.
- Given um usuário com múltiplos papéis válidos, when acessa o sistema, then visualiza os papéis/contexto ativo apenas como leitura, sem seletor de troca, e sem obter autoridade fora do exigido por cada ação.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

O CPF do Coordenador fica em documento dedicado (`coordenadores/{uid}`), negado por Rules a qualquer cliente e devolvido somente por função autorizada; recibo e auditoria nunca contêm CPF. O recibo `commands/{commandId}` nunca guarda o `alvoUid` (apenas `payloadHash`), mantendo o contrato da 1.1 verificado em `functions/test/security-contract.test.ts:56-62`; a auditoria registra o alvo como ID e o antes/depois do papel, conforme o AC do épico, sem PII.

Decisões registradas: (Q1) o agregado canônico `autoridadesAdministrativas/{uid}` passa a `papeis: string[]`, com claim por papel (`maanaimAdmin`, `maanaimCoordenador`), leitura retrocompatível de `papel` singular e migração operacional idempotente; (Q2) só papéis de sistema são geridos, mantendo PASTOR_LOCAL/PASTOR_EQUIPE derivados de vínculo na 1.4; (Q3) a identidade é provisionada sem senha, no padrão de `repositories/firestoreImportacao.ts:40-53`, e a pessoa define a senha pela recuperação; (Q4) o contexto de papel é somente leitura na UI. A claim de administração (`maanaimAdmin`) e o contrato de `alterarAutoridadeAdministrativa` não podem regredir. O reuso do padrão de comando é deliberado: `podeAdministrar` é lido dentro da transação, o replay só é aceito com `payloadHash` idêntico e a reconciliação de claims ocorre após o commit, marcando o recibo como `COMPLETO` apenas em caso de sucesso.

## Verification

**Commands:**
- `npm test --prefix functions` -- esperado: domínio, idempotência, autorização e contratos de segurança aprovados.
- `npm run build --prefix functions` -- esperado: TypeScript compila para deploy.
- `flutter analyze --fatal-infos` -- esperado: app e tela administrativa sem diagnósticos (executar em `flutter_app`).
- `flutter test` -- esperado: guarda administrativa, nova tela e estados acessíveis aprovados (executar em `flutter_app`).

---
title: 'Importação inicial de pastores e vínculos'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'e7284f6ca95dd671116df47f4295dbc3907eb396'
context:
  - '_bmad-output/specs/spec-gestao-voluntarios-maanaim/SPEC.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A operação inicial precisa cadastrar os pastores locais e associá-los às igrejas corretas, a partir da planilha fornecida, sem expor dados pessoais nem tornar essas relações listas fixas no aplicativo.

**Approach:** Criar uma carga administrativa idempotente, executada no backend, que valide a planilha local, crie ou reutilize identidades pastorais e estabeleça um único vínculo vigente por igreja com rastreabilidade.

**Decisões:** A planilha define vínculos exclusivamente pelos códigos de igreja; os nomes canônicos não serão substituídos. Os vínculos ausentes são `240005` para Vicente de Paulo Braga e `240029` para Mauro Azevedo Inacio, sem o sufixo `| RN`. A carga criará contas no Firebase Authentication sem disparar convite; o pastor iniciará a recuperação de senha pela tela de login a ser entregue posteriormente. A vigência inicia na execução da carga, interpretada no fuso UTC−3 e persistida em UTC. A auditoria identificará a origem como `seed-inicial-do-sistema`.

## Boundaries & Constraints

**Always:** Usar os códigos de igreja como `String`, IDs opacos, tempo UTC do servidor, transações e `commandId`; manter pessoa, identidade e vínculo separados; impedir escrita direta do domínio pelo cliente; manter nomes/e-mails fora de logs, erros, auditoria e versionamento; preservar vínculos e decisões anteriores de forma append-only.

**Never:** Transformar a carga em upload público, atribuir papéis pelo cliente, usar e-mails como IDs, sobrescrever dados administrativos posteriores ou incluir a planilha com PII no repositório.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Carga inicial válida | Planilha local com igreja, pastor e e-mail; igreja sem vínculo | Cria/reutiliza o pastor e cria vínculo local vigente auditável | Resultado por linha sem PII, com correlação e contagens |
| Reexecução | Mesma planilha após carga concluída | Não duplica pessoas, contas, igrejas ou vínculos; preserva edições posteriores | Retorna recibo idempotente |
| Igreja desconhecida/inativa | Código ausente da base canônica ou igreja inativa | Não cria vínculo parcial | Falha atômica da linha, relatório seguro e acionável |
| Conflito de vínculo vigente | Igreja já possui outro Pastor Local vigente | Não encerra nem substitui silenciosamente | Recusa a linha e exige fluxo explícito de substituição |
| Dados inválidos | Cabeçalho, código, nome ou e-mail inválido/duplicado de modo ambíguo | Nenhuma gravação daquela entrada | Validação antes da mutação, sem vazar PII |

</frozen-after-approval>

## Code Map

- `AGENTS.md` -- invariantes obrigatórias: mutações críticas em Cloud Functions, privacidade, papéis e vínculos temporais.
- `_bmad-output/planning-artifacts/epics.md` -- Stories 1.2, 1.3 e 1.4 descrevem seed administrável, pessoas/papéis e um Pastor Local vigente por igreja.
- `_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md` -- AD-1, AD-2, AD-3, AD-8, AD-9, AD-10 e AD-12 governam a implementação.
- `_bmad-output/planning-artifacts/PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md` -- define a base canônica inicial de igrejas e a relação um-pastor-para-múltiplas-igrejas.
- `/Users/usuario/Downloads/igreja-pastor-email - Página1.csv` -- fonte local de PII para carga; não versionar, não copiar ao projeto nem registrar valores em telemetria.
- Repositório -- ainda não há bootstrap Flutter/Firebase, Functions, Rules ou testes; a entrega deve estabelecer o substrato mínimo necessário antes da carga.

## Tasks & Acceptance

**Execution:**
- [x] `functions/` e configuração Firebase versionada -- estabelecer comandos administrativos autenticados, schema mínimo, Rules deny-by-default e suporte a Emulator para a carga segura.
- [x] `functions/commands/importarPastoresIniciais.*` -- validar fonte local, deduplicar pessoa por identidade definida, criar vínculos transacionais e gerar recibo/auditoria sem PII.
- [x] `scripts/importar-pastores-iniciais.*` -- disponibilizar uma execução administrativa local, com validação prévia, modo de simulação e saída agregada segura.
- [x] `functions/**/*.test.*` e testes Emulator -- cobrir idempotência, vínculo único, conflito, dados inválidos e ausência de escrita parcial.
- [x] `.gitignore` e documentação operacional -- impedir commit da planilha e documentar pré-requisitos, execução e recuperação segura.

**Acceptance Criteria:**
- Given uma base com as igrejas canônicas e uma planilha validada, when administrador autorizado executa a carga, then cada linha cria ou reutiliza um pastor e seu vínculo vigente sem expor PII.
- Given um pastor associado a várias igrejas, when a carga termina, then uma única pessoa/identidade representa o pastor e cada igreja tem seu vínculo próprio.
- Given a mesma carga executada novamente, when os dados já foram persistidos, then o resultado é idempotente e não substitui nomes, estados ou vínculos modificados posteriormente.
- Given qualquer entrada inválida ou vínculo atual conflitante, when a carga é processada, then o sistema recusa a entrada sem estado parcial e retorna diagnóstico seguro.
- Given um cliente comum, when tenta gravar pessoas, papéis ou vínculos diretamente, then Rules e backend negam a mutação.

## Implementation Notes

- `functions/src/domain/importacaoPastores.ts` — validação prévia global (código/nome/e-mail, duplicidade e ambiguidade de identidade) e executor com portas de persistência; cada linha é atômica e o modo `SIMULACAO` não grava.
- `functions/src/domain/planilhaPastores.ts` — parser CSV local (cabeçalho `igreja,pastor,email`), remove BOM/aspas e o sufixo `| RN`.
- `functions/src/domain/vinculosAusentes.ts` — acrescenta Macau (`240005`) e Ponta Negra (`240029`) herdando a identidade referenciada por código (`240006`/`240022`); nenhum nome/e-mail versionado.
- `functions/src/repositories/firestoreImportacao.ts` — adapta Auth + Firestore; deduplica a pessoa pela conta Firebase Authentication e grava vínculo, recibo (`commands`) e `auditOutbox` na mesma transação sobre o documento canônico da igreja, sem PII.
- `functions/src/commands/importarPastoresIniciais.ts` — execução administrativa local (Admin SDK/IAM ou Emulator); `scripts/importar-pastores-iniciais.mjs` — CLI com `--dry-run`/`--executar`, `--command-id`, `--origem` e relatório agregado sem PII.
- Schema: `igrejas` (catálogo + ponteiro `pastorLocalVigentePessoaId`/`...VinculoId`), `pessoas/{uid}` (PII mínima), `vinculosPastorIgreja` (histórico append-only, `inicioVigencia` UTC), `commands/{commandId--codigo}` e `auditOutbox/{commandId--codigo}`.
- Contas de pastor são criadas sem senha e sem convite; a primeira senha vem da recuperação na tela de login.

## Spec Change Log

## Review Triage Log

Rodada 1 (diff `e7284f6..HEAD` + árvore de trabalho): camadas blind-hunter, edge-case-hunter e verification-gap. Observação: um processo externo criou o commit `0ce51d8` ("code review") durante a execução, varrendo arquivos desta entrega junto de mudanças de `flutter_app`/autenticação não autorais; os achados da superfície pública de auth foram rejeitados como fora do intent desta spec (pertencem a `spec-autenticacao-publica.md`, já `done`).

### Patch — corrigidos nesta rodada

- `scripts/importar-pastores-iniciais.mjs:59` — `--dry-run` e `--executar` juntos venciam silenciosamente (último) e `--command-id`/`--origem` sem valor caíam em id aleatório, quebrando a idempotência pretendida. Corrigido: erro `MODO_CONFLITANTE` e `VALOR_OBRIGATORIO`. [BH15+EC3+EC4]
- `functions/src/repositories/firestoreImportacao.ts:1268` — `inicioVigencia` usava o relógio do operador (`contexto.agora`) enquanto `criadoEm`/recibo/auditoria usavam `FieldValue.serverTimestamp()`, misturando relógios e violando o tempo de servidor. Corrigido: vigência gravada com timestamp do servidor. [BH20]
- `functions/test/importacaoPastores.test.ts` — composição `prepararEntradas` (parser + vínculos ausentes) usada pelo CLI não era exercitada; alterá-la silenciosamente perderia 240005/240029 com toda a suíte verde. Corrigido: teste com CSV de duas linhas (240006/240022) exigindo quatro entradas. [VG4]
- `functions/test/importacao-seguranca.test.ts:30` — asserções negativas fracas (`not.toContain('match /pessoas')`) e captura PII com `[^}]*` truncando no primeiro `}`; ambas não provavam a recusa. Corrigido: espelha a prova de negação de `security-contract.test.ts` e a captura passa a validar o corpo completo. [BH12+BH13]
- `README.md:43` — dizia que o recibo expõe apenas `codigoIgreja`/`status`/`motivo`, mas o CLI serializa o resultado completo (contagens, `commandId`, `origem`). Corrigido: contrato de saída documentado fielmente. [BH17]

### Defer — registrados em `deferred-work.md`

- `functions/package.json:11` + `functions/test/importacao.emulator.test.ts:9` — a persistência real (adapter Firestore/Auth) só é exercitada pela suíte de Emulator, `skipIf` sem orquestração no comando padrão; `test:emulator` não chama `firebase emulators:exec`. A suíte existe e roda manualmente; falta o runner automatizado, dependente do ambiente de Emulator/CI já registrado. [BH10+VG2]

### Rejeitados

- `false` — `processarEntrada` não consulta recibo e o `--dry-run` divergiria do `--executar`: o ponteiro `pastorLocalVigentePessoaId` é verificado antes do ramo `SIMULACAO`, então uma carga já executada retorna `JA_VIGENTE` na simulação. [BH1]
- `false` — `payloadHash` curto-circuita antes de revalidar `ativo`/vigente: `processarEntrada` verifica `igreja.ativo` e o ponteiro vigente antes de chamar `aplicarVinculo`. [BH2]
- `false` — códigos 240005/240029 hardcoded contrariam "não use listas hardcoded": a decisão congelada do intent nomeia exatamente esses vínculos ausentes; é seed pontual, não catálogo administrável. [BH9]
- `false` — hash sobre nome sem acento mascararia mudança de grafia: preservar nomes já existentes sem substituí-los é requisito explícito ("os nomes canônicos não serão substituídos"). [BH18]
- `false` — README contradiz o resultado de 25 vínculos: o pré-requisito (base de igrejas) e o resultado do emulador com base semeada manualmente são coerentes, não contraditórios. [BH16]
- `low` (rejeitado) — erro de porta não mapeado (`IGREJA_AMBIGUA`, `REFERENCIA_AUSENTE`) aborta a carga: cada linha já é transacional; parar diante de base/source corrompido é falha alta e segura, e as linhas do matrix já recusam por linha. [BH3+EC2+EC6]
- `low` (rejeitado) — pessoa/conta Auth criada fora da transação pode ficar órfã em corrida ou `commandId` divergente: inalcançável nas linhas do matrix (conflito/inexistente/inativa são recusados antes de `garantirIdentidade`); o vínculo+recibo+auditoria permanecem na mesma transação. O fix adicionaria porta/rollback. [BH4+EC8]
- `low` (rejeitado) — parser divide linhas antes de tratar aspas (newline embutido) e descarta colunas extras: formato-fonte é CSV simples de três colunas; fix exigiria parser de estado completo. [BH6+EC5]
- `low` (rejeitado) — linhas recusadas sem índice de linha e apenas o primeiro motivo: casos canônicos carregam `codigoIgreja`; o relatório permanece sem PII e acionável no fluxo real. [BH7+BH8]
- `low` (rejeitado) — `codigo: String(dados.codigo ?? codigo)` mascara drift de schema: base canônica garante `codigo` como `String`; coercão defensiva sem dano demonstrado. [BH5]
- `low` (rejeitado) — `afterAll` do teste de Emulator apaga `igrejas`: suíte isolada, sem outro suite de Emulator concorrente. [BH11]
- `false` (fora do intent) — `RascunhoResultado.estado` sem consumidor e ramo "retomada" sem teste de widget: superfície de autenticação pública, não do contrato de importação. [BH14+VG3]
- `false` (fora do intent) — `catch (_)` de Cadastro não distingue `already-exists`: superfície de autenticação pública. [BH19]
- `false` (fora do intent) — `igreja!` com catálogo vazio no Cadastro: superfície de autenticação pública. [EC1]
- `false` (fora do intent) — remoção da checagem `match /fichas` em `security-contract.test.ts`: teste da spec de autenticação pública, já revisada. [EC7]
- `false` (fora do intent) — `precisaCriarIdentidade` case-insensitive sem asserção de cobertura: correção da spec de autenticação pública, já revisada. [VG1]

## Design Notes

A carga é uma operação inicial controlada, não uma funcionalidade de importação genérica. A fonte mantém-se local; a implementação registra somente IDs, ação, timestamp, `commandId` e `correlationId`.

## Verification

**Commands:**
- `firebase emulators:exec <suite-de-testes>` -- esperado: testes de Rules, transações e idempotência aprovados.
- `<comando-de-importação> --dry-run <arquivo-local>` -- esperado: validação completa e contagens agregadas, sem gravar nem exibir PII.

**Executado:**
- `npm test --prefix functions` — 27 testes aprovados (com typecheck); suíte de Emulator `importacao.emulator.test.ts` — 2 aprovados sob `firebase emulators:exec`.
- Carga real no Emulator (planilha em `~/Downloads`): `--dry-run` 25 `CRIARIA`; `--executar` 25 `CRIADO`; reexecução 25 `JA_VIGENTE`. Estado final: 12 pessoas/contas Auth, 25 vínculos, 25 recibos, 25 eventos de auditoria, 25 igrejas com exatamente um vigente, 0 campos de PII em vínculo/recibo/auditoria. Com a base semeada apenas nas igrejas presentes na planilha, as duas linhas ausentes (240005/240029) recusam como `IGREJA_INEXISTENTE`, confirmando a atomicidade por linha.
- `inicioVigencia` persistido com timestamp do servidor (alinhado a `criadoEm`/recibo/auditoria).
- CLI: `--dry-run --executar` → `MODO_CONFLITANTE` (exit 2); `--command-id`/`--origem` sem valor → `VALOR_OBRIGATORIO`.
- Observação de ambiente: dentro de `firebase emulators:exec`, o `node` embutido da CLI (v20) quebrou o vitest; a suíte roda com o node do sistema em caminho absoluto.

**Pendências conhecidas:**
- O seed canônico de igrejas (Story 1.2) é pré-requisito e ainda não foi implementado; sem ele a carga recusa as linhas como `IGREJA_INEXISTENTE`.

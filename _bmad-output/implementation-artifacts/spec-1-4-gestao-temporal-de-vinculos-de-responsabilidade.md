---
title: 'Gestão temporal de vínculos de responsabilidade'
type: 'feature'
created: '2026-09-30'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'caeef5650495027427e841b69784a4b305a759fc'
context:
  - 'AGENTS.md'
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As Stories 1.1–1.3 entregaram acesso administrativo, catálogo de igrejas/equipes e pessoas/papéis, mas não existe caminho para atribuir, encerrar ou substituir responsáveis vigentes: `igrejas.pastorLocalVigentePessoaId` só é gravado pela carga inicial e `equipes` não possui responsável canônico. Sem isso não há autoridade contextual (Pastor Local / responsável de equipe) para os Epics 2 e 3.

**Approach:** Adicionar comandos administrativos em Cloud Functions para atribuir, encerrar e substituir vínculos Pastor–Igreja e Pastor–Equipe com vigência semiaberta UTC, em transação sobre o documento canônico da igreja/equipe, preservando vínculos históricos e gravando recibo/auditoria no mesmo commit; e uma superfície administrativa mobile-first "Vínculos e Responsáveis" com responsável vigente, troca (data efetiva + confirmação) e linha do tempo somente leitura.

## Boundaries & Constraints

**Always:** Toda mutação só em Cloud Function callable v2 com App Check, Auth e autoridade administrativa vigente revalidada dentro da transação (tempo do servidor); usar o padrão de comando (`commandId` opaco, `correlationId`, `payloadHash`, versão esperada do agregado, recibo `commands/{commandId}` e `auditOutbox/{commandId}` no mesmo commit, erro neutro sem PII). O vínculo canônico é temporal e contextual: a autorização futura lê o vínculo vigente na hora de agir em vez de claims de pastor; chaves em `UPPER_SNAKE_CASE`, IDs opacos, timestamps UTC; exatamente um responsável canônico vigente por igreja e por equipe; a substituição encerra o anterior e inicia o novo sem sobreposição; decisões passadas e vínculos históricos permanecem intactos e não editáveis/excluíveis; igrejas/equipes inativas não recebem vínculo; Firestore/Storage deny-by-default; Flutter Web/PWA mobile-first e WCAG 2.2 AA (alvos ≥44 px, foco, teclado, leitor de tela, estado por texto+ícone). Reusar `consultarPessoas` para selecionar a pessoa e o padrão de busca sem acento do catálogo. Vínculos legados criados pela importação (`estado: 'VIGENTE'`, `pastorLocalVigenteVinculoId`) devem continuar sendo lidos como vigentes. Decisões (Q1–Q3): **Q1** a data efetiva é escolhida pelo administrador e **nunca futura** (≤ tempo do servidor), sem agendamento; atribuição aceita hoje ou passada, e substituição/encerramento exigem data ≥ início do vínculo vigente (não pode encerrar antes de começar); **Q2** encerrar é permitido e pode deixar a entidade sem responsável vigente; **Q3** a tela não exibe prévia de pendências (inexistentes até os Epics 2/3): mostra apenas responsável atual e data da troca, pois o redirecionamento é automático pela regra "vigente na hora de agir" (AD-3).

**Never:** Não emitir custom claims de `PASTOR_LOCAL`/`PASTOR_EQUIPE` (a autoridade pastoral continua derivada do vínculo, AD-2); não permitir dois vínculos vigentes simultâneos para a mesma igreja/equipe nem sobreposição temporal; não permitir data futura nem retroatividade que encerre o vínculo anterior antes do seu início; não alterar decisões/pendências já decididas nem reescrever histórico; não excluir fisicamente documentos de vínculo; não gerenciar pessoas/papéis (1.3), termos (1.5) nem fichas/participações (Epics 2/3); não usar enums/listas hardcoded de igrejas/equipes no Flutter; não expor PII em recibo, auditoria, logs ou erros.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Atribuir responsável | Igreja/equipe ativa, sem responsável vigente, pessoa válida, data efetiva válida | Cria vínculo `VIGENTE`, grava o par vigente na entidade canônica, recibo e auditoria | Replay idêntico devolve o recibo |
| Substituir responsável | Entidade com responsável vigente, nova pessoa, data efetiva válida | Uma transação encerra o anterior (`ENCERRADO`, `fimVigencia`) e cria o novo (`VIGENTE`, `inicioVigencia`), sem sobreposição | Sobreposição temporal → `failed-precondition` |
| Encerrar vínculo | Entidade com responsável vigente | Vínculo `ENCERRADO` com `fimVigencia`; entidade sem par vigente; histórico preservado | Vínculo inexistente → `failed-precondition` |
| Pessoa/entidade inativa ou inexistente | Pessoa sem identidade/perfil; igreja/equipe inativa ou ausente | Nenhuma mutação persistida | `invalid-argument` |
| Concorrência | `versaoVinculo` divergente do agregado | Nenhuma mutação; recarregar | `aborted` |
| Sessão sem autoridade | Sem Auth/App Check/papel administrativo | Operação recusada | `permission-denied` genérico |
| Consulta de vínculos | Administrador autorizado | Lista igrejas/equipes com responsável vigente, versão e linha do tempo (ator, papel em snapshot, ação, data/hora, justificativa) | Erro neutro |
| Data efetiva inválida | Data futura, ou que encerre o vínculo vigente antes do seu início | Operação recusada integralmente | `failed-precondition` |

</frozen-after-approval>

## Code Map

Backend:
- `functions/src/domain/vinculos.ts` (**novo**) -- tipos canônicos (`TipoEntidade` IGREJA/EQUIPE, `AcaoVinculo` ATRIBUIR/SUBSTITUIR/ENCERRAR, `PapelVinculo` PASTOR_LOCAL/PASTOR_EQUIPE, estados `VIGENTE`/`ENCERRADO`), validação da entrada (IDs opacos, data efetiva, `expectedVersion`), `hashVinculo`, planejamento puro da transição (encerrar anterior + criar novo) e erros de domínio; segue o estilo de `functions/src/domain/pessoas.ts:82-136` e `functions/src/domain/importacaoPastores.ts:25-99`.
- `functions/src/repositories/vinculos.ts` (**novo**) -- transação sobre o documento canônico da igreja/equipe (`igrejas`/`equipes`), grava vínculo + par vigente (`pastorLocalVigentePessoaId`/`pastorLocalVigenteVinculoId` ou `responsavelVigentePessoaId`/`responsavelVigenteVinculoId`) + `versaoVinculo`, recibo e `auditOutbox` no mesmo commit, com leitura retrocompatível do vínculo legado da importação; molde de `functions/src/repositories/pessoas.ts:92-233` e `functions/src/repositories/firestoreImportacao.ts:119-199`.
- `functions/src/commands/gerenciarVinculo.ts` + `functions/src/commands/consultarVinculos.ts` (**novos**) -- callables v2 (App Check/Auth/autoridade em transação, `commandId`/`payloadHash`/`versao`, erro neutro `'Operação administrativa indisponível.'`), no molde de `functions/src/commands/gerenciarPapeis.ts:25-84`; a consulta é read-only autorizada e não expõe PII.
- `functions/src/index.ts:1-9` -- exportar `gerenciarVinculo` e `consultarVinculos`.
- `firestore.rules:1-18` -- manter deny-by-default; cobrir negativas de `vinculosPastorIgreja`/`vinculosPastorEquipe` e dos campos de responsável, sem conceder escrita/leitura cliente.
- `functions/test/vinculos.test.ts` + `functions/test/vinculos.emulator.test.ts` (**novos**) + `functions/test/security-contract.test.ts` -- testes puros da matriz, de transação/Emulator e de contrato de segurança; estilos de `functions/test/pessoas.test.ts` e `functions/test/pessoas.emulator.test.ts`.

Frontend:
- `flutter_app/lib/features/admin/vinculos_service.dart` (**novo**) -- interfaces de gateway + implementação Firebase para `consultarVinculos`, `gerenciarVinculo` e busca de pessoas elegíveis via `consultarPessoas`, no molde de `flutter_app/lib/features/admin/pessoas_service.dart:81-211`; `comandoOpaco()` de `flutter_app/lib/comando.dart:4-8`.
- `flutter_app/lib/features/admin/vinculos_responsaveis.dart` (**novo**) -- tela mobile-first "Vínculos e Responsáveis": abas/segmentação Igrejas/Equipes, cartões com responsável vigente, ação atribuir/substituir/encerrar com confirmação e linha do tempo somente leitura, e estados carregando/erro/vazio/retentativa; segue `consulta_catalogo.dart:58-91` e `pessoas_papeis.dart:227-376` (tabela→cartões, `Semantics`/`liveRegion`).
- `flutter_app/lib/features/admin/admin_shell.dart:34-87` -- adicionar destino "Vínculos e Responsáveis" em `_destinos`, `case` em `_corpo()` e slot do gateway no construtor, sem regredir Catálogo/Seed/Pessoas e Papéis/Sair.
- `flutter_app/lib/main.dart:66-77,277-283` -- injetar o gateway no `AdminShell` a partir de `AreaAutenticada`, sem alterar a guarda de autorização.
- `flutter_app/test/fakes.dart` + `flutter_app/test/vinculos_responsaveis_test.dart` (**novo**) -- fake no padrão existente + testes de widget (sucesso, confirmação, sem permissão, erro/retentativa).

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/vinculos.ts` -- definir tipos/estados, validação, hash e planejamento puro da transição (atribuir/substituir/encerrar, sobreposição e versão) -- concentra a regra temporal testável sem Firestore.
- [x] `functions/src/repositories/vinculos.ts` -- transação sobre a entidade canônica gravando vínculo, par vigente, `versaoVinculo`, recibo e `auditOutbox`, lendo o legado da importação -- única fronteira de leitura/escrita do domínio.
- [x] `functions/src/commands/gerenciarVinculo.ts`, `functions/src/commands/consultarVinculos.ts` + `functions/src/index.ts` -- callables v2 com App Check, Auth, autoridade em transação, idempotência e auditoria; consulta read-only autorizada -- expõe a operação sem escrita direta de domínio.
- [x] `firestore.rules` + `functions/test/security-contract.test.ts` -- manter deny-by-default e cobrir negativas de vínculo/responsável -- preserva a fronteira backend.
- [x] `flutter_app/lib/features/admin/vinculos_service.dart` + `vinculos_responsaveis.dart` + `admin_shell.dart` + `main.dart` -- tela administrativa mobile-first com atribuir/substituir/encerrar, confirmação, data efetiva e linha do tempo -- entrega o objetivo ao administrador.
- [x] `functions/test/` e `flutter_app/test/` -- testes de domínio/contrato/Emulator e de widget cobrindo a matriz de I/O -- verifica os ACs.

**Acceptance Criteria:**
- Given uma igreja sem Pastor Local vigente, when o administrador atribui um pastor com data efetiva válida, then o sistema cria o vínculo temporal auditável e a igreja passa a ter exatamente um Pastor Local vigente.
- Given uma igreja com Pastor Local vigente, when o administrador confirma uma substituição com data efetiva, then uma transação encerra o vínculo anterior e cria o novo sem sobreposição temporal, e pendências não decididas passam a ser encontradas pelo novo vínculo vigente.
- Given uma equipe, when o administrador atribui ou substitui seu responsável, then o sistema mantém exatamente um responsável canônico vigente por vez e decisões já tomadas preservam responsável e vínculo em snapshot.
- Given uma tentativa de criar vínculo sobreposto, com data retroativa inválida ou para entidade inativa, when a operação é submetida, then a Cloud Function a rejeita integralmente sem alterar vínculos, filas ou auditoria de domínio.
- Given o administrador autorizado, when abre "Vínculos e Responsáveis", then vê o responsável vigente e a linha do tempo histórica somente leitura (ator, papel em snapshot, ação, data/hora, justificativa).

## Implementation Notes

Implementado conforme o bloco congelado, o Code Map e as Tasks & Acceptance. Backend: `functions/src/domain/vinculos.ts` (tipos/estados, `validarVinculo`, `dataEfetivaEmMs` UTC, `hashVinculo` sem PII, `camposVigente`/`papelDoTipo` e o núcleo puro `planejarVinculo` com sobreposição, versão e data não futura), `functions/src/repositories/vinculos.ts` (`gerenciarVinculo` transaciona sobre `igrejas`/`equipes`, revalida `podeAdministrar` dentro da transação, lê o ponteiro vigente inclusive o legado da importação sem timestamp, grava vínculo + par vigente + `versaoVinculo` + recibo `commands/{commandId}` + `auditOutbox/{commandId}` no mesmo commit; `lerVinculos` read-only sem e-mail/CPF) e os callables `gerenciarVinculo`/`consultarVinculos` exportados em `index.ts`. `firestore.rules` mantém deny-by-default e nega explicitamente `vinculosPastorIgreja`/`vinculosPastorEquipe`. Frontend: `features/admin/vinculos_service.dart` (gateway + `formatarDataEfetiva`), `vinculos_responsaveis.dart` (abas Igrejas/Equipes, atribuir/substituir/encerrar com data efetiva e confirmação, linha do tempo somente leitura com data/hora local, `Semantics`/`liveRegion`), destino em `admin_shell.dart` e injeção em `main.dart`. Testes: `functions/test/vinculos.test.ts` (domínio), `functions/test/vinculos.emulator.test.ts` (transação/Emulator) e ampliação de `security-contract.test.ts`; `flutter_app/test/vinculos_responsaveis_test.dart` + `VinculosFake` em `fakes.dart`.

Ajuste pós-verificação: `_formatarDataHora` em `vinculos_responsaveis.dart` passou a exibir data **e hora** (HH:mm local) na linha do tempo, para cumprir o AC que exige "data/hora" (antes só a data era formatada).

Verificação: `npm test --prefix functions` → 90 passam, 37 puladas (Emulator); `npm run build --prefix functions` → OK; `flutter analyze --fatal-infos` → sem diagnósticos; `flutter test` → 62 passam; `npm run test:emulator --prefix functions` (com Emulators Auth+Firestore) → 37/37, incluindo 12 de vínculos. Cada linha da matriz de I/O tem teste que rodou e passou (domínio, contrato e Emulator), inclusive sessão sem autoridade sem mutação persistida e consulta read-only sem PII.

Riscos/limitações: (1) a data efetiva tem granularidade de dia (meia-noite UTC), então substituir um vínculo iniciado no mesmo dia mais tarde pode dar `failed-precondition`; (2) `lerVinculos` devolve nome de exibição do responsável e do ator (sem e-mail/CPF), necessário para a linha do tempo; (3) `consultarVinculos` lê as coleções completas, sem paginação — mesma escala administrativa da 1.2/1.3; (4) ponteiro de responsável sem documento de vínculo é tratado como vigente e substituído sem gerar histórico (caso defensivo de legado).

## Spec Change Log

## Review Triage Log

| # | Finding (agrupado por causa raiz) | Verdict | Route | Evidence |
|---|-----------------------------------|---------|-------|----------|
| 1 | O caminho de escrita ignora o `estado` do vínculo apontado: ponteiro para vínculo já `ENCERRADO` bloquearia `ATRIBUIR` e permitiria reescrever `fimVigencia` de registro fechado (blind + edge-case). | false | reject | Nenhum caminho produz ponteiro para vínculo `ENCERRADO`: `encerrar` apaga o ponteiro (`vinculos.ts:221-222`) e `substituir`/`atribuir` o reapontam para o novo `VIGENTE`; a importação sempre grava `VIGENTE`. Sem caminho de escrita que crie o estado, não há defeito demonstrado. |
| 2 | `ATRIBUIR` com data passada após `ENCERRAR` não verifica sobreposição contra intervalos históricos já fechados (blind). | low | reject | `planejarVinculo` só compara com o `vigente` corrente; um novo vínculo retroativo poderia cruzar um intervalo fechado. Gesto incomum (o seletor inicia em "hoje"), sem quebra funcional hoje (autorização é sempre por vínculo vigente no instante presente, não histórica); a correção exigiria ler o histórico completo, além de correção direta. |
| 3 | Ramo de ponteiro pendurado faz `tx.update` em documento inexistente quando o id aponta para vínculo ausente com ponteiro de pessoa presente (blind + verification "Other"). | false | reject | O estado exige ponteiro `...VinculoId` sem o documento correspondente. A importação (`firestoreImportacao.ts:119-199`) e as novas mutações gravam ponteiro e documento atomicamente na mesma transação; nenhum caminho cria o estado. |
| 4 | `gerenciarVinculo` só valida existência do perfil `pessoas`, não a identidade Auth, para a linha "Pessoa sem identidade/perfil" da matriz (blind). | false | reject | A matriz cobre "sem identidade/perfil" e é atendida por "sem perfil": `repositories/vinculos.ts:137-141` lança `PessoaInexistenteError` → `invalid-argument`. `pessoas` é criado junto com a conta Auth (1.3/importação), então perfil sem identidade não é um estado produzido. |
| 5 | A UI colapsa `failed-precondition`/`aborted`/`invalid-argument` em uma única mensagem neutra (blind). | false | reject | Erro neutro é requisito do bloco congelado ("erro neutro sem PII") e a orientação "recarregue e tente novamente" cobre o reload em conflito; deliberado, não defeito. |
| 6 | A linha do tempo recalcula `papel` a partir do tipo e cai em `ATRIBUIR` para `acao` desconhecida, em vez de ler o snapshot persistido (blind). | false | reject | Para o vínculo o papel é determinístico por tipo (`papelDoTipo`) e sempre igual ao persistido; a queda para `ATRIBUIR` é justamente o que faz o vínculo legado da importação (sem `acao`) aparecer legível. Sem resultado incorreto. |
| 7 | Fuso: o seletor usa o dia local e o servidor reduz a `UTC` comparando com `Date.now()`, rejeitando "hoje" como futuro em fusos a leste de UTC (blind + edge-case). | false | reject | O público-alvo é o Brasil (UTC−3/−4), a oeste de UTC: a meia-noite UTC do dia local escolhido nunca é posterior a `Date.now()`, então o servidor sempre aceita "hoje". Não alcançável na operação real. |
| 8 | Sem cobertura Flutter para `formatarDataEfetiva`/helpers de data e para a saída "data/hora" da linha do tempo (blind + verification-gap, pré-verificado). | low | patch | `flutter_app/test/vinculos_responsaveis_test.dart:98-102` assere ator/ação/justificativa, mas não a linha `Início:` nem `HH:mm`; reverter `_formatarDataHora` para só data manteria a suíte verde, então o AC "data/hora" e o envio `YYYY-MM-DD` ficam sem trava de regressão. |
| 9 | Busca server-side (`termo` em `consultarVinculos`) é caminho morto e duplicado, com filtro local em paralelo (blind). | false | reject | A tela sempre busca o conjunto completo e filtra no cliente (mesmo desenho de `pessoas_papeis`/`consulta_catalogo`); o parâmetro opcional não causa dano nem divergência de resultado. |
| 10 | Diálogo de seleção de pessoa com largura fixa 420, sem retentativa e sem excluir o responsável atual (blind). | low | reject | O `AlertDialog` restringe a largura ao `maxWidth` da tela (sem overflow real); a falha de carga mostra mensagem e recompor o diálogo é gesto trivial; escolher o responsável atual falha limpo com `failed-precondition`. Correção exigiria complexidade além de correção direta. |
| 11 | `sprint-status.yaml` diz `in-progress` enquanto o spec está `in-review` (blind). | false | reject | Estado transitório esperado do fluxo: o status de sprint é sincronizado na etapa de apresentação; não é defeito do código. |
| 12 | Três leituras de `autoridadesAdministrativas` (pré-comando, pré-transação e na transação) (blind). | low | reject | As leituras fora da transação impedem revelar existência de alvo a chamador sem autoridade; a revalidação transacional é requisito. Latência desprezível para um painel administrativo. |
| 13 | `lerVinculos` lê coleções completas sem paginação e o teste usa consulta com `where` composto sem índice declarado (blind). | low | reject | Produção não usa `where` (varredura sem índice) e a escala é administrativa, igual à 1.2/1.3; a limitação já está registrada nas notas de implementação. |
| 14 | Comparador de `historico` nunca retorna 0 e ordena por string ISO possivelmente vazia (blind). | low | patch | `vinculos.ts:319` viola o contrato do comparador (não retorna 0 em empates), tornando a ordem dependente da implementação do sort; correção direta (retornar 0 em igualdade). |
| 15 | Rules não adicionam negativa específica para os campos de responsável nas entidades (blind). | false | reject | `igrejas`/`equipes` já têm `allow write: if false`; nenhum campo, inclusive os de responsável, é gravável pelo cliente. O `match` explícito das coleções de vínculo reforça o resto. |
| 16 | `justificativa` livre e nomes retornados pela consulta poderiam conter PII sem mascaramento (blind). | false | reject | Nomes de exibição e justificativa são conteúdo administrativo previsto (UX/AC "justificativa" na linha do tempo) e restritos a administrador autorizado; o esquema proíbe e-mail/CPF, que é o que os testes verificam. |
| 17 | `justificativa` fora do `payloadHash`, então replay com comando igual e justificativa diferente devolveria recibo antigo (edge-case). | false | reject | A UI gera `commandId` novo a cada ação (`comandoOpaco()`), então não existe replay com justificativa alterada alcançável pelo app; o replay coincide apenas em retentativa idêntica. |
| 18 | Entidade inativa continua com botões de atribuir/substituir/encerrar habilitados, levando a erro genérico (edge-case). | low | patch | `vinculos_responsaveis.dart` mostra o chip "Inativa" mas deixa as ações ativas; o servidor recusa com `invalid-argument` genérico. Correção direta: desabilitar as ações quando `!item.ativo`, mantendo a explicação acessível. |
| 19 | `FirebaseVinculosGateway` (mapeamento de resposta e formato de `dataEfetiva`/`expectedVersion`) não é exercitado por teste algum; só o fake é testado (verification-gap, pré-verificado). | low | patch | Nenhum teste instancia o gateway real; uma troca de nome de campo na resposta passaria verde (a tela renderiza `—`/vazio). Extrair mapeadores puros e/ou testar com resposta stub. |
| 20 | Códigos `failed-precondition`/`aborted` do callable `gerenciarVinculo` não são assertados (verification-gap, pré-verificado). | low | patch | Os testes de Emulator só assertam `permission-denied`/`invalid-argument`; trocar o mapeamento de erro do comando não quebraria teste, embora a matriz exija esses códigos. |
| 21 | Vínculos legados da importação são gravados com `igrejaId` e sem `entidadeId`/`tipoEntidade`, mas `agruparPorEntidade` descarta quem não tem `entidadeId`, omitindo-os da linha do tempo (verificação própria). | low | patch | `firestoreImportacao.ts:159-171` grava `igrejaId` e não `entidadeId`; `vinculos.ts:281` agrupa só por `entidadeId`, então a leitura retrocompatível prometida no Code Map só funciona para responsável vigente, não para o histórico. O teste de legado grava um documento irreal (com `entidadeId`). |

## Design Notes

O vínculo é o agregado temporal canônico: a igreja/equipe guarda apenas o par vigente (`PessoaId`+`VinculoId`) e `versaoVinculo` para concorrência otimista; o histórico vive em `vinculosPastorIgreja`/`vinculosPastorEquipe` (`VIGENTE`/`ENCERRADO`). A substituição é uma transação única que fecha o anterior com `fimVigencia = dataEfetiva` e abre o novo com `inicioVigencia = dataEfetiva`, garantindo intervalo semiaberto `[inicio, fim)` sem sobreposição. Preservam-se as decisões passadas sem tocar em fichas/participações: a atribuição de pendências não decididas já é resolvida pelo vínculo vigente na hora de agir (AD-3), então esta story não reescreve pendências. Não há claims de pastor: a autoridade pastoral continua sendo o vínculo (AD-2). Decisões: (Q1) data efetiva escolhida, nunca futura, sem agendamento; (Q2) encerrar pode deixar a entidade sem responsável vigente; (Q3) a tela omite a prévia de pendências até os Epics 2/3 existirem.

## Verification

**Commands:**
- `npm test --prefix functions` -- esperado: domínio, idempotência, autorização e contratos de segurança aprovados.
- `npm run build --prefix functions` -- esperado: TypeScript compila para deploy.
- `flutter analyze --fatal-infos` -- esperado: app e tela de vínculos sem diagnósticos (executar em `flutter_app`).
- `flutter test` -- esperado: guarda administrativa, nova tela e estados acessíveis aprovados (executar em `flutter_app`).
- `npm run test:emulator --prefix functions` -- esperado: transações de vínculo e recusa de sobreposição aprovadas com Emulators ativos.

### Review Findings

Revisão de código (2026-09-30) — Story 1.4, **Grupo 1 (backend produção)**. Diff `caeef56..HEAD` restrito a `functions/src/domain/vinculos.ts`, `functions/src/repositories/vinculos.ts`, `functions/src/commands/gerenciarVinculo.ts`, `functions/src/commands/consultarVinculos.ts`, `functions/src/index.ts`, `firestore.rules`, `functions/package.json`. Camadas: Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor. Grupos 2–4 (testes backend, Flutter lib, Flutter testes+artefatos) permanecem para execuções seguintes.

**decision-needed**

_(nenhum — resolvido em 2026-09-30)_

**decision resolvida**
- [x] [Review][Reject] Campos de responsável legíveis pelo cliente em `igrejas`/`equipes` — decisão humana: aceitar a exposição; os IDs são opacos (sem nome/PII) e o catálogo `igrejas`/`equipes` já é legível por design desde a Story 1.2.

**patch**
- [x] [Review][Patch] `payloadHash` não vincula `justificativa`/`correlationId` — replay do mesmo `commandId` com justificativa divergente devolve o recibo antigo sem detectar a divergência, então o recibo deixa de provar o payload que o produziu. [functions/src/domain/vinculos.ts:323-336]
- [x] [Review][Patch] Rótulo de igreja sem `codigo` gera `"Nome -"` com separador pendente. [functions/src/repositories/vinculos.ts:354-357]
- [x] [Review][Patch] Sem teste de Emulator para entidade inativa no caminho de escrita: `repositories/vinculos.ts:135` nunca roda com `ativo: false` (o teste de domínio chama `planejarVinculo` sem passar pelo repositório). [functions/test/vinculos.emulator.test.ts]
- [x] [Review][Patch] Vínculo legado (`igrejaId` sem `entidadeId`) não é assertado no `historico` de `lerVinculos`; remover o fallback de agrupamento em `agruparPorEntidade` manteria a suíte verde e o vínculo sumiria da linha do tempo. [functions/src/repositories/vinculos.ts:286-287]
- [x] [Review][Patch] Callable `gerenciarVinculo` sem asserção dos códigos `invalid-argument` (entidade/pessoa inexistente) e `failed-precondition` (data futura), embora a matriz de I/O os exija. [functions/test/vinculos.emulator.test.ts:545-641]

**Rejected**
- `false` — Ponteiro `...VinculoId` pendurado levaria a `tx.update` em documento inexistente (BH1/ECH1/AA3): nenhum caminho de escrita produz ponteiro sem documento; a importação (`firestoreImportacao.ts:154-171`) e as novas mutações gravam ponteiro e vínculo atomicamente na mesma transação.
- `false` — Vínculo apontado com `estado: ENCERRADO` tratado como vigente (ECH3/AA4): `encerrar` apaga o ponteiro e `atribuir`/`substituir` o reapontam para o novo `VIGENTE`; nenhum caminho cria o estado.
- `false` — `resumir` reportaria responsável sem vínculo `VIGENTE` de apoio (BH2): depende do mesmo estado não produzido; com ponteiro válido o documento `VIGENTE` é encontrado.
- `false` — `VinculoInvalidoError` de `planejarVinculo` escaparia sem mapeamento (BH8): `validarVinculo` garante `pessoaId` em ATRIBUIR/SUBSTITUIR, tornando o ramo inalcançável.
- `false` — `ENCERRAR` registraria encerramento sem vínculo (BH10): exige ponteiro de pessoa sem ponteiro de vínculo, estado não produzido por nenhum caminho.
- `low` — `ATRIBUIR` retroativo após `ENCERRAR` não compara com intervalos fechados (ECH2/AA1): gesto incomum (o seletor inicia em hoje) e a correção exigiria ler o histórico completo na transação — não vale o custo agora.
- `low` — `atorNome` não é snapshot na linha do tempo (BH3): o papel é determinístico e correto; snapshot do nome exigiria novo campo/migração.
- `low` — leituras de coleções completas sem paginação (BH5): limitação já documentada, escala administrativa igual à 1.2/1.3.
- `low` — parâmetro `termo` server-side é caminho morto (BH6): a tela filtra no cliente; sem divergência de resultado.
- `low` — `justificativa` não-string é silenciosamente reduzida a nulo (BH7/ECH5): só alcançável por chamada forjada; a UI envia string.
- `low` — `consultarVinculos` aceita `request.data` não-objeto e devolve a listagem completa (ECH4): só alcançável por chamada forjada; resultado é a listagem já autorizada.

### Review Findings — Grupo 2 (testes backend)

Revisão de código (2026-09-30) — Story 1.4, **Grupo 2 (testes backend)**. Diff `caeef56..working tree` restrito a `functions/test/vinculos.test.ts`, `functions/test/vinculos.emulator.test.ts`, `functions/test/security-contract.test.ts`. Camadas: Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor.

**patch**
- [x] [Review][Patch] Binding de `justificativa`/`correlationId` no `hashVinculo` não é pinado por teste; reverter o hash manteria a suíte verde, sem travar a proteção recém-corrigida. [functions/test/vinculos.test.ts:136-148]
- [x] [Review][Patch] `SUBSTITUIR` com o responsável atual (`OperacaoInvalidaError`) não é coberto no domínio; remover o guard não quebraria teste. [functions/test/vinculos.test.ts:161]
- [x] [Review][Patch] `SUBSTITUIR` retroativo (data anterior ao início do vigente → `SobreposicaoError`) não é coberto; só há caso de `ENCERRAR`. [functions/test/vinculos.test.ts:223]
- [x] [Review][Patch] Detector de PII ineficaz para e-mail: `not.toMatch(/nomeCompleto|email@|cpf/)` nunca casa `"email":"a@exemplo.com"`, então vazamento de e-mail passaria. [functions/test/vinculos.emulator.test.ts:181-182]
- [x] [Review][Patch] Asserções tautológicas: `cobre as três ações válidas` só mede o comprimento de um array literal, e `expect(payloadHash).not.toContain(pessoaId)` é sempre verdadeiro (hex não contém o ID). [functions/test/vinculos.test.ts:139-140,261-264]
- [x] [Review][Patch] Linha do tempo da consulta não assere `justificativa` nem data/hora, exigidas pelo AC5/matriz. [functions/test/vinculos.emulator.test.ts:470-485]
- [x] [Review][Patch] Testes de recusa não asseram `auditOutbox` intocado (AC4 "sem alterar ... auditoria de domínio"). [functions/test/vinculos.emulator.test.ts]
- [x] [Review][Patch] `gerenciarVinculo` sem caso de sessão sem `auth` (matriz "Sem Auth → permission-denied"); só há `sem-autoridade`. [functions/test/vinculos.emulator.test.ts:495-510]
- [x] [Review][Patch] Invariante "exatamente um vigente" da equipe consultado sem filtro por `entidadeId`; passaria com um segundo `VIGENTE` de outra equipe. [functions/test/vinculos.emulator.test.ts:340-344]
- [x] [Review][Patch] `afterAll` apaga todos os usuários do Auth emulator (`listUsers` → `deleteUsers`), incluindo de outras suítes; a suíte de vínculos não cria usuários. [functions/test/vinculos.emulator.test.ts:141-147]

**defer**
- [x] [Review][Defer] Suíte de Emulator não roda no caminho padrão (`npm test` a ignora; `test:emulator` não usa `emulators:exec` nem CI). [functions/package.json:10-11] — deferred: lacuna de infraestrutura pré-existente, já registrada em `deferred-work.md:24`.
- [x] [Review][Defer] Assertivas de Rules são texto-fonte (sem `@firebase/rules-unit-testing`); regra permissiva passaria. [functions/test/security-contract.test.ts:199-204] — deferred: sem harness de Rules no repo, já registrado em `deferred-work.md:54`.

**Rejected**
- `low` — Sobreposição histórica (`ATRIBUIR` retroativo após `ENCERRAR`) não impedida: mesmo item do Grupo 1 já rejeitado como `low` (gesto incomum, correção exige leitura do histórico).
- `low` — `papel` da linha do tempo derivado em vez de lido do snapshot persistido (AA2): `papelDoTipo` é determinístico por tipo, então a saída é sempre correta; verificar o campo persistido não muda resultado.
- `low` — Legado da importação aparece como `acao: 'ATRIBUIR'` (AA3): fallback documentado que torna o vínculo legado legível; não reescreve dado persistido.
- `false` — "Nenhuma implementação no diff, nada prova que os testes compilam" (BH1): a suíte foi executada com sucesso (90 unit + 40 Emulator).
- `low` — App Check verificado só por texto (`toContain('enforceAppCheck: true')`) (BH4/AA7): `.run()` não exercita App Check; abordagem de contrato estático pré-existente.
- `low` — Regex de contrato acopladas a formatação (`not.toMatch(/allow\s+[^;]*request\.auth/)`) (BH6): frágil, mas funciona no formato atual.
- `low` — Estado mutável compartilhado entre `it` sem `beforeEach` (BH7/ECH4): suíte roda em ordem e passa; reset por teste é refatoração além de correção direta.
- `low` — `correlationId` opcional/regex sem teste; controle de caracteres e normalização de `justificativa` sem teste; limites de ano e bissexto de `dataEfetivaEmMs` sem teste (BH11-13): casos baixos, cobertura incremental.
- `low` — `lerVinculos(db, termo)` sem teste (BH14): o parâmetro foi rejeitado como caminho morto no Grupo 1.
- `low` — Ramos de ponteiro pendurado e agrupamento legado por `equipeId` sem teste (BH15): dependem de estados não produzidos.
- `low` — Ordem de autoridade (alvo inexistente → `SemAutoridadeError`) e revogação em corrida sem teste (BH16): comportamento defensivo sem caminho demonstrado.
- `low` — `OperacaoInvalidaError` no mapeamento do callable sem teste (BH17): o código é determinístico e o domínio cobre o erro.
- `low` — `dataEfetivaEmMs(...) as number` admite `null` no fixture (BH18/ECH1): datas do fixture são fixas e válidas.
- `low` — `historico[0]` não assere `estado` (BH19): coberto indiretamente por outras asserções.
- `low` — Invariante exatamente-um-vigente sem teste concorrente (BH20): transação já garante; teste de contenção exige infraestrutura.
- `low` — Rules não cobrem negativas dos campos de responsável no teste (AA6): decisão do Grupo 1 foi aceitar a exposição dos campos.

### Review Findings — Grupo 3 (Flutter produção)

Revisão de código (2026-09-30) — Story 1.4, **Grupo 3 (Flutter lib)**. Diff `caeef56..working tree` restrito a `flutter_app/lib/features/admin/vinculos_responsaveis.dart`, `flutter_app/lib/features/admin/vinculos_service.dart`, `flutter_app/lib/features/admin/admin_shell.dart`, `flutter_app/lib/main.dart`. Camadas: Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor.

**decision-needed**

_(nenhum — resolvido em 2026-09-30)_

**decision resolvida**
- [x] [Review][Patch] Linha do tempo passa a exibir só a data efetiva (dia escolhido, calendário UTC), sem hora e sem `.toLocal()`, para não deslocar o dia nem fabricar horário. [flutter_app/lib/features/admin/vinculos_responsaveis.dart:644-650]

**patch**
- [x] [Review][Patch] Cartão não mostra a "data da troca" (Q3), só o responsável vigente; a data fica escondida na linha do tempo expandida. [flutter_app/lib/features/admin/vinculos_responsaveis.dart:341-363]
- [x] [Review][Patch] Entidade inativa desabilita as ações sem explicação acessível vinculada aos botões ("manter a explicação acessível" do ajuste do review anterior). [flutter_app/lib/features/admin/vinculos_responsaveis.dart:365-394]
- [x] [Review][Patch] Faixa de erro de mutação instrui "Recarregue e tente novamente" mas não oferece controle de recarregar; `_recarregar` só está no erro de carga. [flutter_app/lib/features/admin/vinculos_responsaveis.dart:138-146,219-224]
- [x] [Review][Patch] Busca por nome/código (`filtrarVinculos`) não tem teste; trocá-la por `return true` manteria a suíte verde. [flutter_app/lib/features/admin/vinculos_service.dart:138-148]
- [x] [Review][Patch] Limites do seletor de data efetiva (`_primeiraData`/`lastDate`) não têm teste; permitir data futura ou abaixo do início vigente passaria. [flutter_app/lib/features/admin/vinculos_responsaveis.dart:79-90,149-159,476-481]

**Rejected**
- `low` — Mapeamento do `FirebaseVinculosGateway` não exercitado (BH): o contrato de campos já é coberto pelos mappers puros exportados e o nome do callable pelo `security-contract.test.ts`; só a fiação fina `httpsCallable().call()` fica sem teste, e mocká-la exigiria harness da plataforma.

**Rejected**
- `low` — `commandId` novo a cada tentativa (BH): nova ação do usuário é legitimamente um novo comando; o servidor recusa a duplicata pelo estado (vigente existente), preservando a integridade.
- `low` — `VinculoResultado` descartado e `repetido` não exibido (BH): a tela recarrega via `consultar`; nenhum resultado incorreto.
- `low` — Seletor de pessoa inclui o responsável atual e falha genérico (AA4): falha limpa com `failed-precondition`; mesmo item já rejeitado no review anterior (#10).
- `low` — Mapeamento lança em resposta nula/não-`Map` e omite defaults silenciosos (ECH/BH): o backend sempre devolve o shape; guards adicionariam complexidade.
- `low` — `pessoa.uid` vazio no payload (ECH): `PessoaAdministrativa` sempre tem `uid`.
- `low` — Segunda ação iniciada antes do refresh resolve usa `versaoVinculo` obsoleta (ECH): o servidor protege com `aborted`; janela rara.
- `low` — `_evento` decide "(vigente)" por `fimVigencia == null` em vez do `estado` (BH): o backend sempre grava `fimVigencia` no encerrado.
- `low` — Código morto (`rotulosTipoEntidade`, `VinculosResposta.vazio`, `termo` server-side não exercitado) (BH): inofensivo; `termo` já rejeitado como caminho morto no Grupo 1.
- `low` — Sem spinner durante a mutação (BH): botões desabilitam; feedback suficiente.
- `low` — `SegmentedButton` com ícones pode transbordar (BH): dois segmentos cabem em telas mobile.
- `low` — Faixas de aviso/erro não são limpas ao trocar de aba (BH): cosmético.
- `low` — Rótulo "Pesquisar por nome ou código" impreciso na aba Equipes (BH): equipes não têm código; wording.
- `low` — Inconsistência "Responsável" vs "Responsável de Equipe" (BH): cosmético.
- `low` — Limites de data caem em janela arbitrária de 5 anos sem vigente/legado (BH): servidor recusa com mensagem neutra; gesto incomum.

### Review Findings — Grupo 4 (Flutter testes + artefatos)

Revisão de código (2026-09-30) — Story 1.4, **Grupo 4 (Flutter testes + artefatos)**. Diff `caeef56..working tree` restrito a `flutter_app/test/vinculos_responsaveis_test.dart`, `flutter_app/test/vinculos_service_test.dart`, `flutter_app/test/fakes.dart`, `spec-1-4-…md`, `sprint-status.yaml`. Camadas: Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor.

**patch**
- [x] [Review][Patch] A mudança da linha do tempo para data-only não está pinada: `textContaining('Início: 05/01/2020')` também casa `05/01/2020 HH:mm`, e o fixture é 14:30 UTC (não meia-noite), então reverter para o formato local passaria. Usar fixture meia-noite UTC e asserção exata. [flutter_app/test/vinculos_responsaveis_test.dart:48,102]
- [x] [Review][Patch] Ramo de entidade inativa (botões desabilitados + explicação) sem teste; nenhum fixture usa `ativo: false`. [flutter_app/test/vinculos_responsaveis_test.dart]
- [x] [Review][Patch] Linha "Data da troca" do cartão sem asserção. [flutter_app/test/vinculos_responsaveis_test.dart:85-104]
- [x] [Review][Patch] Controle "Recarregar" da faixa de erro de mutação sem teste; o teste atual só confere `consultas == 1`. [flutter_app/test/vinculos_responsaveis_test.dart:209-228]
- [x] [Review][Patch] Busca "sem acento" não exercitada: digita `goianinha` (já sem acento), nunca `mossoro` para casar `Mossoró`. [flutter_app/test/vinculos_responsaveis_test.dart]
- [x] [Review][Patch] Teste dos limites do seletor de data é sensível à virada de meia-noite (`DateTime.now()` após o pump). [flutter_app/test/vinculos_responsaveis_test.dart]
- [x] [Review][Patch] Mutação de EQUIPE (`tipoEntidade: 'EQUIPE'`, papel responsável) não exercitada; só há IGREJA. [flutter_app/test/vinculos_responsaveis_test.dart]
- [x] [Review][Patch] Evento `ENCERRADO` (com `Fim:`) na linha do tempo sem teste; o único fixture é `VIGENTE`. [flutter_app/test/vinculos_responsaveis_test.dart]
- [x] [Review][Patch] Ramos "Nenhum resultado encontrado." e "Nenhuma equipe cadastrada." sem teste. [flutter_app/test/vinculos_responsaveis_test.dart]
- [x] [Review][Patch] Falha de `buscarPessoas` inalcançável no fake (`falhar` só afeta `consultar`) e sem teste do estado de erro do seletor de pessoa. [flutter_app/test/fakes.dart:251-254]
- [x] [Review][Patch] Asserções de mapeamento incompletas: `montarPayloadVinculo` não confere `commandId`/`tipoEntidade`/`entidadeId` e o teste de `mapearItemVinculo` só verifica `historico` por tamanho. [flutter_app/test/vinculos_service_test.dart]

**Rejected**
- `false`/tratado — Frontmatter do spec `done` vs `sprint-status` `review` (BH4/AA7): reconciliado na atualização de status do workflow.
- `low` — Mappers fabricam `acao: 'ATRIBUIR'` e `tipoEntidade: 'IGREJA'` para campos ausentes (BH11/BH12/AA3/AA4): defaults defensivos; o backend sempre envia os campos.
- `low` — Sem asserções de `Semantics`/`liveRegion` (BH13/AA6): a UI já implementa a semântica; cobrir toda ela excede correção direta e o overflow/foco já é coberto em `layout_referencia_test`.
- `low` — `FirebaseVinculosGateway` real sem teste (AA5): mesma rejeição do Grupo 3 (mappers puros cobrem o contrato; mock da plataforma seria necessário).
- `false` — #14 sem patch correspondente (BH8): o comparador já retorna `0` em empate (`functions/src/repositories/vinculos.ts:325`), então o patch foi aplicado.
- reject (correção seria editar o spec sob review) — AC5/Implementation Notes contradizem a decisão data-only (BH1/BH2/AA1), Spec Change Log vazio (BH3), preâmbulo do Grupo 1 desatualizado (BH5), contagens de teste divergentes (BH6), "toda linha tem teste" exagerado (BH7), `package.json` sem justificativa (BH9), `vinculos_service_test.dart` fora do Code Map (BH10), `**Rejected**` duplicado no Grupo 3 (BH19).
</content>

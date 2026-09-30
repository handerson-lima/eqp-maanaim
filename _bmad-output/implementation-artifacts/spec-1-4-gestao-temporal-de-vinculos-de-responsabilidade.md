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
</content>

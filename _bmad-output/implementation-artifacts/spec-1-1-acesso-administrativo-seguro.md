---
title: 'Acesso administrativo seguro'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 2
baseline_commit: '27caa56c63d99077f444365aa6a42329f9e96f23'
context:
  - 'AGENTS.md'
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O aplicativo já autentica voluntários, mas não distingue uma pessoa autorizada a operar a administração. Não há fronteira reutilizável que impeça o acesso administrativo de sessões comuns ou mantenha a autorização atualizada após concessão e revogação.

**Approach:** Introduzir a fundação mínima de autorização administrativa: papel efetivo emitido apenas pelo backend, consulta administrativa protegida para a UI e uma área administrativa inicial acessível somente à sessão autorizada. A primeira identidade e senha já existem no Firebase Authentication; conceder a ela, por processo operacional seguro e com UID fornecido apenas em tempo de execução, a autoridade inicial e a Custom Claim reconciliada. As operações de gestão ampla de pessoas, papéis, igrejas, equipes, vínculos e termos ficam nas Stories 1.2–1.5.

## Boundaries & Constraints

**Always:** Manter Firebase Authentication separado de papel, vínculo e escopo; executar mutações críticas somente em Cloud Functions callable com autenticação e App Check; validar a autorização efetiva a cada requisição, com tempo do servidor; usar `commandId`, `correlationId`, transação, recibo e `auditOutbox` correlacionado para concessão/revogação; conceder a primeira autoridade somente a uma identidade Firebase Authentication já existente, pelo UID recebido em memória pelo processo operacional IAM/ADC; usar esse UID opaco somente como chave do documento canônico de autoridade, nunca em logs, erros, auditoria ou código versionado; persistir uma máquina de estados de provisionamento e reconciliar, de modo idempotente, a autoridade no Firestore e a claim, sem reverter alteração posterior de papel em replay; bloquear auto-revogação e revogação do último administrador ativo; impedir escrita direta de domínio em Firestore e Storage; não registrar PII, e-mail, token, senha ou conteúdo sensível em logs, erros ou auditoria; preservar Flutter Web/PWA mobile-first e WCAG 2.2 AA.

**Never:** Conceder papel pelo cadastro, recuperação de senha, UI cliente, Custom Claims graváveis pelo usuário ou importação existente; implementar CRUD administrativo completo, gestão de vínculos, termo, MFA ou alterações de privilégios sem uma autorização administrativa já vigente; expor dados administrativos a sessão sem papel efetivo.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sessão sem privilégio | Visitante ou usuário autenticado sem papel administrativo | Não vê navegação/área administrativa; chamada protegida não revela projeções administrativas | Retorno genérico de permissão, sem detalhes de escopo ou dados |
| Administrador vigente | Sessão autenticada, App Check válido e papel backend efetivo | Vê a área inicial e consulta a projeção mínima autorizada | Interface anuncia carregamento/erro e mantém foco acessível |
| Provisionamento inicial | UID de identidade Firebase Authentication existente, informado somente em tempo de execução e sem administrador vigente | Processo IAM/ADC avança estados persistidos para autoridade e claim, usando o UID apenas como chave canônica; uma retentativa reconcilia somente a etapa pendente | UID inexistente ou estado incompatível interrompe sem criar autoridade parcial nem registrar o UID em logs ou auditoria |
| Concessão/revogação | Administrador autorizado, alvo válido, `commandId` e versão esperada | Function altera somente a autoridade permitida, registra antes/depois mínimo, recibo e outbox; token/sessão passa a refletir nova autorização em requisições seguintes | Replay igual retorna resultado idempotente; conflito, alvo inválido ou comando divergente é recusado sem mutação parcial |
| Escrita direta/requisição inválida | Cliente tenta gravar domínio/Storage, omite Auth ou falha App Check | Rules negam escrita; Function não executa transição | Erro seguro, sem PII ou concessão implícita |
| Revogação de continuidade | Administrador tenta revogar a própria autoridade ou a última autoridade ativa | Nenhuma mudança de papel é persistida | Retorno seguro de pré-condição; a capacidade administrativa continua recuperável |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/main.dart` -- bootstrap Firebase/App Check, roteamento da sessão e superfícies públicas; integrar guarda e entrada administrativa sem regredir cadastro/login.
- `flutter_app/lib/features/auth/auth_service.dart` -- gateways testáveis de Firebase Auth/Functions; estender para token/estado administrativo e refresh seguro após mudança de claim.
- `functions/src/index.ts` e `functions/src/commands/criarOuRetomarRascunho.ts` -- padrão existente de callable v2, App Check, autenticação, transação e auditoria a reutilizar, sem alterar o fluxo de rascunho.
- `functions/src/domain/` e `functions/src/repositories/` -- criar autoridade canônica e reconciliador de claim por revisão que preserva claims alheias, atualiza recibo terminal/pêndencia, revalida a revisão após escrita externa e compensa a revisão atual em caso de corrida ou falha.
- `scripts/conceder-primeiro-administrador.mjs` e `functions/package.json` -- criar processo operacional com ADC/IAM que recebe UID em tempo de execução, inicia e retoma a reconciliação; não expor endpoint HTTP sem administrador inicial.
- `functions/test/security-contract.test.ts`, `functions/test/*.test.ts` e testes Emulator -- ampliar contratos positivos/negativos de App Check, RBAC, idempotência, redaction, corrida de revisão, retomada operacional e negações reais de Firestore/Storage.
- `firestore.rules`, `firebase.json` e novo `storage.rules` -- preservar deny-by-default e incluir Storage no contrato/configuração Firebase.
- `flutter_app/test/auth_service_test.dart`, `flutter_app/test/login_envio_test.dart` -- testar guarda administrativa, renovação de autorização e semântica da UI.
- `README.md` -- documentar bootstrap operacional escolhido, emuladores e limites de acesso, sem segredos.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/{commands,domain,repositories}/` e `functions/src/index.ts` -- implementar fonte canônica de autoridade, concessão/revogação protegidas e reconciliador de claim por revisão; validar Auth, App Check, autoridade vigente, alvo, versão, `commandId`, auto-revogação e último administrador antes de qualquer mudança; preservar claims alheias, registrar resultado terminal da reconciliação e compensar revisão obsoleta.
- [x] `scripts/conceder-primeiro-administrador.mjs` e `functions/package.json` -- implementar processo operacional IAM/ADC que recebe UID somente em tempo de execução, usa-o apenas como chave do documento canônico de autoridade e retoma etapas pendentes de autoridade e claim; o UID nunca entra em recibos, outbox, logs ou código.
- [x] `firestore.rules`, `storage.rules` e `firebase.json` -- manter Firestore e Storage deny-by-default para escrita de domínio e configurar o conjunto de regras verificável no Emulator.
- [x] `flutter_app/lib/main.dart` e `flutter_app/lib/features/auth/auth_service.dart` -- obter/atualizar a autorização efetiva, ocultar ações não permitidas e entregar área administrativa inicial responsiva sem confiar em estado controlado pelo cliente.
- [x] `functions/test/`, `flutter_app/test/` e testes Emulator -- cobrir visitante, usuário comum, administrador, App Check/Auth ausentes, escrita direta negada, concessão/revogação auditável, replay, corrida/retomada de claim, script operacional e atualização/erro de autorização. (A suíte de Emulator permanece diferida: a CLI falha ao iniciar o Emulator neste ambiente; a cobertura executável no Emulator está registrada em `deferred-work.md`.)
- [x] `README.md` -- registrar a operação de provisionamento inicial aprovada, o nome da variável segura (sem valor), a configuração do link Firebase e comandos de verificação.

**Acceptance Criteria:**
- Given uma pessoa sem sessão, when tenta abrir superfície ou comando administrativo, then o sistema nega o acesso e não expõe dados administrativos.
- Given um administrador autenticado com papel emitido pelo backend, when abre a administração, then visualiza apenas as superfícies permitidas e o cliente não pode criar, alterar ou conceder a si próprio papel administrativo.
- Given uma operação administrativa crítica, when é solicitada pelo cliente, then uma Cloud Function valida autenticação e App Check antes de executar, and Firestore e Storage negam escrita direta de domínio.
- Given um papel administrativo é concedido ou revogado pelo caminho autorizado, when a operação conclui, then há auditoria correlacionada sem PII e as requisições subsequentes aplicam a autorização atualizada.
- Given o ambiente novo recebe o UID opaco de uma identidade Firebase Authentication existente apenas em tempo de execução, when o provisionamento privilegiado é executado, then somente essa conta recebe o papel administrativo inicial e o UID é usado apenas como chave do documento canônico, sem aparecer em logs, erros, auditoria ou código versionado.
- Given uma execução é interrompida entre etapas externas, when o operador a retoma, then o reconciliador avança somente a revisão ainda pendente e nunca reaplica uma claim histórica após revogação posterior.

## Implementation Notes

Loop de revisão 3: reaproveitada a autoridade canônica e o reconciliador por revisão do loop 2; aplicados patches de idempotência (recibo vinculado por `payloadHash`, replay sem efeito externo), resiliência do reconciliador (teto de tentativas, resultado verificado), bootstrap (resolução de dependências por `functions/node_modules`, retomada de documento inativo), validação de entrada, guarda de último administrador sobre autoridades válidas, e guarda administrativa Flutter (stateful, cache da consulta, retentativa acessível).

## Spec Change Log

- Loop de revisão 1 — a tentativa anterior persistia Firestore, Custom Claims e envio OOB como se fossem uma única transação. A identidade e a senha passaram a ser pré-requisito operacional já concluído; o plano usa autoridade canônica no Firestore, claim como projeção reconciliada por versão e processo IAM/ADC que recebe somente o UID em execução. Evita replays que ressuscitam privilégios e elimina envio OOB desta story. **KEEP:** manter App Check/Auth, `commandId`/versão, recibo/outbox sem PII, regras deny-by-default, guarda Flutter e documentação operacional.
- Loop de revisão 2 — a intenção permite o UID opaco somente como chave do documento canônico. A rederivação deve tratar a claim como projeção eventualmente reconciliada, preservar claims de outros domínios, registrar estado terminal/pendente e compensar escrita externa vencida por nova revisão. **KEEP:** o UID não entra em logs, erros, auditoria, recibos, outbox ou código; autoridade canônica continua sendo a única base de autorização de comando.

## Review Triage Log

| Origem | Achado | Veredito e evidência | Rota |
| --- | --- | --- | --- |
| edge-case | Falha ao sincronizar claim deixa autoridade/recibo concluídos | high — a transação persiste antes de `setCustomUserClaims`; uma falha externa é possível e a conclusão deixa de refletir a autorização efetiva. | bad_spec |
| edge-case | Replay após alteração oposta regrava claim obsoleta | high — o caminho idempotente retorna o resultado histórico e ainda executa `setCustomUserClaims`, podendo reverter uma revogação posterior. | patch |
| edge-case | Autoridade inativa no bootstrap diverge da claim | high — com documento existente inativo a transação não o reativa, mas a claim é concedida. | patch |
| edge-case | Falha de segredo/envio deixa privilégio parcial | high — a autoridade e a claim são persistidas antes do envio OOB; uma falha de configuração ou rede deixa bootstrap incompleto. | bad_spec |
| edge-case | Administrador pode revogar a si próprio | high — não há guarda para `alvoUid == uidAtor`, contrariando explicitamente o critério de aceitação. | patch |
| edge-case | Alvo inexistente é descoberto após a transação | high — `getUser` é chamado depois de gravar autoridade, recibo e outbox, portanto uma UID inválida deixa estado de domínio inválido. | patch |
| blind-hunter | Bootstrap cria conta sem privilégio depois de já provisionado | medium — a conta é criada antes da consulta de administrador ativo e permanece após a recusa. | patch |
| blind-hunter | Bootstrap repete envio de senha em chamadas posteriores | medium — autoridade existente da mesma conta passa pela transação e reenvia OOB, sem recibo terminal para impedir efeito externo repetido. | bad_spec |
| blind-hunter | Revogação do último administrador pode bloquear recuperação | medium — a função permite remover a última autoridade ativa; a regra de recuperação e de continuidade operacional não foi definida no contrato congelado. | intent_gap |
| blind-hunter | UI trata falha de refresh como negativa sem anúncio/retentativa | medium — `FutureBuilder` ignora `estado.hasError`, ocultando falha transitória como ausência de papel, em desacordo com o requisito de anunciar erro. | patch |
| blind-hunter | URL de continuação documentada não é enviada ao OOB | medium — o corpo de `sendOobCode` não contém `continueUrl`; o requisito demanda configuração do link, mas não define o contrato HTTP necessário. | bad_spec |
| verification-gap | Callables administrativas só têm teste textual | high — as buscas e o teste lido mostram apenas substrings; não há execução de Auth, App Check, transação, replay ou claim. | patch |
| verification-gap | Bootstrap não tem teste executável de endpoint | high — só há asserções textuais; nenhum teste observa primeira provisão, rejeição posterior ou ausência de parcial. | patch |
| verification-gap | Guarda administrativa não é widget-testada | medium — os testes Flutter exercitam somente o gateway fake, não os ramos `AreaAutenticada`/`Administracao`. | patch |
| verification-gap | Rules de Storage só são verificadas como texto | high — não há teste de Rules no Emulator para leitura/escrita autenticada ou anônima. | patch |
| edge-case | Reconciliação concorrente pode restaurar claim antiga | high — a revisão canônica pode mudar entre a última leitura e `setCustomUserClaims`; marcar a revisão falha, mas a claim externa permanece obsoleta. | bad_spec |
| edge-case | Escrita de claim apaga claims de outros domínios | high — `setCustomUserClaims` substitui o mapa inteiro sem preservar claims existentes. | patch |
| blind-hunter | Recibo fica pendente após claim concluída | medium — o estado externo não é refletido no recibo, dificultando retomada operacional auditável. | bad_spec |
| blind-hunter | Falhas transitórias de callable viram ausência de privilégio na UI | medium — exceções de rede/App Check são convertidas em `false`, sem acionar o retorno acessível. | patch |
| verification-gap | Callables, Rules e script não têm teste integrado executável | high — a suíte cobre contratos textuais e domínio puro; Emulator falha antes da execução. | patch |
| edge-case | UID como ID de documento contradiz a intenção congelada | intent_gap — a autoridade canônica deve relacionar a identidade Firebase, mas o texto aprovado proíbe o UID em documentos. | intent_gap |
| blind-hunter | Script de bootstrap importa `firebase-admin`, que só existe em `functions/node_modules` | high — verificado: não há `node_modules` na raiz, então `MODULE_NOT_FOUND`; o bootstrap documentado estava quebrado. | patch |
| blind-hunter | `principal().catch` engole o erro do provisionamento | low — real, porém intencional para não vazar o UID em mensagens de erro; corrigir adicionaria complexidade e risco de exposição. | rejeitado |
| blind-hunter | README omite `npm run build --prefix functions` antes do script | low — o script consome `functions/lib`, então a doc estava incompleta. | patch |
| blind-hunter | `actorUid` em `commands`/`auditOutbox` violaria a intenção congelada | false — o texto veda o UID de provisionamento (alvo), não o ator; a auditoria exige registrar o ator e nenhum UID de alvo é persistido. | rejeitado |
| blind-hunter | Replay não vincula o conteúdo do comando (`alvoUid`/`conceder`) | high — a matriz exige recusar “comando divergente”; o recibo não detectava divergência nem rejeitava. | patch |
| edge-case (carried) | Replay após alteração oposta reexecutava a projeção | carried high — o caminho `repetido` ainda chamava `setCustomUserClaims`; o mesmo patch agora encerra o replay sem efeito externo. | patch |
| blind-hunter / edge-case | Recursão do reconciliador sem limite | medium — concorrência sustentada recorria indefinidamente, sem teto de profundidade. | patch |
| blind-hunter | Resultado `false` do reconciliador era ignorado | medium — autoridade inexistente era marcada como concluída. | patch |
| blind-hunter | `serve` não incluía `storage` | low — o emulador local não carregava `storage.rules`. | patch |
| blind-hunter | `sprint-status` divergente do spec e `last_updated` só com data | low — marcava `in-progress` com spec `in-review` e quebrava o formato de data/hora. | patch |
| edge-case / blind-hunter | `request.data` nulo gerava `TypeError` | medium — erro interno em vez de `invalid-argument`. | patch |
| edge-case (carried) | Bootstrap com documento existente inativo reportava CONCLUIDO sem conceder | carried high — a retomada não reativava o documento nem recusava. | patch |
| edge-case | Revogar alvo inexistente/nunca-admin criava documento e auditoria espúrios | medium — faltava exigir autoridade ativa antes de revogar. | patch |
| edge-case | Contagem do último administrador incluía papel inválido | low — contava qualquer `ativa==true`, não só `podeAdministrar`. | patch |
| edge-case | `claimStatus` CONCLUIDA com revisão já alterada | low — janela estreita entre releitura e gravação do status. | patch |
| blind-hunter (carried) | UI convertia falha transitória em ausência sem retentativa | carried medium — o ramo de erro não oferecia ação de retentar. | patch |
| blind-hunter | `FutureBuilder` refazia a consulta de autorização a cada rebuild | medium — cada reconstrução refazia `getIdTokenResult(true)`. | patch |
| blind-hunter | `correlationId` sem validação | low — aceitava qualquer string e a copiava para recibo/outbox. | patch |
| blind-hunter | Agregado `autoridadesAdministrativas` não documentado | low — modelo de dados do README estava desatualizado. | patch |
| blind-hunter | `auditOutbox` sem consumidor/materializador | medium — crash após a transação não tem caminho automatizado para drenar a outbox nem finalizar a claim. | defer |
| blind-hunter | Nome da claim duplicado entre Dart e TypeScript | low — backend centralizado em `NOME_CLAIM_ADMINISTRATIVA`; o literal Dart permanece e requer contrato compartilhado. | defer |
| blind-hunter | Cliente usaria a claim e servidor o documento canônico | false — a claim é projeção reconciliada de forma síncrona no comando; o Design Notes já define isso explicitamente. | rejeitado |
| blind-hunter (carried) | TOCTOU do alvo entre validação e commit | low — exige excluir a conta Auth na janela; a releitura transacional não revalida existência. | defer |
| verification-gap | Ramos de `AreaAutenticada` sem teste de widget | medium — nenhum teste construía a guarda; agora coberta por `area_autenticada_test.dart`. | patch |
| verification-gap | Detecção da claim coberta apenas por fake que fixa `false` | medium — `FirebaseIdentidadeGateway` não era exercitado; agora há `claimAdministrativaAtiva` puro e testado. | patch |
| verification-gap (carried) | Callable/reconciliador/bootstrap/rules sem teste executável | high — contratos ampliados e testes de domínio adicionados; o restante depende de Emulator/Auth, que falha no ambiente e já está diferido. | defer |
| edge-case (carried) | Corrida de merge pode perder claims de outros domínios | medium — `setCustomUserClaims` substitui o mapa; a mitigação exigiria serialização da escrita de claims. | defer |

## Design Notes

O papel efetivo é um sinal de entrada, não uma autorização suficiente para mutações de domínio futuras: cada comando continuará validando vínculo, escopo, alvo, estado e tempo do servidor. A Story 1.1 estabelece esse ponto de controle e a superfície mínima; as stories seguintes dão conteúdo administrativo a ela.

## Verification

**Commands:**
- `flutter analyze --fatal-infos` -- esperado: aplicação e guarda administrativa sem diagnósticos.
- `flutter test` -- esperado: autenticação, guarda e semântica da área administrativa aprovadas.
- `npm test --prefix functions` -- esperado: contratos de Function, autorização, idempotência e redaction aprovados.
- `npm run build --prefix functions` -- esperado: TypeScript compila para deploy.
- `firebase emulators:exec --only firestore,storage,functions "npm test --prefix functions"` -- esperado: Rules e callables recusam os caminhos não autorizados no Emulator.

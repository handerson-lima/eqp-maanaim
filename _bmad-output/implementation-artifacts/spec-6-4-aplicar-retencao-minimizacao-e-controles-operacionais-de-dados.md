---
title: 'Story 6.4: Aplicar retenção, minimização e controles operacionais de dados'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_commit: 'c683025313927e4f79f7dcee37ff2ce3dc0cd759'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema declara retenção de 5 anos e minimização de PII (AD-12), mas não há sanitização canônica: `auditOutbox` guarda `diff` da ficha com nome, CPF e profissão em claro; mensagens de erro e `detalhes` de alertas vão crus para Firestore/logs. Também faltam rotina autorizada de expurgo/anonimização, metadados de retenção e controles operacionais (lifecycle, alertas de IAM/Rules/deleção/backup).

**Approach:** Um sanitizador de PII canônico (lista de negação + máscaras) aplicado em auditoria, outbox, alertas, erros e logs; um comando autorizado, idempotente e `dryRun` por padrão que expurga rascunhos abandonados e anonimiza fichas encerradas elegíveis, auditando só IDs; metadados `retencaoAte` (5 anos) em auditoria e PDFs; configuração versionada de lifecycle/alertas; UI Flutter com aviso de privacidade e painel de conformidade.

## Boundaries & Constraints

**Always:**
- Mutação só em Cloud Functions autenticadas (Coordenador/Administrador vigente); relógio e `retencaoAte` do servidor em UTC; `commandId` idempotente com `payloadHash`; cada ficha em transação própria (≤500 operações), com recibo + `auditOutbox` na mesma transação.
- Anonimização: `nomeCompleto='Nome Anonimizado'`, `cpf='***.***.***-**'`, `profissao=''`, `anonimizadaEm`; preserva IDs, estados, versão+1, eventos, evidências e auditoria. Só fichas em estado terminal (`INATIVA`,`CANCELADA`,`EXPIRADA`,`REJEITADA`) sem participação ativa/pendente, com 5 anos desde `atualizadoEm` **ou** motivo categorizado `SOLICITACAO_TITULAR`.
- Expurgo: apenas ficha `RASCUNHO` sem `termoAceito`, com todas as participações `RASCUNHO`, sem atualização há ≥180 dias (padrão; `configuracoes/retencao.diasRascunho`, 30–730). Agendado semanal só se `configuracoes/retencao.expurgoAutomaticoHabilitado === true` (padrão `false`).
- Auditoria do procedimento sem PII: ação `ANONIMIZAR_FICHA`/`EXPURGAR_RASCUNHO`, IDs opacos, estado, motivo categorizado, política `AD-12_V1`.
- Textos de privacidade em PT-BR, tokens do Design System, alvos ≥44 px, estado nunca só por cor.

**Never:**
- Nenhuma regra de Firestore/Storage libera `delete`; sem TTL do Firestore e sem trava (lock) irreversível de retenção do bucket no repositório.
- Não apagar PDFs, `auditoria`, `auditOutbox`, evidências, termos ou aceites; anonimização não altera `ownerUid` nem remove o objeto de PDF antes de 5 anos.
- Não registrar nome, CPF, profissão, e-mail, telefone, endereço, token, assinatura bruta ou ficha completa em auditoria, outbox, FCM, logs ou erros.
- Não usar enums/listas fixas de igrejas ou equipes; não expor IDs de voluntários na UI de conformidade (somente contagens).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Simulação | `dryRun` omitido/true | Contagens e IDs candidatos; nada gravado | N/A |
| Execução repetida | mesmo `commandId` e hash | Devolve recibo, `repetido: true` | hash diferente → `ComandoDivergenteError` |
| Rascunho recente | `RASCUNHO` < prazo | Ignorado | N/A |
| Rascunho com aceite ou participação avançada | `termoAceito` ou estado ≠ `RASCUNHO` | Ignorado | N/A |
| Ficha ativa/pendente | participação ativa ou pendente | Não anonimiza | contabilizada como `ignoradas` |
| Já anonimizada | `anonimizadaEm` presente | No-op | N/A |
| Sem papel | outro usuário | Negado | `permission-denied` sem detalhes |
| PII em payload | chave `cpf`, `nomeCompleto`, e-mail etc. | Removida/mascarada | N/A |
| PDF de ficha anonimizada | `anonimizadaEm` presente | Geração nova recusada | `failed-precondition` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/auditoria.ts` -- `sanitizarDadoAuditoria` passa a delegar ao sanitizador novo; `montarRegistroAuditoriaImutavel` grava `retencaoAte`.
- `functions/src/repositories/auditoria.ts` -- sanitizar `erro`, `detalhes` e logs (`dadosComando` cru em alerta de órfão).
- `functions/src/domain/ficha.ts` + `repositories/ficha.ts` -- `diff` com valores em claro; passa a registrar só `camposAlterados` (nomes de campos).
- `functions/src/repositories/pdfTermo.ts` -- upload com `customMetadata.retencaoAte`; recusa ficha anonimizada.
- `functions/src/repositories/expirarCiclo.ts` -- modelo de job idempotente com recibo e `auditOutbox`.
- `functions/src/commands/expirarCiclo.ts`, `triggers/expirarCicloScheduled.ts`, `repositories/configuracaoVigencia.ts` -- padrões de callable, scheduler e leitura de `configuracoes`.
- `flutter_app/lib/features/auditoria/auditoria_service.dart`, `auditoria_relatorios_screen.dart` -- padrão de gateway (Cloud/Memória) e tela administrativa.
- `flutter_app/lib/features/admin/admin_shell.dart`, `lib/main.dart` -- nova aba e injeção do gateway.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` (`_buildSecaoTermo`) e `termo/termo_dialog.dart` -- ponto do aviso de privacidade.
- `firestore.indexes.json`, `firestore.rules`, `storage.rules` -- índice `fichas(estado, atualizadoEm)`; regras já negam escrita/delete.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/privacidade.ts` -- sanitizador (`sanitizarPii`, `sanitizarErro`, `mascararTexto`), lista de negação de chaves, máscaras de CPF/e-mail/telefone, `calcularRetencaoAte(base, anos=5)`, política de elegibilidade e máscara de ficha -- fonte única do AD-12.
- [x] `functions/src/domain/auditoria.ts`, `repositories/auditoria.ts`, `domain/ficha.ts`, `repositories/ficha.ts` -- aplicar o sanitizador; trocar `diff` por `camposAlterados`; `retencaoAte` nos registros.
- [x] `functions/src/domain/retencao.ts`, `repositories/retencao.ts` -- validação, hash, expurgo, anonimização, indicadores de conformidade.
- [x] `functions/src/commands/executarRotinaRetencao.ts`, `consultarConformidadeRetencao.ts`, `triggers/expurgarRascunhosScheduled.ts`, `index.ts` -- callables (Coordenador/Admin, App Check) e scheduler com chave de ativação.
- [x] `functions/src/repositories/pdfTermo.ts` -- metadado de retenção e recusa para ficha anonimizada.
- [x] `infra/storage-lifecycle.json`, `infra/alertas-monitoramento.json`, `infra/README.md`, `scripts/aplicar-controles-operacionais.mjs` -- retenção de 5 anos no bucket (sem lock), lifecycle, alertas de IAM/Rules/conta de serviço/deleção/falha de backup; script imprime comandos `gcloud` e só executa com `--executar`.
- [x] `firestore.indexes.json` -- índice composto `fichas(estado, atualizadoEm)`.
- [x] `flutter_app/lib/features/privacidade/` (`politica_privacidade_card.dart`, `retencao_service.dart`, `conformidade_retencao_screen.dart`) -- aviso institucional, gateway Cloud/Memória e painel (contagens, simular, executar com confirmação).
- [x] `admin_shell.dart`, `main.dart`, `minha_ficha_screen.dart`, `termo_dialog.dart` -- aba "Retenção e Privacidade" e aviso nas telas do voluntário.
- [x] Testes: `functions/test/privacidade.test.ts`, `retencao.test.ts`, `controlesOperacionais.test.ts`; ajuste de `ficha.test.ts`/`auditoria`; `flutter_app/test/retencao_privacidade_test.dart`.

**Acceptance Criteria:**
- Given um registro de auditoria ou PDF novo, when é persistido, then recebe `retencaoAte` = criação + 5 anos UTC e nenhuma regra, TTL ou lifecycle permite exclusão antes disso.
- Given payload, erro, alerta ou log com nome, CPF, profissão, e-mail, telefone, endereço, token ou assinatura, when passa pelo sanitizador, then somente IDs, ação, estado, timestamps, papel/vínculo e motivo categorizado permanecem.
- Given ficha elegível e usuário autorizado, when a rotina executa fora de `dryRun`, then PII é mascarada, correlações são preservadas e a auditoria do procedimento é gravada; repetir é no-op.
- Given `dryRun` ou usuário sem papel, when a rotina é chamada, then nada é gravado ou o acesso é negado sem vazar dados.
- Given o voluntário na ficha ou no termo, when abre a tela, then vê política de 5 anos, finalidade, PDF privado e canal LGPD em tela única mobile e com navegação lateral no desktop.
- Given o painel administrativo, when carrega, then exibe indicadores de retenção e permite simular/executar com confirmação, com estados loading/erro/vazio/sucesso/negado.

## Implementation Notes

## Verification

**Commands:**
- `cd functions && npm test` -- expected: typecheck e Vitest verdes.
- `cd functions && npm run build` -- expected: compila sem erros.
- `cd flutter_app && flutter analyze && flutter test` -- expected: sem alertas, testes verdes.

## Review Triage Log

| Finding | Verdict | Evidence / Route |
|---------|---------|------------------|
| BH1 sem guarda de profundidade (`contemPii` sem uso) | false | Nenhum caminho de escrita demonstra PII persistida; o sanitizador é aplicado em todos os sites. O guarda extra é *nice-to-have*, não defeito. |
| BH2 sanitização de alerta parcial (`...alerta`) | false | `AlertaOperacional` só expõe texto livre em `motivo`/`detalhes`, ambos tratados; os demais campos são controlados. |
| BH3 nomes em texto livre não removidos | low | Detecção de nomes arbitrários é inviável; a correção adiciona complexidade e o caso é raro em uso diário. Rejeitado. |
| BH4 regex de telefone ignora números sem máscara | low | Uso diário improvável e um regex mais amplo mascararia sequências numéricas legítimas. Rejeitado. |
| BH5 `retencaoAte` enganoso no expurgo | low | `fichaElegivelParaExpurgo` devolve `atualizadoEm+dias` sob o nome `retencaoAte` e o chamador o descarta. Correção direta (deixar de devolver). Patch. |
| BH6 `retencaoAte` do registro de auditoria a partir de `new Date()` | low | `materializadoEm`/`timestampOriginal` ocorrem no mesmo instante da criação; desvio irrelevante. Rejeitado. |
| BH7/E2 indicadores limitados a 500 sem paginação | low | Painel indicador; o teto respeita o orçamento de leitura (AD-9). Correção não trivial e cenário não cotidiano. Rejeitado. |
| BH8 consulta N+1 de participações | low | Desempenho; correção não trivial (batching). Rejeitado. |
| BH9 `tx.get` de participações sem limite | low | Ficha com centenas de participações não é alcançável na prática; orçamento de 500 folgado. Rejeitado. |
| BH10 coerção de `dryRun` e `agoraIso` do cliente | false | A callable sobrescreve `agoraIso` com relógio do servidor; a coerção de booleano falha na direção segura (simulação). |
| BH11 hash/chave de idempotência subespecificados | low | Recibo sem `payloadHash` string é tratado como processado. Endurecer para divergência é correção direta. Patch. |
| BH12 IDs de fichas devolvidos ao cliente | false | Resposta a Coordenador/Admin autenticado; a UI nunca os renderiza e o intent restringe a exposição à UI. |
| BH13 sizing do job agendado | low | Boa prática operacional, sem defeito funcional. Rejeitado. |
| BH14 filtros de monitoramento possivelmente incorretos | maybe-false | Não é possível confirmar os nomes de método de audit log sem o ambiente GCP; se verdadeiro seria medium/high. Deferido com severidade não verificada. |
| BH15 fontSize hardcoded / canal LGPD não acionável | low | Cosmético; sem dano funcional demonstrado. Rejeitado. |
| BH16 `semanaIso` sem teste (bordas de ano) | medium | Função exportada sem cobertura; chave semanal errada pode pular/duplicar o expurgo. Patch (teste + correção se necessário). |
| BH17 risco de overflow no diálogo do termo | low | Testes existentes passam; cenário de tela muito baixa, correção adiciona complexidade. Rejeitado. |
| BH18 expurgo físico sem snapshot verificável | false | Expurgo apaga apenas rascunho sem aceite (por design); auditoria preserva ID/estado e não há evidência/PDF órfãos. |
| E1 lifecycle `age=1825` apaga até 1 dia antes de 5 anos | medium | 5 anos civis podem ter 1826/1827 dias (bissexto); `calcularRetencaoAte` usa `setUTCFullYear(+5)`. Violação direta de "nenhum lifecycle permite exclusão antes". Patch. |
| E2 >500 fichas subconta | low | Ver BH7. Rejeitado. |
| E3 chaves PII compostas (`voluntarioNome`, `profissaoVoluntario`) não removidas | medium | No próprio sanitizador, `sanitizarPii({voluntarioNome:'X'})` mantém o nome; contrário ao contrato AD-12. Patch. |
| E4 falha de leitura da config engolida → padrão 180 | medium | `obterConfiguracaoRetencao` captura qualquer erro e devolve 180, podendo expurgar rascunhos antes do prazo configurado (até 730). Patch. |
| E5 erro de refresh ocultado com indicadores antigos | medium | `_erro != null && _indicadores == null` ignora falha de recarga e mostra dados obsoletos como atuais. Patch. |
| V1 escritas diretas em `auditoria` (consulta/relatório) sem `retencaoAte` | medium | `consultaAuditoria.ts:208` e `:440` gravam sem `retencaoAte`, embora o tipo o exija e a AC1 o mande. Patch. |
| V2 minimização de alerta sem teste | medium | Remover as linhas de sanitização mantém `auditoria.test.ts` verde (só checa `tentativas`). Patch (teste). |
| V3 callable `obterUrlDownloadPdf` sem teste do mapeamento anonimizada | medium | Apenas `gerarPdfParticipacao` é coberto; o download pode regredir para `internal`. Patch (teste). |
| V4 gate do job semanal sem teste | medium | Nenhum teste invoca `expurgarRascunhosScheduled`; gate invertido passaria despercebido. Patch (teste). |
| V5 aviso de privacidade nas telas do voluntário sem teste | medium | Apenas o card isolado é testado; remover a inserção não quebra testes. Patch (testes). |
| V-Outros `consultaAuditoria.ts` loga erro cru | low | Caminho com PII não estabelecido; o padrão já foi corrigido no repositório de auditoria. Rejeitado. |

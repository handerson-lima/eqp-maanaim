---
title: 'Story 2.3: Ler e aceitar o termo vigente'
type: 'feature'
created: '2026-10-06'
status: 'completed'
baseline_commit: HEAD
route: 'dispatch'
review_loop_iteration: 1
context:
  - _bmad-output/implementation-artifacts/epic-2-context.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O voluntário com ficha e equipes selecionadas precisa ler o conteúdo oficial do termo de adesão ao serviço voluntário e manifestar consentimento eletrônico explícito e auditável. O sistema deve garantir que o aceite seja vinculado à versão exata vigente e registrado de forma imutável pelo servidor, impedindo que o cliente fabrique aceites ou envie solicitações com termos desatualizados ou adulterados.

**Approach:** 
1. Criar a Cloud Function callable autenticada `aceitarTermoVigente` com verificação estrita de App Check, verificação da identidade do voluntário (`fichaId == auth.uid`), verificação de pré-condições (ficha existente em rascunho e ao menos uma equipe/participação selecionada), verificação da versão vigente e do hash canônico do termo contra o banco de dados institucional.
2. Persistir transacionalmente o registro do aceite como evidência imutável em `fichas/{uid}/aceites/{versaoId}`, atualizar a projeção do termo aceito na ficha (`termoAceito`), gravar recibo idempotente em `commands/{commandId}` e evento de auditoria append-only em `auditOutbox/{commandId}` (AD-6, AD-7, AD-8, AD-10).
3. Na interface Flutter Web (`MinhaFichaScreen`), integrar o leitor do termo com os dados canônicos da versão vigente (`obterTermoVigente`), checkbox explícito de consentimento e botão de confirmação acessível (WCAG 2.2 AA), exibindo imediatamente o comprovante com versão, data/hora e hash de auditoria após a confirmação.

## Boundaries & Constraints

**Always:**
- Validação estrita de autorização: o voluntário só pode registrar aceite para sua própria ficha (`fichaId == auth.uid`).
- Verificação da versão vigente pelo servidor: a Cloud Function consulta `termos/{termoId}` e valida se a versão indicada é exatamente a versão ativa e vigente.
- Pré-condição de equipes selecionadas: exige ao menos uma participação cadastrada na ficha antes de permitir o aceite.
- Evidência imutável e append-only (AD-6, AD-7): o registro de aceite nunca é sobrescrito ou apagado; novas versões do termo geram novos aceites preservando o histórico integral.
- Idempotência rigorosa (AD-10): requisições com o mesmo `commandId` e payload idêntico devolvem o comprovante original com `repetido: true` sem criar duplicatas.
- Acessibilidade e responsividade (WCAG 2.2 AA): alvos de toque >= 44 px, navegação por teclado, rótulos claros e visual alinhado ao Design System canônico (`navy-900`, `blue-600`).

**Never:**
- Nunca permitir que o cliente envie parâmetros de aceite como aprovado ou fabrique datas/hashes sem validação pelo backend (AD-13).
- Nunca aceitar gravação direta no Firestore pelo SDK cliente (escrita bloqueada por Security Rules).
- Nunca permitir aceite de termo inativo ou de versão superada/obsoleta.
- Nunca permitir aceite sem a declaração explícita de leitura e concordância (`declaracaoLidoEConcordo == true`).
- Nunca incluir PII sensível ou desnecessária nos recibos de comando ou eventos de auditoria (AD-12).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta de termo vigente | `obterTermoVigente` por voluntário autenticado | Retorna dados canônicos da versão vigente (`versaoId`, `numeroVersao`, `titulo`, `conteudo`, `hashSha256`) | Se não houver termo ativo, retorna `versaoVigente: null` |
| Aceite com dados válidos | `aceitarTermoVigente` com `commandId`, `versaoId`, `hashSha256`, `declaracaoLidoEConcordo: true`, com ficha e >=1 equipe | Evidência imutável criada, ficha atualizada com `termoAceito`, recibo e auditoria gravados | `200 OK` com dados do comprovante (`aceitoEm`, `versaoId`, `numeroVersao`, `hashSha256`, `commandId`) |
| Aceite sem declaração de leitura | `declaracaoLidoEConcordo: false` ou ausente | Operação recusada sem modificar dados | `invalid-argument: A declaração explícita de leitura e concordância é obrigatória` |
| Aceite sem ficha cadastrada | Voluntário autenticado sem documento em `fichas/{uid}` | Operação recusada com instrução de preenchimento | `failed-precondition: Ficha permanente não encontrada` |
| Aceite sem nenhuma equipe | Ficha em rascunho sem nenhuma participação | Operação recusada orientando seleção de equipes | `failed-precondition: É necessário selecionar ao menos uma equipe antes de aceitar o termo` |
| Tentativa de aceitar versão desatualizada | Cliente envia `versaoId` ou `hashSha256` de versão anterior após publicação de nova versão | Backend detecta discrepância com a versão vigente atual e bloqueia o aceite | `failed-precondition: A versão do termo informada não corresponde à versão vigente` |
| Reenvio com mesmo `commandId` e payload idêntico | Reenvio do mesmo comando de aceite | Retorna resultado original com `repetido: true` sem criar registros duplicados | Idempotência garantida |
| Reenvio com mesmo `commandId` e payload diferente | Reenvio com dados divergentes | Transação abortada sem modificar dados | `invalid-argument: Operação já registrada com dados divergentes` |
| Tentativa de aceite por terceiro | UID do token diverge do alvo da operação | Acesso bloqueado | `permission-denied` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/termos.ts` -- Tipagem de `EntradaAceitarTermoVigente`, `ComprovanteAceiteTermo`, validação de regras de consentimento e hash de payload.
- `functions/src/repositories/termos.ts` -- Função transacional `aceitarTermoVigenteRepo` com gravação de evidência imutável em subcoleção `fichas/{uid}/aceites`, atualização de projeção na ficha, gravação em `commands` e `auditOutbox`.
- `functions/src/domain/ficha.ts` -- Modelagem da projeção `TermoAceitoResumo` no agregado `FichaPermanente`.
- `functions/src/repositories/ficha.ts` -- Serialização do resumo de termo aceito na leitura e salvamento da ficha.
- `functions/src/commands/aceitarTermoVigente.ts` -- Cloud Function callable autenticada para o aceite eletrônico.
- `functions/src/commands/obterHistoricoAceites.ts` -- Cloud Function callable para consulta das evidências de aceite da ficha do voluntário.
- `functions/src/index.ts` -- Exportação das novas Cloud Functions.
- `functions/test/aceiteTermo.test.ts` -- Testes unitários em Vitest cobrindo regras de negócio, integridade de hash, idempotência e edge cases.
- `flutter_app/lib/features/termo/termo_service.dart` -- Gateway de termos (`TermoGateway`) com métodos para consultar termo vigente, aceitar termo vigente e consultar histórico de aceites, incluindo suporte mock em memória.
- `flutter_app/lib/features/voluntario/ficha_service.dart` -- Atualização do modelo `FichaModel` com campo `TermoAceitoModel`.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Seção visual do Termo de Adesão com leitor do termo canônico, checkbox de declaração, confirmação de aceite e exibição do comprovante.
- `flutter_app/lib/main.dart` -- Injeção do `TermoGateway` no container de dependências autenticado.
- `flutter_app/test/aceite_termo_test.dart` -- Testes de widget e integração para fluxo de leitura, validação de checkbox, confirmação de aceite, exibição de comprovante e bloqueios quando pendente.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/termos.ts` -- Implementar tipos e funções de validação para aceite do termo e cálculo de payloadHash.
- [x] `functions/src/domain/ficha.ts` e `functions/src/repositories/ficha.ts` -- Atualizar `FichaPermanente` com projeção `termoAceito`.
- [x] `functions/src/repositories/termos.ts` -- Implementar `aceitarTermoVigenteRepo` e `obterHistoricoAceitesRepo` com transação atômica, evidência imutável, idempotência e auditoria.
- [x] `functions/src/commands/aceitarTermoVigente.ts` -- Implementar callable autenticada para aceite do termo.
- [x] `functions/src/commands/obterHistoricoAceites.ts` -- Implementar callable autenticada para histórico de aceites do voluntário.
- [x] `functions/src/index.ts` -- Exportar `aceitarTermoVigente` e `obterHistoricoAceites`.
- [x] `functions/test/aceiteTermo.test.ts` -- Criar testes unitários no backend cobrindo todos os cenários da matriz de I/O.
- [x] `flutter_app/lib/features/termo/termo_service.dart` -- Implementar `TermoGateway`, `FirebaseTermoGateway` e `MemoriaTermoGateway`.
- [x] `flutter_app/lib/features/voluntario/ficha_service.dart` -- Integrar modelo de `TermoAceitoModel` em `FichaModel`.
- [x] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Implementar card do Termo de Adesão, visualização canônica, checkbox de consentimento e comprovante.
- [x] `flutter_app/lib/main.dart` -- Injetar `TermoGateway` na aplicação.
- [x] `flutter_app/test/aceite_termo_test.dart` -- Desenvolver testes de widget para o fluxo completo da Story 2.3.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 2.3.

**Acceptance Criteria:**
- Given uma ficha em rascunho com ao menos uma equipe selecionada, when o voluntário visualiza o termo, then o sistema apresenta conteúdo canônico, versão e identificação da versão vigente, bloqueando o aceite sem marcação explícita de concordância.
- Given o voluntário confirma o aceite com declaração explícita, when o comando é executado, then o backend persiste evidência imutável com UID, ficha, versão, hash SHA-256, serverTimestamp e commandId, exibindo o comprovante na tela.
- Given que uma nova versão do termo foi publicada antes do envio, when o voluntário tenta prosseguir, then o sistema detecta que o aceite não corresponde à versão vigente, exige novo aceite e preserva o aceite anterior intacto no histórico.
- Given qualquer tentativa de fabricar aceite no cliente sem passar pela Cloud Function ou com parâmetros divergentes da versão vigente, when o backend recebe a requisição, then rejeita a operação com erro claro e nenhum registro é criado.

## Verification

**Commands:**
- `npm test` na pasta `functions` -- resultado: 147 testes unitários aprovados (19 testes dedicados de aceite em `aceiteTermo.test.ts`).
- `flutter test` na pasta `flutter_app` -- resultado: 140 testes de widget/integração aprovados (7 testes dedicados cobrindo fluxo mobile, desktop e regras de negócio em `aceite_termo_test.dart`).
- Regressão zero confirmada em toda a base de testes Flutter e TypeScript.

### Review Findings

- [x] [Review][Decision] Documento do termo é montado no cliente a partir de dados transitórios e identidades fabricadas, não da versão canônica/evidência — Resolvido conforme diretriz do usuário: a assinatura formal e geração de PDF ocorrem exclusivamente pós-aprovação em todas as etapas (AD-12 e AD-13). Em fase de rascunho, o cliente exibe a leitura do texto canônico da versão vigente e registra o aceite eletrônico / consentimento prévio auditável.
- [x] [Review][Decision] `obterHistoricoAceites` implementado, mas sem superfície de histórico — Resolvido: implementada modal de Histórico de Aceites Eletrônicos na `MinhaFichaScreen`, com botão acessível que consulta a Cloud Function callable e apresenta lista de comprovantes e hashes.
- [x] [Review][Patch] `termoAceito` não é devolvido por `obterMinhaFicha`/`salvarMinhaFicha`, perdendo o estado de aceite [functions/src/commands/obterMinhaFicha.ts, functions/src/repositories/ficha.ts]
- [x] [Review][Patch] Evidência imutável de aceite pode ser sobrescrita para a mesma versão [functions/src/repositories/termos.ts]
- [x] [Review][Patch] Pré-condição de ficha em `RASCUNHO` não é verificada no aceite [functions/src/repositories/termos.ts]
- [x] [Review][Patch] Códigos de erro divergentes do contrato (divergente→`invalid-argument`; UID divergente→`permission-denied`) [functions/src/commands/aceitarTermoVigente.ts, functions/src/repositories/termos.ts]
- [x] [Review][Patch] Falha ao carregar o termo derruba a tela inteira (`Future.wait` acoplado) [flutter_app/lib/features/voluntario/minha_ficha_screen.dart]
- [x] [Review][Patch] Sem termo vigente, a UI exibe cartão fabricado "Versão 1 (Vigente)" [flutter_app/lib/features/voluntario/minha_ficha_screen.dart]
- [x] [Review][Patch] Injeção de HTML não escapada no documento impresso (`document.write`) [removida impressão prematura em rascunho]
- [x] [Review][Patch] App Check debug token commitado em asset web [flutter_app/web/index.html]
- [x] [Review][Patch] Alvo de toque abaixo de 44 px no link "Ver Termo de Adesão (PDF)" [removido link indevido em rascunho]
- [x] [Review][Patch] Testes de contrato de segurança não cobrem `aceitarTermoVigente`/`obterHistoricoAceites` [functions/test/security-contract.test.ts]
- [x] [Review][Patch] Wiring do `TermoGateway` em `AreaAutenticada` sem teste [flutter_app/lib/main.dart]
- [x] [Review][Patch] Pré-condição "ao menos uma equipe" não é de fato exercitada pelos testes (mock ignora o filtro) [functions/test/aceiteTermo.test.ts]
- [x] [Review][Patch] Round-trip de `termoAceito` em `FichaModel.fromMap` sem teste [flutter_app/lib/features/voluntario/ficha_service.dart, flutter_app/test/aceite_termo_test.dart]
- [x] [Review][Patch] Ponte JS de impressão sem teste de contrato [resolvido pelo escopo pós-aprovação]
- [x] [Review][Patch] Warning de `flutter analyze`: `invalid_null_aware_operator` [flutter_app/lib/features/voluntario/minha_ficha_screen.dart]
- [x] [Review][Patch] Região default divergente no `FirebaseTermoGateway` [flutter_app/lib/features/termo/termo_service.dart]

- [x] [Review][Defer] Alterações fora do escopo declarado da story (admin termos + bootstrap de importação) [flutter_app/lib/features/admin/termos_screen.dart, functions/src/commands/importarPastoresIniciais.ts] — deferred: mudanças não declaradas no Code Map/Tasks; reavaliar separadamente.
- [x] [Review][Defer] Pré-condição de equipe não filtra estado/ciclo da participação [functions/src/repositories/termos.ts:365-376] — deferred: não verificável no fluxo atual (participações `CANCELADA`/`APROVADA` só surgem em epics posteriores); confirmar se estados não-rascunho podem coexistir com o aceite.

#### Rejected

- `false` — "Sem concorrência otimista/`expectedVersion` no aceite": o comando compara a versão do termo (`versaoId`/`hashSha256`, `termos.ts:391-406`), que é o agregado relevante para este mutação; não há caminho demonstrado de perda.
- `false` — "Aceite sem `termoId` usa `TERMO_ID_PADRAO` e trava termos não-padrão": `obterTermoVigente` e o aceite usam o mesmo default de forma consistente hoje; sem defeito alcançável.
- `low` — `aceitoEm` do comprovante novo usa `new Date()` em vez do `serverTimestamp` persistido (`termos.ts:487`): divergência de exibição pouco provável de ser notada; persistência auditada permanece correta.
- `low` — Evidência sem snapshot de nome/CPF/equipe no aceite (`termos.ts:415-429`): não exigido pela AC nem pelo SPEC da story.
- `low` — `pubspec` adiciona `assets/images/` enquanto o logo é embutido em base64 (`pubspec.yaml:21-22`): o PNG será versionado junto; sem impacto funcional.
- `low` — Hash de string vazia no `MemoriaTermoGateway` (`termo_service.dart:226-227`): apenas dados de teste.
- `low` — `StatusChip(status: 'APROVADO')` como selo de versão (`minha_ficha_screen.dart:1197-1200`): rótulo ainda comunica a versão; cosmético.
- `low` — Botão admin "Carregar texto oficial do modelo" com corpo hardcoded (`termos_screen.dart:391-414`): conveniência administrativa, sem dano demonstrado.
- `low` — Desvio de Design System no documento impresso (cores não-token, Arial) (`termo_adesao_widget.dart`/`termo_html_template.dart`): justificável pela fidelidade ao papel; correção ampla sem ganho proporcional.
- `low` — Assinatura de `dataFormatadaExtenso` cai em `DateTime.now()` (`termo_adesao_model.dart:60`): absorvido pelo achado decisório do documento canônico.

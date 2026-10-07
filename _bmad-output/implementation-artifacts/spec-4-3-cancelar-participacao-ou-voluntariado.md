---
title: 'Story 4.3: Cancelar participação ou voluntariado'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_commit: HEAD
route: 'dispatch'
review_loop_iteration: 1
context:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
Voluntários ou lideranças autorizadas (Pastor Local, Responsável de Equipe, Coordenador Geral) necessitam encerrar participações específicas em equipes ou o vínculo integral de voluntariado da ficha permanente.
No entanto, esse processo não pode apagar o histórico de serviços, deliberações anteriores ou auditoria, e deve obedecer estritamente aos princípios de isolamento de agregados, segregação de autoridade e sigilo pastoral:
1. **Dois Níveis Distintos de Cancelamento (AD-1, AD-4, AD-11):**
   - **Nível 1: `cancelarParticipacao` (Individual):** Cancela uma participação específica (`participacoes/{participacaoId}`). As demais participações ativas permanecem intocadas e o histórico permanece somente-leitura.
   - **Nível 2: `cancelarVoluntariado` (Geral):** Cancela todas as participações não terminais do voluntário e encerra a ficha permanente (`fichas/{uid}`).
2. **Autoridade e Segregação em Runtime (AD-2, AD-11):**
   - `cancelarParticipacao`: Pode ser invocado pelo próprio voluntário titular, pelo Pastor Local com vínculo vigente na igreja do voluntário, pelo Responsável de Equipe com vínculo vigente na equipe da participação, ou pelo Coordenador Geral.
   - `cancelarVoluntariado`: Pode ser invocado pelo próprio voluntário titular, pelo Pastor Local com vínculo vigente na igreja do voluntário, ou pelo Coordenador Geral.
   - *Invariante:* Responsável de Equipe NÃO tem autoridade para cancelar toda a ficha (tentativas são rejeitadas com `permission-denied`).
3. **Regra de Redução de Estados da Ficha (AD-11):**
   - Ao cancelar uma participação: se o voluntário mantiver ao menos uma outra participação ativa (`ATIVA`), a ficha permanece `ATIVA`.
   - Se for a última participação ativa cancelada e não houver nenhuma outra participação ativa: a ficha transiciona para `INATIVA`.
   - Ao cancelar o voluntariado geral: todas as participações não terminais passam para `CANCELADA` e a ficha transiciona para `CANCELADA`.
4. **Sigilo Pastoral e Mensagem Neutra Canônica (AD-12, FR28):**
   - Se o cancelamento for solicitado pelo próprio voluntário titular: recebe confirmação comum no frontend com o alvo cancelado.
   - Se o cancelamento for deliberado por liderança (Pastor Local, Responsável de Equipe ou Coordenador): exige justificativa interna no backend para auditoria/evidência, mas na visualização do voluntário (timeline, status, notificações) a mensagem é ESTRITAMENTE a mensagem neutra canônica:
     `"Procure o Pastor da igreja local para mais informações"`
     Sem vazar motivo, ator deliberador ou qualquer menção a "rejeitado".
5. **Idempotência, Evidência e Trilha de Auditoria Append-Only (AD-8, AD-10, AD-12):**
   - Comandos com `commandId` único, `payloadHash` SHA-256 verificado em `commands/{commandId}`.
   - Evidência imutável persistida em `evidenciasDecisao/{commandId}`.
   - Evento de auditoria em `auditOutbox/{commandId}` com snapshot de papéis sem PII confidencial.
   - Execução atômica e estrita em Firestore Transaction no backend (Cloud Functions v2). Nenhuma escrita direta pelo cliente Flutter.
6. **Experiência do Usuário e Acessibilidade (Sally - WCAG 2.2 AA):**
   - Diálogos/modais de confirmação explícita com alto contraste (`danger: #EF4444`, `danger-bg: #FDECEC`, `navy-900`).
   - Apresentação prévia dos itens afetados antes da confirmação do cancelamento total.
   - Campo obrigatório de justificativa interna quando a ação for executada por liderança.
   - Alvos de toque >= 44px, feedback semântico não dependente exclusivamente de cor e foco acessível.

**Approach:**
1. **Backend (Cloud Functions TypeScript - Winston & Amelia):**
   - **Módulo de Domínio (`functions/src/domain/cancelarParticipacao.ts`):**
     * Tipos, contratos e validações de input (`commandId`, `participacaoId`, `motivo`).
     * Hashing determinístico do payload via SHA-256.
     * Erros canônicos de domínio (`ParticipacaoNaoEncontradaError`, `ParticipacaoJaTerminalError`, `AutoridadeInsuficienteError`, `MotivoObrigatorioLiderancaError`, `ComandoDivergenteError`).
   - **Módulo de Domínio (`functions/src/domain/cancelarVoluntariado.ts`):**
     * Tipos, contratos e validações de input (`commandId`, `fichaId`, `motivo`).
     * Erros canônicos de domínio (`FichaNaoEncontradaError`, `FichaJaCanceladaError`, `AutoridadeInsuficienteError`, `MotivoObrigatorioLiderancaError`).
   - **Repositório Transacional (`functions/src/repositories/cancelamento.ts`):**
     * `executarCancelarParticipacao`: Transação Firestore atômica:
       1. Validação de idempotência em `commands/{commandId}`.
       2. Leitura da participação e da ficha associada.
       3. Validação de autorização em runtime (titular OU vínculo ativo de pastor/responsável/coordenador).
       4. Transição da participação para `CANCELADA` com atualização de `proximaAcao` canônica.
       5. Encerramento do ciclo atual associado (`CANCELADO`).
       6. Avaliação das demais participações do voluntário para redução do estado da ficha (`ATIVA` se restar alguma ativa, senão `INATIVA`).
       7. Gravação de evidência em `evidenciasDecisao/{commandId}` e auditoria em `auditOutbox/{commandId}`.
       8. Gravação do recibo em `commands/{commandId}`.
     * `executarCancelarVoluntariado`: Transação Firestore atômica:
       1. Validação de idempotência em `commands/{commandId}`.
       2. Leitura da ficha e de todas as suas participações.
       3. Validação de autorização em runtime (titular OU Pastor Local vigente da igreja OU Coordenador Geral; rejeição sumária de Responsável de Equipe).
       4. Transição de todas as participações não terminais para `CANCELADA`.
       5. Transição de ciclos não terminais para `CANCELADO`.
       6. Transição da ficha para `CANCELADA`.
       7. Gravação de evidência, outbox e recibo do comando.
   - **Callables Cloud Functions v2:**
     * `functions/src/commands/cancelarParticipacao.ts`
     * `functions/src/commands/cancelarVoluntariado.ts`
   - **Suíte de Testes no Vitest:**
     * `functions/test/cancelarParticipacao.test.ts`
     * `functions/test/cancelarVoluntariado.test.ts`
2. **Frontend Flutter Web/PWA Mobile-First (Sally + Amelia):**
   - **Gateway e Serviços:**
     * Adicionar métodos em `ParticipacaoGateway`:
       `Future<void> cancelarParticipacao({required String participacaoId, String? motivo, String? commandId})`
     * Adicionar métodos em `FichaService`:
       `Future<void> cancelarVoluntariado({required String fichaId, String? motivo, String? commandId})`
     * Implementações em `FirebaseParticipacaoGateway` / `MemoriaParticipacaoGateway` e `FirebaseFichaService` / `MemoriaFichaService`.
   - **Componentes e Modais (Design System Sally):**
     * `ConfirmarCancelamentoParticipacaoDialog`: Modal de confirmação para cancelar equipe específica, com aviso de encerramento de serviço e campo de justificativa caso o usuário logado seja líder.
     * `ConfirmarCancelamentoVoluntariadoDialog`: Modal de confirmação para cancelamento geral, exibindo previamente a lista de todas as equipes ativas que serão encerradas.
   - **Integração nas Telas:**
     * `MinhaFichaScreen`: Ação "Cancelar Participação" em cada card de equipe ativa/pendente e ação "Encerrar Voluntariado" na seção de encerramento da ficha.
     * Fila do Pastor / Fila da Equipe / Fila do Coordenador: Possibilidade de cancelamento/desligamento administrativo com justificativa interna obrigatória.
     * Exibição estrita da mensagem neutra canônica para o voluntário (`"Procure o Pastor da igreja local para mais informações"`).
   - **Suíte de Testes de Widget no Flutter:**
     * `flutter_app/test/cancelar_participacao_test.dart`
     * `flutter_app/test/cancelar_voluntariado_test.dart`

## Boundaries & Constraints

**Always:**
- Exigir transação atômica Firestore com idempotência (`commandId`, `payloadHash`).
- Revalidar autoridade em runtime via Firestore: vínculos vigentes de pastor/responsável, sem confiar em claims estáticas do cliente.
- Rejeitar sumariamente tentativa de cancelamento de voluntariado (`cancelarVoluntariado`) por Responsável de Equipe.
- Manter mensagem estritamente neutra (`"Procure o Pastor da igreja local para mais informações"`) para o voluntário em cancelamentos iniciados por líderes.
- Manter histórico append-only em `evidenciasDecisao` e `auditOutbox` sem registrar PII sensível.
- Garantir que a redução de estados (AD-11) preserve a ficha como `ATIVA` se ainda houver outra participação ativa.
- Manter conformidade WCAG 2.2 AA com alvos de toque >= 44px e contraste.

**Never:**
- Nunca permitir escrita direta de cliente no Firestore.
- Nunca permitir cancelamento de participações ou fichas já em estado terminal (`CANCELADA`, `REJEITADA`).
- Nunca expor justificativa interna de líderes ou identidade de quem deliberou ao voluntário titular.
- Nunca apagar ou sobrescrever documentos de participações, fichas, termos ou ciclos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Voluntário cancela própria participação (com outras ativas) | Titular autenticado, Participação `ATIVA`, outra participação `ATIVA` | Participação vira `CANCELADA`, ciclo vira `CANCELADO`, Ficha permanece `ATIVA`. | `200 OK` |
| Voluntário cancela sua última participação ativa | Titular autenticado, Participação `ATIVA`, sem outras ativas | Participação vira `CANCELADA`, Ficha transiciona para `INATIVA` (AD-11). | `200 OK` |
| Pastor da igreja cancela participação de voluntário | Pastor local com vínculo vigente, fornece `motivo` | Participação `CANCELADA`, evidência gravada com motivo. Voluntário vê mensagem neutra canônica. | `200 OK` |
| Responsável de equipe cancela participação da sua equipe | Responsável com vínculo vigente na equipe alvo, fornece `motivo` | Participação `CANCELADA`, evidência com motivo. Outras equipes do voluntário intocadas. | `200 OK` |
| Responsável de equipe tenta cancelar toda a ficha | Responsável tenta `cancelarVoluntariado` | Rejeição imediata no backend | `permission-denied` ("Responsável de equipe não tem autoridade para cancelar toda a ficha.") |
| Liderança tenta cancelar sem informar motivo | Pastor/Responsável/Coordenador sem `motivo` | Rejeição de validação | `invalid-argument` ("Motivo é obrigatório para cancelamento por liderança.") |
| Cancelamento de voluntariado completo por titular ou Pastor | Titular ou Pastor da igreja confirma cancelamento total | Todas as participações não terminais viram `CANCELADA`, Ficha vira `CANCELADA`. | `200 OK` |
| Tentativa de cancelar participação já cancelada ou rejeitada | Participação em estado terminal | Rejeição por estado inválido | `failed-precondition` ("Participação já se encontra em estado terminal.") |
| Replay idempotente com mesmo `commandId` e mesmo payload | Reenvio idêntico de rede | Retorna recibo original sem reprocessar | `200 OK` com `repetido: true` |
| Replay com mesmo `commandId` mas payload alterado | Chave duplicada com parâmetros divergentes | Rejeição por integridade | `invalid-argument` ("Comando já executado com dados divergentes.") |

</frozen-after-approval>

## Code Map

- `functions/src/domain/cancelarParticipacao.ts` -- Tipos, regras de autorização, hashing de payload e erros de domínio para cancelamento de participação.
- `functions/src/domain/cancelarVoluntariado.ts` -- Tipos, regras de autorização, hashing de payload e erros de domínio para cancelamento geral da ficha.
- `functions/src/repositories/cancelamento.ts` -- Transações atômicas Firestore para `cancelarParticipacao` e `cancelarVoluntariado`, validação de vínculos em runtime, redução de estado da ficha (AD-11), auditoria e outbox.
- `functions/src/commands/cancelarParticipacao.ts` -- Endpoint callable Cloud Function v2 para cancelamento individual.
- `functions/src/commands/cancelarVoluntariado.ts` -- Endpoint callable Cloud Function v2 para cancelamento geral.
- `functions/test/cancelarParticipacao.test.ts` -- Testes Vitest cobrindo cancelamento pelo titular, pastor, responsável de equipe, concorrência, idempotência e redução de ficha.
- `functions/test/cancelarVoluntariado.test.ts` -- Testes Vitest cobrindo cancelamento geral por titular e pastor, bloqueio a responsável de equipe, cancelamento em lote das participações e ficha.
- `flutter_app/lib/features/voluntario/participacao_service.dart` -- Atualização do contrato `ParticipacaoGateway` com `cancelarParticipacao`.
- `flutter_app/lib/features/voluntario/ficha_service.dart` -- Atualização do contrato com `cancelarVoluntariado`.
- `flutter_app/lib/features/voluntario/cancelar_participacao_dialog.dart` -- Diálogo acessível de confirmação e justificativa para cancelamento individual.
- `flutter_app/lib/features/voluntario/cancelar_voluntariado_dialog.dart` -- Diálogo acessível com pré-visualização de todos os itens afetados para cancelamento total.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Integração das ações de cancelamento com feedback visual e mensagem neutra canônica.
- `flutter_app/test/cancelar_participacao_test.dart` -- Testes de widget Flutter para fluxo de cancelamento de participação individual.
- `flutter_app/test/cancelar_voluntariado_test.dart` -- Testes de widget Flutter para fluxo de cancelamento de voluntariado e pré-visualização dos itens.

## Review Findings (code review 2026-10-07)

### Patch
- [x] [Review][Patch] Violação de ordem "todos os reads antes dos writes" na transação Firestore — `executarCancelarParticipacaoRepo` faz `tx.update(partRef)` (:241) e depois `tx.get(cicloRef)` (:254) e a query de participações (:267); `executarCancelarVoluntariadoRepo` faz `tx.update(doc.ref)` (:460) e depois `tx.get(cRef)` (:473). O SDK `@google-cloud/firestore` lança `READ_AFTER_WRITE_ERROR` (`transaction.js:95-98`), então ambos os cancelamentos falham em produção. O mock de teste (`test/cancelarParticipacao.test.ts:174-185`) não impõe ordem, então a suíte fica verde. Corrigir prefetchando todos os `tx.get` antes de qualquer escrita. [functions/src/repositories/cancelamento.ts:241, functions/src/repositories/cancelamento.ts:267, functions/src/repositories/cancelamento.ts:460, functions/src/repositories/cancelamento.ts:473]
- [x] [Review][Patch] Catálogo canônico de estados não estendido — `CANCELADA` não existe em `EstadoParticipacao`/`ESTADOS_PARTICIPACAO` (`domain/participacao.ts:38-53`), e `normalizarEstadoParticipacao` (:55-60) coage qualquer estado desconhecido a `'RASCUNHO'`. Como `montarParticipacao` (`repositories/participacao.ts:37`) usa esse normalizador, `obterMinhasParticipacoes` devolve uma participação cancelada como `RASCUNHO` e a UI volta a oferecê-la como rascunho editável, desfazendo o cancelamento. Adicionar `CANCELADA`/`EXPIRADA`/`INATIVA` ao catálogo e garantir que a leitura os preserve. [functions/src/domain/participacao.ts:38, functions/src/repositories/participacao.ts:37]
- [x] [Review][Patch] Autoridade de coordenador lê `pessoas` como segunda fonte revogável — `verificarSeCoordenador` aceita `pessoas.coordenador===true`/`administrador===true`/`papeis` além do agregado canônico `autoridadesAdministrativas`. `avaliarAutoridadeCoordenador` documenta explicitamente que `pessoas` não é fonte de autorização (`decisaoCoordenador.ts:109-118`), então um coordenador/administrador revogado no agregado mas com flag obsoleta em `pessoas` mantém poder de cancelamento. Autorizar somente pelo agregado canônico. [functions/src/repositories/cancelamento.ts:59]
- [x] [Review][Patch] Conjunto de estados terminais divergente entre backend e cliente — `cancelamento.ts:32` declara `ESTADOS_TERMINAIS=['CANCELADA','REJEITADA']`, omitindo `EXPIRADA`/`INATIVA` que o canônico `solicitarEquipeAdicional.ts:26` e o cliente (`participacao_service.dart:44-45`, com comentário alegando paridade) já incluem. Quando a Epic 5 produzir `EXPIRADA`/`INATIVA`, o cancelamento as recancelará e as contará como afetadas; a UI (`minha_ficha_screen.dart:1105,1954`) usa literais `!= 'CANCELADA' && != 'REJEITADA'` e o `isTerminal` fica sem uso. Derivar de uma constante canônica única. [functions/src/repositories/cancelamento.ts:32, flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1105]
- [x] [Review][Patch] Guarda de concorrência `expectedVersion` não conectada ponta-a-ponta — `cancelarVoluntariado` não tem `expectedVersion` no domínio nem no repositório (`domain/cancelarVoluntariado.ts:31-37`), `ParticipacaoModel` não possui campo `versao` (`participacao_service.dart:6-33`) e a UI nunca passa `expectedVersion` (`minha_ficha_screen.dart:1923`), então o `ConflitoVersaoError` é inalcançável; o repositório ainda pula a checagem quando `partData.versao` é `undefined` (:185-191) e o `payloadHash` não inclui `expectedVersion`. AD-5/AD-10 exigem comparar a versão do agregado. [functions/src/repositories/cancelamento.ts:185, flutter_app/lib/features/voluntario/participacao_service.dart:6]
- [x] [Review][Patch] Autoridade reavaliada fora da transação (TOCTOU) — `verificarSeCoordenador`/`verificarSePastorLocal`/`verificarSeResponsavelEquipe` usam `db.collection(...).get()` em vez de `tx.get`, então uma revogação entre a leitura e o commit não é detectada. `decisaoCoordenador` revalida via `tx.get` explicitamente para fechar essa janela (`decisaoCoordenador.ts:161-171`). Passar o `tx` às checagens e prefetchá-las antes das escritas. [functions/src/repositories/cancelamento.ts:47, functions/src/repositories/cancelamento.ts:78, functions/src/repositories/cancelamento.ts:106]
- [x] [Review][Patch] `cancelarVoluntariado` aceita ficha terminal `REJEITADA`; UI oferece "Encerrar Voluntariado" em ficha terminal — o repositório só rejeita `estado === 'CANCELADA'` (:394), mas o `Never` da story proíbe cancelar fichas já terminais (`CANCELADA`, `REJEITADA`); `FichaModel.isRejeitada` existe e `_obterActionHeader` trata ficha `REJEITADA`. Na UI, `_ficha?.estado == 'ATIVA' || (_isBloqueadoParaEdicao && _ficha?.estado != 'CANCELADA')` exibe o botão para `REJEITADA`. [functions/src/repositories/cancelamento.ts:394, flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1133]
- [x] [Review][Patch] Eventos de auditoria sem ator, antes/depois e motivo — AD-8 exige ator e estados antes/depois; os eventos de `cancelarParticipacao`/`cancelarVoluntariado` (`cancelamento.ts:309-318` e :507-514) gravam apenas `papelAtor`, omitindo `atorUid`, estado anterior e justificativa, enquanto os pares `decisaoPastor.ts:382-397` e `decisaoCoordenador.ts:603-615` incluem ator, `antes`/`depois` e metadados. [functions/src/repositories/cancelamento.ts:309]
- [x] [Review][Patch] `commandId` regenerado a cada tentativa — a UI nunca passa `commandId`, então `FirebaseParticipacaoGateway.cancelarParticipacao` e `FirebaseFichaGateway.cancelarVoluntariado` chamam `comandoOpaco()` por invocação (`participacao_service.dart:196`, `ficha_service.dart:285`). Um retry após sucesso não confirmado gera novo `commandId` e a guarda de estado terminal rejeita, exibindo erro para uma operação que já concluiu. Gerar `commandId` estável na ação da UI e reutilizá-lo no retry. [flutter_app/lib/features/voluntario/participacao_service.dart:196, flutter_app/lib/features/voluntario/ficha_service.dart:285]
- [x] [Review][Patch] Recibo idempotente não vinculado ao `uid` do chamador — o replay (`cancelamento.ts:156-172` e :369-385) compara apenas `payloadHash`, sem validar `dadosRecibo.uid === contexto.uid`, ao contrário do padrão de `solicitarEquipeAdicional.ts:72-74` e `participacao.ts:99-101`. Um chamador que conheça o `commandId` recebe o resultado de outro. [functions/src/repositories/cancelamento.ts:156, functions/src/repositories/cancelamento.ts:369]
- [x] [Review][Patch] Ficha ausente tratada silenciosamente como vazia — em `cancelarParticipacao` a ficha inexistente cai em `fichaSnap.exists ? ... : {}` sem lançar (`cancelamento.ts:199`), permitindo cancelar participação órfã e registrar `fichaEstado:'ATIVA'` fictício; `cancelarVoluntariado` lança `FichaNaoEncontradaError` (:389). Lançar também aqui. [functions/src/repositories/cancelamento.ts:199]
- [x] [Review][Patch] Tokens de design hardcoded e `navy-900` rotulado errado — ambos os diálogos definem `corNavy900 = Color(0xFF0F172A)` (comentário afirma ser Navy-900), `corGray600 = 0xFF475569` e outros literais, enquanto `AppColors.navy900 = 0xFF082C49` e `textSecondary = 0xFF667085` (`ui/tokens.dart:9,19`); raios/alturas também literais em vez de `AppGeometry`. Usar os tokens canônicos. [flutter_app/lib/features/voluntario/cancelar_participacao_dialog.dart:92, flutter_app/lib/features/voluntario/cancelar_voluntariado_dialog.dart:100]
- [x] [Review][Patch] Diálogos fora do catálogo de componentes — usam `ElevatedButton`/`TextButton` crus com `styleFrom` inline e duplicam ~280/360 linhas de layout, enquanto a tela reutiliza `PrimaryButton`/`OutlinedButton` (`minha_ficha_screen.dart:854,1137`), contrariando a regra de reutilização do Design System. [flutter_app/lib/features/voluntario/cancelar_participacao_dialog.dart:232, flutter_app/lib/features/voluntario/cancelar_voluntariado_dialog.dart:310]
- [x] [Review][Patch] Exceção crua exibida ao usuário — `_erroMensagem = 'Falha ...: ${e.toString()...}'` (`cancelar_participacao_dialog.dart:84`, `cancelar_voluntariado_dialog.dart:85`) mostra mensagens de framework/backend em vez de um texto mapeado e seguro. [flutter_app/lib/features/voluntario/cancelar_participacao_dialog.dart:84]
- [x] [Review][Patch] Validação de motivo diverge cliente/servidor — os diálogos exigem `motivo` com ≥5 caracteres, mas o backend só valida não-vazio (sem mínimo nem máximo) em `validarCancelarParticipacao`/`validarCancelarVoluntariado`. Alinhar o contrato. [functions/src/domain/cancelarParticipacao.ts:109, flutter_app/lib/features/voluntario/cancelar_voluntariado_dialog.dart:278]
- [x] [Review][Patch] Checagem terminal do ciclo usa conjunto de participação (feminino) — `ESTADOS_TERMINAIS` (`CANCELADA`/`REJEITADA`) é comparado contra estados de ciclo gravados como `'CANCELADO'` (`cancelamento.ts:257` e :474), então um ciclo já cancelado é reescrito. Usar o estado terminal próprio do ciclo. [functions/src/repositories/cancelamento.ts:257]
- [x] [Review][Patch] `verificarSePastorLocal` consulta coleção/escopo incorretos — busca em `vinculosPastorEquipe` por `igrejaId` (a coleção pastoral é `vinculosPastorIgreja`, cf. `decisaoPastor.ts:229`) e nenhuma das queries de vínculo filtra `tipo`, enquanto o bloco de bloqueio usa `tipo == 'EQUIPE'`; um responsável registrado só em `equipes.responsavelVigentePessoaId` não é detectado e cai na mensagem genérica. [functions/src/repositories/cancelamento.ts:93, functions/src/repositories/cancelamento.ts:416]
- [x] [Review][Patch] Leitura de participações na transação sem teto (AD-9) — `db.collection('participacoes').where('fichaId','==',...)` sem `.limit` (`cancelamento.ts:267` e :449), diferente de `solicitarEquipeAdicional.ts:133`/`participacao.ts:69`. [functions/src/repositories/cancelamento.ts:267]
- [x] [Review][Patch] `_rotuloEstado` colapsa e expõe estados internos — retorna `'AGUARDANDO'` para qualquer estado `AGUARDANDO_*` (indistinguindo etapas) e o valor bruto do enum para os demais, quebrando a semântica de chips/status e expondo estado interno ao voluntário. [flutter_app/lib/features/voluntario/cancelar_voluntariado_dialog.dart:91]
- [x] [Review][Patch] Gateway de produção sem teste — nenhum teste constrói `FirebaseParticipacaoGateway`/`FirebaseFichaGateway` e chama `cancelarParticipacao`/`cancelarVoluntariado`; trocar a chave `participacaoId`/`fichaId` ou enviar `motivo` sempre mantém a suíte verde. [flutter_app/lib/features/voluntario/participacao_service.dart:189, flutter_app/lib/features/voluntario/ficha_service.dart:279]
- [x] [Review][Patch] Tela `MinhaFichaScreen` sem teste de integração do cancelamento — os testes instanciam os diálogos direto e nunca montam a tela nem tocam `btn_cancelar_participacao_*`/`btn_cancelar_voluntariado`; cancelar o alvo errado ou omitir `_carregarDados()` não falha a suíte. [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1914]
- [x] [Review][Patch] Elegibilidade do `SolicitarEquipeModal` para estados terminais sem teste — `isPendente` passou a excluir `EXPIRADA`/`INATIVA` (`participacao_service.dart:47`), alterando a seleção de equipes, mas nenhum teste usa participação terminal. [flutter_app/lib/features/voluntario/participacao_service.dart:47]

### Defer
- [x] [Review][Defer] Cancelamento administrativo pelas filas de Pastor/Equipe/Coordenador não implementado — o `Approach` da story exige, nas filas, ação de cancelamento/desligamento com justificativa interna obrigatória, mas a única integração no diff é `MinhaFichaScreen`, que fixa `isLideranca: false`; o backend já aceita a autoridade de liderança, porém não há superfície para exercê-la. [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1921, flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1961] — deferred: backend autoritativo; a superfície administrativa das filas fica em story própria.
- [x] [Review][Defer] Nomenclatura diverge do Code Map — o spec nomeia `ConfirmarCancelamentoParticipacaoDialog`/`ConfirmarCancelamentoVoluntariadoDialog` e `FichaService`/`FirebaseFichaService`/`MemoriaFichaService`; o código usa `Cancelar...Dialog` e `FichaGateway`/`FirebaseFichaGateway`, sem implementação em memória de `FichaGateway`. [flutter_app/lib/features/voluntario/ficha_service.dart:211] — deferred: divergência cosmética de nomes, sem consumidor; renomear é amplo e sem impacto funcional.
- [x] [Review][Defer] Vigência temporal do vínculo não validada nas checagens de autoridade — `verificarSePastorLocal`/`verificarSeResponsavelEquipe` só filtram `estado == 'VIGENTE'`, sem janela `inicioVigencia`/`fimVigencia` (AD-2), mesma convenção de `decisaoPastor.ts:220-238`/`decisaoResponsavelEquipe.ts:240-260`. [functions/src/repositories/cancelamento.ts:93] — deferred: padrão pré-existente no codebase; o modelo marca o vínculo como `ENCERRADO` ao encerrar, então não há caso alcançável hoje.

### Rejected
- `false` — Ficha rebaixada a `INATIVA` ignorando participações pendentes e guarda `fichaData.estado === 'ATIVA'`: a `Intent` congelada §3 prescreve `INATIVA` quando não resta participação ativa, e a guarda é inalcançável (ficha `ATIVA` exige ao menos uma participação ativa, AD-11).
- `false` — "Encerrar Voluntariado" oculto quando a lista de participações está vazia: uma ficha `ATIVA` sempre possui ≥1 participação (AD-11), então a condição não esconde a ação em nenhum estado alcançável.

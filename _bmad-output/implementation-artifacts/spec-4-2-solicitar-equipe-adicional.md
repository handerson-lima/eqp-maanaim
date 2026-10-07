---
title: 'Story 4.2: Solicitar equipe adicional'
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
Voluntários com ficha de voluntariado já homologada e no estado `ATIVA` frequentemente desejam ampliar seu serviço institucional participando de novas equipes administráveis do catálogo (ex: voluntário que atua em Recepção deseja solicitar ingresso em Som/Mídia ou Louvor).
Entretanto, o sistema deve garantir rigorosamente:
1. **Isolamento Estrito de Agregados (AD-4, PRD Seção 24):**
   - Cada solicitação de nova equipe gera uma nova participação (`participacoes/{participacaoId}`) e ciclo de aprovação (`ciclos/{cicloId}`) estritamente independentes.
   - As participações existentes ativas permanecem integralmente ativas, vigentes e inalteradas.
   - Qualquer deliberação futura (aprovação, indeferimento, cancelamento) da nova equipe nunca pode reverter, bloquear ou contaminar as participações já consolidadas nem alterar o estado geral da ficha (que permanece `ATIVA` enquanto houver ao menos uma participação ativa, conforme AD-11).
2. **Validações de Domínio e Invariantes no Backend (AD-1, AD-2, AD-5):**
   - Execução exclusiva via Cloud Function autenticada (`solicitarEquipeAdicional`). Escrita direta de cliente no Firestore é sumariamente negada.
   - O chamador autenticado deve ser o titular da ficha permanente.
   - A ficha permanente deve estar no estado `ATIVA` com termo vigente aceito.
   - A equipe solicitada deve existir no catálogo administrável e estar ativa (`ativo == true`).
   - Bloqueio estrito de duplicidade: o voluntário não pode solicitar uma equipe na qual já possua participação ativa (`ATIVA`) ou em tramitação de aprovação (`AGUARDANDO_PASTOR_LOCAL`, `AGUARDANDO_RESPONSAVEL_EQUIPE`, `AGUARDANDO_COORDENADOR`, `RASCUNHO`).
   - Roteamento ao fluxo de aprovação aplicável: uma vez que o voluntário já possui vínculo e anuência pastoral validados na ficha ativa, a nova participação ingressa diretamente na fila de avaliação do Responsável da Equipe (`AGUARDANDO_RESPONSAVEL_EQUIPE`), passando posteriormente pela conclusão do Coordenador Geral.
3. **Idempotência e Trilha de Auditoria Append-Only (AD-8, AD-10, AD-12):**
   - Idempotência transacional via `commands/{commandId}` com `payloadHash` SHA-256.
   - Registro de evento em `auditOutbox/{commandId}` sem dados pessoais sensíveis (PII).
4. **Experiência do Usuário e Acessibilidade (Sally - WCAG 2.2 AA):**
   - Ponto de entrada claro na visão da Ficha Ativa do Voluntário: botão "Solicitar Nova Equipe".
   - Diálogo/BottomSheet responsivo listando equipes ativas do catálogo.
   - Equipes inelegíveis (já ativas ou em análise) claramente sinalizadas e desabilitadas para seleção com feedback semântico (não apenas cor).
   - Alvos de toque >= 44px, estados de loading, feedback de erro claro e confirmação de sucesso.

**Approach:**
1. **Backend (Cloud Functions TypeScript - Winston & Amelia):**
   - Módulo de domínio `functions/src/domain/solicitarEquipeAdicional.ts`:
     * Definição de contratos, tipos e classes de erro específicas (`FichaNaoAtivaError`, `EquipeJaSolicitadaError`, `EquipeInativaError`, `TermoInvalidoError`, `ComandoDivergenteError`).
     * Hash determinístico de payload SHA-256.
   - Repositório transacional `functions/src/repositories/solicitarEquipeAdicional.ts`:
     * Execução atômica em Firestore Transaction.
     * Verificação de idempotência em `commands/{commandId}`.
     * Leitura e validação da Ficha (`estado === 'ATIVA'`, termo aceito).
     * Leitura de todas as participações do voluntário para conferência de duplicidade não terminal.
     * Leitura e validação da equipe alvo em `equipes/{equipeId}` (`ativo === true`).
     * Criação da nova participação em `participacoes/{participacaoId}` com estado `AGUARDANDO_RESPONSAVEL_EQUIPE`, `proximaAcao: 'Aguardando avaliação do Responsável de Equipe'`, `ciclo: 'INICIAL'`, `versao: 1`.
     * Criação do ciclo de aprovação independente em `ciclos/{cicloId}` com estado `EM_APROVACAO`, vinculado à participação.
     * Persistência de recibo em `commands/{commandId}` (`status: 'COMPLETO'`).
     * Persistência de auditoria em `auditOutbox/{commandId}` com snapshot seguro sem PII.
   - Endpoint callable v2 `functions/src/commands/solicitarEquipeAdicional.ts`:
     * Autenticação e App Check obrigatórios.
     * Tratamento padronizado de erros (`invalid-argument`, `failed-precondition`, `permission-denied`, `internal`).
   - Suíte de testes no Vitest `functions/test/solicitarEquipeAdicional.test.ts`.
2. **Frontend Flutter Web/PWA Mobile-First (Sally + Amelia):**
   - Extensão do `ParticipacaoGateway` (`flutter_app/lib/features/voluntario/participacao_service.dart`):
     * Adicionar método `Future<ParticipacaoModel> solicitarEquipeAdicional(String equipeId, {String? commandId})`.
     * Implementações em `FirebaseParticipacaoGateway` e `MemoriaParticipacaoGateway`.
   - Componente `SolicitarEquipeModal` / `SolicitarEquipeDialog`:
     * Interface mobile-first (BottomSheet no mobile, Diálogo no desktop) respeitando tokens (`navy-900`, `blue-600`, `gray-100`, etc.).
     * Apresentação das equipes ativas do catálogo, filtrando/desabilitando equipes onde o voluntário já possui participação ativa ou pendente.
     * Chips informativos acessíveis: "Participação Ativa" ou "Em Análise".
     * Seleção assistida por leitor de tela e alvos de toque >= 44px.
   - Integração na `MinhaFichaScreen`:
     * Seção de ações na ficha ativa com botão destacado "Solicitar Nova Equipe".
     * Atualização dinâmica da lista de participações após submissão bem-sucedida, exibindo o card da nova equipe em "Aguardando Responsável" sem impactar as demais.
   - Suíte de testes de Widget no Flutter `flutter_app/test/solicitar_equipe_adicional_test.dart`:
     * Cenário de seleção e submissão com sucesso.
     * Bloqueio visual de equipes já solicitadas.
     * Tratamento de erro de rede ou recusa da Cloud Function.
     * Verificação de responsividade (mobile 390x844 e desktop 1024x768).

## Boundaries & Constraints

**Always:**
- Exigir ficha no estado `ATIVA` e autenticação correspondente ao voluntário titular.
- Validar equipe ativa no catálogo administrável dentro da transação Firestore.
- Impedir qualquer duplicidade de solicitação não terminal para a mesma equipe.
- Criar participação e ciclo como entidades separadas e imutáveis em relação às participações existentes.
- Registrar recibo idempotente em `commands` e evento em `auditOutbox` sem PII no mesmo commit lógico.
- Garantir alvos de toque >= 44px e contraste WCAG 2.2 AA.

**Never:**
- Nunca permitir escrita direta de cliente em `participacoes` ou `ciclos`.
- Nunca alterar ou reverter o estado de participações ativas existentes durante a solicitação de uma nova equipe.
- Nunca alterar o estado geral da ficha de `ATIVA` para pendente durante a inclusão de uma equipe adicional.
- Nunca expor PII ou detalhes confidenciais em logs de auditoria ou mensagens de erro.
- Nunca permitir solicitar equipe inativa ou inexistente.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Solicitação bem-sucedida de equipe adicional | Voluntário autenticado, Ficha `ATIVA`, Equipe ativa e sem participação prévia | Cria `participacoes/{id}` (`AGUARDANDO_RESPONSAVEL_EQUIPE`), `ciclos/{id}` (`EM_APROVACAO`), recibo e auditoria. Retorna `sucesso: true`. | `200 OK` |
| Voluntário tenta solicitar equipe em que já atua (`ATIVA`) | Ficha `ATIVA`, Equipe já ativa na lista de participações | Recusa no backend sem alterar agregados | `failed-precondition` / `invalid-argument` ("Voluntário já possui participação ativa ou pendente nesta equipe.") |
| Voluntário tenta solicitar equipe com aprovação em andamento | Equipe em `AGUARDANDO_RESPONSAVEL_EQUIPE` ou `AGUARDANDO_COORDENADOR` | Recusa no backend | `failed-precondition` ("Voluntário já possui solicitação em andamento para esta equipe.") |
| Ficha do voluntário não está ativa (ex: `RASCUNHO` ou `AGUARDANDO_PASTOR_LOCAL`) | Ficha fora do estado `ATIVA` | Recusa sumária da operação | `failed-precondition` ("Apenas voluntários com ficha ativa podem solicitar equipes adicionais.") |
| Equipe solicitada está desativada no catálogo | `equipe.ativo === false` | Recusa no backend | `failed-precondition` ("A equipe selecionada está inativa ou não existe.") |
| Replay de comando com mesmo `commandId` e mesmo payload | Reenvio de rede idêntico | Retorno idempotente do resultado original sem duplicar registros | `200 OK` com `repetido: true` |
| Replay com mesmo `commandId` mas `equipeId` diferente | Mesma chave de idempotência com dados divergentes | Recusa imediata de integridade | `invalid-argument` ("Operação já registrada com dados divergentes.") |
| Chamador não autenticado ou tentando solicitar para outro UID | Sem sessão ou `request.data.uid !== request.auth.uid` | Bloqueio de segurança | `unauthenticated` / `permission-denied` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/solicitarEquipeAdicional.ts` -- Modelos, validações de entrada, hashing de payload e erros canônicos de domínio.
- `functions/src/repositories/solicitarEquipeAdicional.ts` -- Transação atômica Firestore, validação de ficha ativa, equipe ativa, duplicidade de participação, criação independente de participação/ciclo, recibo em `commands` e outbox.
- `functions/src/commands/solicitarEquipeAdicional.ts` -- Callable Cloud Function v2 autenticada com App Check e mapeamento de HttpsError.
- `functions/test/solicitarEquipeAdicional.test.ts` -- Testes Vitest cobrindo fluxo feliz, duplicidades, ficha inativa, equipe desativada, concorrência e idempotência.
- `flutter_app/lib/features/voluntario/participacao_service.dart` -- Atualização do gateway com método `solicitarEquipeAdicional` e modelo atualizado.
- `flutter_app/lib/features/voluntario/solicitar_equipe_modal.dart` -- Componente BottomSheet/Dialog acessível mobile-first para seleção de equipe adicional elegível.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Integração do botão de ação na visualização da ficha ativa e recarregamento reativo de participações.
- `flutter_app/test/solicitar_equipe_adicional_test.dart` -- Testes de widget Flutter cobrindo abertura do modal, desabilitação de equipes duplicadas, envio e exibição de feedback.

## Review Findings (code review 2026-10-07)

### Patch
- [x] [Review][Patch] Ficha `ATIVA` é rebaixada a `AGUARDANDO_COORDENADOR` e a nova equipe não chega à fila do Coordenador [decisão: preservar `ATIVA` e fatiar a fila por participação] — ao aprovar a equipe adicional, `decisaoResponsavelEquipe.ts:375-387` recalcula a ficha: como a participação pré-existente continua `ATIVA`, `temAprovada` é verdadeiro e a ficha é sobrescrita para `AGUARDANDO_COORDENADOR`, violando AD-11 ("ficha é `ATIVA` se possuir ao menos uma participação ativa") e o "Never" da story. Em contrapartida, `obterFilaCoordenadorRepo` descarta pendências cuja ficha não esteja em `AGUARDANDO_COORDENADOR` (`decisaoCoordenador.ts:236`), então mantendo a ficha `ATIVA` a nova equipe nunca aparece para o Coordenador. Correção decidida: manter a ficha `ATIVA` quando houver participação ativa e selecionar a fila do Coordenador pelo estado da participação (`AGUARDANDO_COORDENADOR`), não pelo estado da ficha. [functions/src/repositories/decisaoResponsavelEquipe.ts:375, functions/src/repositories/decisaoCoordenador.ts:236]
- [x] [Review][Patch] Gateway de produção sem teste — `FirebaseParticipacaoGateway.solicitarEquipeAdicional` nunca é exercitado por teste algum (só o double `ParticipacaoMockGateway`): renomear a string do callable ou trocar as chaves de resposta (`participacaoId`→`id`) mantém a suíte verde e quebra a produção. [flutter_app/lib/features/voluntario/participacao_service.dart:149]
- [x] [Review][Patch] Ciclo pré-criado órfão/divergente — `solicitarEquipeAdicional` cria `ciclos/{ciclo_<id>_<anoSolicitação>}` com `estado: EM_APROVACAO`, mas `decisaoCoordenador` usa o ano da aprovação (`decisaoCoordenador.ts:414,422`) e nenhuma decisão negativa (responsável/coordenador) encerra o ciclo, deixando um `EM_APROVACAO` não terminal permanente e/ou um id divergente do aprovado. [functions/src/repositories/solicitarEquipeAdicional.ts:140]
- [x] [Review][Patch] Classificação de estados não-terminais duplicada e divergente — o repositório re-declara a lista (ATIVA/AGUARDANDO_*/RASCUNHO) em vez de derivá-la de `ESTADOS_PARTICIPACAO` (`domain/participacao.ts:46`), enquanto o cliente `isPendente` (`participacao_service.dart:38`) classifica qualquer estado desconhecido como pendente. Para `CANCELADA`/`EXPIRADA` (citados em `status_chips.dart` e no próprio teste do repositório, `test/solicitarEquipeAdicional.test.ts:349`) backend libera re-solicitação e UI bloqueia. [functions/src/repositories/solicitarEquipeAdicional.ts:21]
- [x] [Review][Patch] Leitura de participações na transação sem teto (AD-9) — `db.collection('participacoes').where('fichaId','==',uid)` sem `.limit`, diferente de `obterMinhasParticipacoesRepo` (`participacao.ts:18,74`). [functions/src/repositories/solicitarEquipeAdicional.ts:122]
- [x] [Review][Patch] Acessibilidade do modal — o `TextField` de busca usa só `hintText`, sem label persistente (DESIGN-SYSTEM / DESIGN-RULES), e a caixa de erro não é anunciada a leitores de tela (`Semantics(liveRegion: true)`). [flutter_app/lib/features/voluntario/solicitar_equipe_modal.dart:193]
- [x] [Review][Patch] Feedback de erro opaco — `_submeter` colapsa qualquer falha numa mensagem fixa e ignora `FirebaseFunctionsException.code`, tornando "EquipeJaSolicitadaError" (`failed-precondition`) indistinguível de falha de rede. [flutter_app/lib/features/voluntario/solicitar_equipe_modal.dart:116]

### Defer
- [x] [Review][Defer] Callable: sucesso e mapeamento de erros de domínio não exercitados — os dois únicos testes cobrem `unauthenticated` e `permission-denied`; o caminho feliz e as traduções `FichaNaoAtivaError`/`EquipeInvalidaError`/`EquipeJaSolicitadaError`/`ComandoDivergenteError` só são cobertos no repositório. [functions/test/solicitarEquipeAdicional.test.ts:441] — deferred: os testes de repositório já fixam os desfechos de domínio; contrato do callable pode ser pinado com emulator depois.
- [x] [Review][Defer] Cobertura de verificação ausente no repositório — sem testes para recibo pertencente a outro uid (`PermissaoNegadaError`), bloqueio por estado não-terminal não-rejeitado, propagação de `correlationId` e corrida com `commandId` distinto para a mesma equipe. [functions/test/solicitarEquipeAdicional.test.ts] — deferred: reforço de suíte, sem defeito funcional demonstrado.
- [x] [Review][Defer] Ação `SOLICITAR_EQUIPE_ADICIONAL` não mapeada para notificação — ausente de `MAPA_ACOES_NOTIFICAVEIS`, então o evento de auditoria não notifica o responsável. [functions/src/domain/notificacao.ts:60] — deferred: notificar nova solicitação ao responsável não está no escopo explícito desta story; decisão de produto.
- [x] [Review][Defer] Concorrência sem garantia determinística — duas solicitações com `commandId` distintos para a mesma equipe não têm chave de unicidade determinística; a isolação serializável do Firestore pode já impedir o duplo, mas não há teste que o comprove. [functions/src/repositories/solicitarEquipeAdicional.ts:122] — maybe-false: um teste de concorrência no emulator (duas transações simultâneas) settle se há duplicidade.
- [x] [Review][Defer] Contrato de segurança/Rules não estendido para o novo endpoint — a lista de callables do cliente em `security-contract.test.ts` não inclui `solicitarEquipeAdicional`. [functions/test/security-contract.test.ts:162] — deferred: verificação de contrato, sem impacto funcional imediato.

### Rejected
- `false` — Caminhos absolutos no diff (`diff --git a/Users/usuario/...`): artefato do harness de captura (`git diff --no-index` sobre caminhos absolutos), não do código.
- `false` — `equipeId` contendo `/`: resolve documento inexistente em `equipes` → `EquipeInvalidaError`; falha segura, sem vazamento de caminho.
- `false` — Replay devolveria estado divergente: o replay (`solicitarEquipeAdicional.ts:79`) e o resultado persistido gravam ambos `AGUARDANDO_RESPONSAVEL_EQUIPE`; não há divergência.
- `false` — Timestamp de replay não-determinístico: o recibo sempre contém `criadoEm` (serverTimestamp), então `iso()` não cai no fallback `new Date()`.
- `false` — O gateway fabrica `fichaId:''`/`ciclo:'INICIAL'`: estado transitório, `_carregarDados()` recarrega a lista após o sucesso.
- `false` — Classe `EquipeInativaError`: o código usa `EquipeInvalidaError` de forma consistente (também em `domain/participacao.ts`); a divergência é de nomenclatura do spec e corrigi-la exigiria editar o spec.
- `low` — Nomes de recibo (`estado`/`action` vs spec `status`/`acao`): convenções já divididas no código (decisao* e enviarFicha usam `status`; ficha/termos/participacao usam `estado`), sem consumidor de reconciliação ainda; corrigir só este recibo não estabelece consistência.
- `low` — Fachada `MinhaFichaScreen` inclui ação da Story 4.1 (topbar de consulta): escopo, não defeito; o código funciona.
- `low` — Validação de termo sem `hashSha256` (ao contrário de `enviarFicha.ts:121`): inalcançável, pois uma ficha `ATIVA` passou por `enviarFicha`, que exige o hash.
- `low` — Botão habilitado quando `participacaoGateway` é nulo: em produção o gateway é sempre injetado; a ação vira no-op.
- `low` — `RASCUNHO` rotulado "Em análise" no chip: cenário improvável (rascunho coexiste com ficha ativa).
- `low` — Idempotência sem reuso de `commandId` pelo modal: consistente com o padrão do app (novo `commandId` por ação) e o guard de duplicidade do servidor impede dupla submissão.
- `low` — `equipeId`/`correlationId` sem limite de tamanho: sem impacto prático; adicionar guard seria complexidade sem dano demonstrado.
- `low` — Rótulos de chip (`Ativa`/`Em análise`) divergentes do spec (`Participação Ativa`/`Em Análise`): cosmético.

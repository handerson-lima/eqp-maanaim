---
title: 'Story 3.3: Conclusão pelo coordenador e ativação'
type: 'feature'
created: '2026-10-06'
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
Após a aprovação inicial da ficha pelo Pastor Local (Story 3.1) e a deliberação paralela e independente dos Responsáveis de Equipe (Story 3.2), as participações aprovadas pelos respectivos responsáveis avançaram para o estado `AGUARDANDO_COORDENADOR`.
A homologação final e a entrada em vigor do voluntariado exigem a ação do Coordenador Geral do Maanaim:
1. O Coordenador Geral deve ter visão global das solicitações com participações elegíveis à conclusão (`AGUARDANDO_COORDENADOR`), inspecionando o voluntário, igreja de origem, decisão do pastor local e todas as equipes analisadas pelos responsáveis.
2. A ativação depende imperativamente da confirmação prévia na Reunião de Pastores (`confirmouReuniaoPastores == true`).
3. Em caso de aprovação:
   - Ativa SOMENTE as participações que estavam em `AGUARDANDO_COORDENADOR` (transicionando para o estado `ATIVA`), mantendo eventuais participações já `REJEITADA`s inalteradas (preservação de agregados independentes).
   - Gera e persiste o primeiro Ciclo de Voluntariado ativo para cada participação aprovada na coleção `ciclos`, com vigência de exatamente 1 (um) ano contado da data/hora da homologação do Coordenador (`vigenciaInicio` e `vigenciaFim`).
   - Aplica a redução canônica da Ficha (AD-11): com ao menos uma participação ativa, a ficha consolida-se no estado `ATIVA`.
4. Em caso de decisão desfavorável pelo Coordenador:
   - Transiciona as participações pendentes para `REJEITADA` com justificativa interna obrigatória (mínimo de 5 caracteres).
   - Se nenhuma participação restar ativa, a ficha transiciona para `REJEITADA`.
   - Mensagem neutra canônica rigorosamente preservada para exibição ao voluntário: *"Procure o Pastor da igreja local para mais informações"*, sem expor justificativa interna, motivo ou identificador de decisão.
5. Invariantes arquiteturais obrigatórios:
   - Idempotência estrita via `commands/{commandId}` com hash determinístico (SHA-256).
   - Controle de concorrência com `expectedVersion` da ficha.
   - Evidência imutável (`evidenciasDecisao/{commandId}`) e auditoria append-only (`auditOutbox/{commandId}`) sem dados pessoais identificáveis (AD-12).

**Approach:**
1. **Cloud Functions de Domínio e Consulta:**
   - `obterFilaCoordenador`: Callable autenticada (App Check) que valida se o chamador possui autoridade de Coordenador Geral (`autoridadesAdministrativas`, `coordenadores` ou papel `COORDENADOR`/`ADMINISTRADOR`). Consulta participações em `AGUARDANDO_COORDENADOR`, agrupa por ficha e projeta os dados completos da solicitação.
   - `decidirAtivacaoCoordenador`: Callable autenticada transacional que executa a transição atômica de ativação ou recusa:
     * Idempotência por recibo em `commands/{commandId}` com verificação de `payloadHash`.
     * Validação de autoridade do Coordenador Geral (AD-1, AD-2).
     * Validação de concorrência via `expectedVersion` da ficha.
     * Validação de confirmação de reunião de pastores em caso de aprovação.
     * Atualização das participações elegíveis para `ATIVA` (ou `REJEITADA`).
     * Criação determinística dos documentos em `ciclos/{cicloId}` com vigência anual exata (`inicio + 1 ano`).
     * Redução do agregado Ficha para `ATIVA` (ou `REJEITADA`).
     * Gravação de evidência imutável e auditoria append-only sem PII.
2. **Frontend Flutter Web/PWA (Mobile-First):**
   - Criação de `CoordenadorGateway`, `FirebaseCoordenadorGateway` e `MemoriaCoordenadorGateway`.
   - Interface `FilaCoordenadorScreen`:
     * Mobile-first: cards estruturados no celular e painel com tabela no desktop.
     * Detalhes ricos: voluntário, igreja, histórico do Pastor Local, status das equipes (aprovadas e rejeitadas).
     * Modal de Aprovação com checkbox obrigatório de confirmação da reunião de pastores e campo de observação.
     * Modal de Recusa com campo obrigatório de justificativa interna e aviso de texto neutro ao voluntário.
     * Alvos de toque >= 44px (WCAG 2.2 AA) e tokens do Design System.

## Boundaries & Constraints

**Always:**
- Validação no servidor da autoridade de Coordenador Geral (AD-1, AD-2).
- Confirmação explícita da Reunião de Pastores para aprovação e ativação.
- Idempotência absoluta (AD-10) com verificação de `payloadHash`.
- Vigência do ciclo de exatamente 1 ano a partir da data de aprovação do Coordenador.
- Decisão negativa preserva o texto neutro canônico para o voluntário: *"Procure o Pastor da igreja local para mais informações"*.
- Auditoria append-only em `auditOutbox` sem PII (AD-12).
- Acessibilidade WCAG 2.2 AA e Design System: alvos >= 44px, contraste e suporte a leitor de tela.

**Never:**
- Nunca aprovar ou ativar participações sem a confirmação da Reunião de Pastores.
- Nunca reverter, alterar ou ativar participações que já foram rejeitadas pelo responsável de equipe.
- Nunca expor justificativa interna, dados do avaliador ou termo "rejeitado" ao voluntário.
- Nunca permitir escrita direta do cliente no Firestore para transições de estado ou criação de ciclos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta de fila por Coordenador Geral autorizado | Usuário com papel `COORDENADOR` ou `ADMINISTRADOR` | Retorna lista de solicitações com pendências em `AGUARDANDO_COORDENADOR` | `200 OK` com `{ pendencias: [...] }` |
| Consulta por usuário sem papel de Coordenador | Usuário comum autenticado sem perfil de coordenação | Acesso negado | `permission-denied: O usuário não possui autoridade de Coordenador Geral.` |
| Aprovação e ativação com confirmação de reunião | Coordenador autorizado, `confirmouReuniaoPastores: true`, `expectedVersion` correto | Participações elegíveis viram `ATIVA`, ciclos anuais criados, ficha vira `ATIVA`, evidência e auditoria gravadas | `200 OK` com `{ sucesso: true, repetido: false, estadoFicha: 'ATIVA', vigenciaInicio: '...', vigenciaFim: '...' }` |
| Aprovação sem confirmar reunião de pastores | `decisao: 'APROVADO'`, `confirmouReuniaoPastores: false` | Rejeição imediata antes de qualquer mutação | `invalid-argument: É obrigatório confirmar a verificação na Reunião de Pastores para ativar o voluntariado.` |
| Decisão desfavorável válida com justificativa | `decisao: 'DESFAVORAVEL'`, justificativa preenchida (>= 5 chars) | Participações pendentes viram `REJEITADA`, ficha vira `REJEITADA`, mensagem ao voluntário fixada como neutra | `200 OK` com `{ sucesso: true, repetido: false, estadoFicha: 'REJEITADA' }` |
| Decisão desfavorável sem justificativa | `decisao: 'DESFAVORAVEL'`, justificativa ausente ou < 5 caracteres | Rejeição com erro de validação | `invalid-argument: Justificativa obrigatória para decisão desfavorável (mínimo de 5 caracteres).` |
| Conflito de versão na Ficha | `expectedVersion` diverge da versão atual da ficha | Transação abortada sem mutações | `aborted: Conflito de versão: a ficha foi alterada concorrentemente.` |
| Solicitação sem participações em `AGUARDANDO_COORDENADOR` | Ficha já decidida ou com estados terminais | Rejeição por pré-condição inválida | `failed-precondition: A solicitação não possui participações aguardando conclusão do Coordenador.` |
| Reenvio de comando (Idempotência) | Mesmo `commandId` com payload idêntico | Retorna o resultado gravado no recibo original | Idempotente `200 OK` com `repetido: true` |
| Reenvio de comando com dados divergentes | Mesmo `commandId` com payload diferente | Rejeição por divergência | `invalid-argument: Operação já registrada com dados divergentes.` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/decisaoCoordenador.ts` -- Tipos, contratos e validações de domínio para a etapa de coordenação geral e ciclo anual.
- `functions/src/repositories/decisaoCoordenador.ts` -- Repositório com validação de autoridade, consulta e transação atômica de ativação de ciclo e redução de estado.
- `functions/src/commands/obterFilaCoordenador.ts` -- Callable autenticada com App Check para listagem de pendências do Coordenador Geral.
- `functions/src/commands/decidirAtivacaoCoordenador.ts` -- Callable autenticada com App Check para transição atômica de homologação e ativação.
- `functions/src/index.ts` -- Exportação das novas Cloud Functions.
- `functions/test/decisaoCoordenador.test.ts` -- Suíte de testes no Vitest cobrindo autoridade, ativação de ciclos, vigência anual, concorrência, idempotência e decisão desfavorável.
- `flutter_app/lib/features/coordenador/coordenador_service.dart` -- Modelos, contrato `CoordenadorGateway` e implementações `FirebaseCoordenadorGateway` e `MemoriaCoordenadorGateway`.
- `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Tela mobile-first da fila do coordenador, histórico anterior, confirmação de reunião e diálogos modais acessíveis.
- `flutter_app/lib/features/admin/admin_shell.dart` e `flutter_app/lib/main.dart` -- Integração com navegação e injeção do gateway.
- `flutter_app/test/fila_coordenador_test.dart` -- Suíte de testes de widget e integração para a tela do Coordenador.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/decisaoCoordenador.ts` -- Criar contratos e validações de domínio.
- [x] `functions/src/repositories/decisaoCoordenador.ts` -- Implementar transação atômica de ativação de ciclos e redução de estado.
- [x] `functions/src/commands/obterFilaCoordenador.ts` -- Implementar callable de listagem.
- [x] `functions/src/commands/decidirAtivacaoCoordenador.ts` -- Implementar callable de decisão.
- [x] `functions/src/index.ts` -- Exportar novas callables.
- [x] `functions/test/decisaoCoordenador.test.ts` -- Criar testes unitários no Vitest.
- [x] `flutter_app/lib/features/coordenador/coordenador_service.dart` -- Criar serviços e gateways.
- [x] `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Criar tela mobile-first do coordenador.
- [x] Integrar no `admin_shell.dart` e `main.dart`.
- [x] `flutter_app/test/fila_coordenador_test.dart` -- Criar suíte de testes de widget.
- [x] Validar com `npm test`, `flutter test` e `flutter analyze`.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 3.3 para `done`.

**Acceptance Criteria:**
- Given uma ficha com aprovação local e ao menos uma participação aprovada pela equipe, when o Coordenador abre a fila, then visualiza voluntário, igreja, decisão local, participações, responsáveis e datas.
- Given uma solicitação elegível, when o Coordenador confirma a consulta na reunião de pastores e aprova, then o backend grava a confirmação, ativa somente as participações elegíveis e recalcula a ficha para `ATIVA`.
- Given a ativação concluída, when o ciclo anual é persistido em `ciclos`, then sua vigência é de exatamente um ano contado da homologação do Coordenador.
- Given o Coordenador toma decisão desfavorável, when submete o comando com justificativa interna, then as participações migram para `REJEITADA`, a ficha é recalculada e a mensagem neutra canônica é preservada ao voluntário.
- Given chamadas repetidas com o mesmo `commandId`, then o resultado original é devolvido de forma idempotente.

### Review Findings

- [x] [Review][Patch] Coordenador que não é Administrador não alcança a fila — `main.dart:299,361` só abre o `AdminShell` quando `possuiAdministracao()` é true, e `auth_service.dart:100` lê apenas a claim `maanaimAdmin`; o backend, porém, autoriza `COORDENADOR`/`maanaimCoordenador` (`repositories/decisaoCoordenador.ts:64`). Como a tab e a tela vivem só no `AdminShell`, um Coordenador-only é roteado para a tela de voluntário. Resolvido: opção 1 — rotear via claim `maanaimCoordenador`, expondo somente a Fila do Coordenador (menor privilégio).
- [x] [Review][Patch] Autoridade do Coordenador não atende AD-2 (vigência e instante da transação) — `validarAutoridadeCoordenador` (`repositories/decisaoCoordenador.ts:56-91`) chamado fora do `runTransaction` (`:216`), sem revalidação dentro dele, e aceita `coordenadores/{uid}` (`:72-77`) e `pessoas.coordenador` (`:80-88`) sem janela de vigência. Como `salvarPessoa` não limpa nem marca `ativo:false` em `coordenadores/{uid}` ao remover a designação (`repositories/pessoas.ts:198-210`), um ex-Coordenador continua autorizado pelo caminho 2. Resolvido: opção 1 — `autoridadesAdministrativas` como fonte canônica, com revalidação dentro da transação e snapshot de papel/vínculo na evidência.
- [x] [Review][Patch] Fila e redução ignoram participações ainda não terminais, permitindo conclusão/ativação parcial [functions/src/repositories/decisaoCoordenador.ts:107-121,288-354,397-423] — `obterFilaCoordenadorRepo` agrupa por `AGUARDANDO_COORDENADOR` sem exigir que a ficha esteja `AGUARDANDO_COORDENADOR` (contraria Story 3.2, "somente as participações aprovadas seguem para a fila" quando todas as pendências são resolvidas); a aprovação marca a ficha `ATIVA` sem verificar outra participação em `RASCUNHO`/`AGUARDANDO_PASTOR_LOCAL`/`AGUARDANDO_RESPONSAVEL_EQUIPE`; e a recusa reduz a ficha a `REJEITADA` considerando apenas outra `ATIVA`, ignorando pendências independentes.
- [x] [Review][Patch] UI exibe participação ainda não decidida como "Recusada" [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:520-568] — a renderização é binária por `elegivelAtivacao`; qualquer estado que não seja `AGUARDANDO_COORDENADOR` (ex.: `AGUARDANDO_RESPONSAVEL_EQUIPE`) aparece em vermelho como "Recusada", informação falsa ao Coordenador.
- [x] [Review][Patch] Recusa grava `confirmouReuniaoPastores: true` fabricado em evidência/auditoria [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:348-356; functions/src/repositories/decisaoCoordenador.ts:435,476] — o modal de recusa não coleta a confirmação, mas o cliente envia `true` e o backend persiste esse valor em `evidenciasDecisao` e `auditOutbox`, corrompendo a trilha da AD-6/AD-8.
- [x] [Review][Patch] Adaptação desktop (painel em tabela) não implementada e adaptação de tokens/overflow ausente [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:410,616,709] — `isCompact` é calculado e passado a `_buildCardPendencia`, mas nunca lido: renderiza sempre `ListView` de cards, contrariando o Approach ("painel com tabela no desktop"); usa `TextStyle` hardcoded em vez de `AppTypography` e `Row` no lugar de `OverflowBar`, com risco de overflow em telas estreitas.
- [x] [Review][Patch] `commandId` só com timestamp quebra idempotência em retry [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:209,348] — gerado em tempo de submissão sem sufixo aleatório (o peer usa `Random`+timestamp, `fila_responsavel_equipe_screen.dart:70`); um timeout seguido de nova tentativa cria outro `commandId` e perde o replay idempotente (`repetido:true`).
- [x] [Review][Patch] Datas exigidas pelo AC não são exibidas [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:488-504,552-563] — os modelos carregam `pastorLocalDecididoEm` e `responsavelDecididoEm`, mas o card só mostra nomes; o AC pede "voluntário, igreja, decisão local, participações, responsáveis, decisões e datas".
- [x] [Review][Patch] Evidência grava `papel: 'COORDENADOR'` fixo e sem snapshot de vínculo [functions/src/repositories/decisaoCoordenador.ts:365,434] — um `ADMINISTRADOR` aceito como autoridade é registrado como `COORDENADOR` e nenhum `vinculoId`/snapshot do ator é persistido, contrariando AD-2/AD-6.
- [x] [Review][Patch] Vigência não é autoritativa do servidor nem exata em ano bissexto [functions/src/repositories/decisaoCoordenador.ts:276-296] — `vigenciaInicio`/`vigenciaFim` usam `new Date().toISOString()` do processo, enquanto recibo/auditoria usam `serverTimestamp`; `setUTCFullYear(+1)` em 29/02 produz 01/03, e o AC exige "um ano contado da aprovação final".
- [x] [Review][Patch] Fila sem paginação e com N+1 [functions/src/repositories/decisaoCoordenador.ts:107-199] — lê todas as participações `AGUARDANDO_COORDENADOR` sem limite e faz leituras por ficha/igreja/equipe, contrariando AD-9 ("paginação limitada") e o padrão em lote do peer (`obterFilaResponsavelEquipeRepo`).
- [x] [Review][Patch] Verificação incompleta da mudança (testes/contratos) [functions/test/decisaoCoordenador.test.ts:360-454,610-676,679-695; functions/test/security-contract.test.ts:157-186; flutter_app/test/fila_coordenador_test.dart] — o teste de aprovação não lê a participação nem a ficha persistidas; o ramo DESFAVORAVEL que mantém a ficha `ATIVA` (outra participação ativa) não é exercido; a falha de decisão da tela (`erroAoDecidir`) não é testada; a tab do Coordenador no `AdminShell` não tem teste de fiação; a checagem de posse do recibo idempotente não é testada; e `security-contract.test.ts` não cobre as novas callables/domínio/repo nem inclui os callables do Coordenador na lista de exportação.
- [x] [Review][Patch] Validação de entrada inconsistente [functions/src/domain/decisaoCoordenador.ts:134-152,215-224] — o limite de 500 caracteres de `observacao` é aplicado só em `DESFAVORAVEL`, permitindo observação ilimitada na aprovação (persistida em ciclo/evidência); `normalizarDecisaoCoordenador` aceita aliases não documentados (`APROVAR`, `RECUSAR`, `RECUSADO`, `NEGATIVO`, `DESFAVORÁVEL`), ampliando a superfície além do contrato de dois valores.
- [x] [Review][Patch] `TextEditingController`s dos modais nunca são descartados [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:54,223] — criados a cada abertura de modal sem `dispose()`, vazando recursos.
- [x] [Review][Patch] Defaults de parsing e `voluntarioUid` enganosos [flutter_app/lib/features/coordenador/coordenador_service.dart:38-39,141-142; functions/src/repositories/decisaoCoordenador.ts:182,314] — `fromMap` assume `decisao='APROVADO'`/`estadoFicha='ATIVA'` quando ausentes e recomputa `elegivelAtivacao` a partir do estado; e `voluntarioUid` cai para o `fichaId` quando `ownerUid` falta, gravando id de ficha em campo de uid.
- [x] [Review][Patch] Textos inconsistentes com o comportamento [flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:276,700-704] — o modal de recusa diz que a justificativa "será gravada em auditoria", mas ela só vai para `evidenciasDecisao` e é excluída de `auditOutbox`; o estado vazio afirma que "todas as participações aprovadas foram homologadas e ativadas", o que também pode significar que nada chegou ao Coordenador.

#### Rejected

- `false` — Overwrite de `evidenciaRef`/`auditoriaRef` via `tx.set`: o `tx.create(reciboRef, …)` (`repositories/decisaoCoordenador.ts:455`) garante unicidade por `commandId` dentro da mesma transação, e o replay com recibo existente retorna/`throw` antes de qualquer `set`, então não há sobrescrita.
- `false` — Hunks de arquivos novos com caminho absoluto do host: artefato da construção do diff de revisão (`git diff --no-index /dev/null <abs>`), não do código versionado.
- `low` — `_processandoFichaId` único permite processar dois cards em paralelo: real mas mitigado por `expectedVersion`/idempotência, e a correção (conjunto de ids + desabilitar ações) vai além de uma correção direta; não vale o custo agora.
- `low` — `MemoriaCoordenadorGateway.decidir` sempre devolve `REJEITADA` e não espelha a redução AD-11: double de teste; a correção adiciona lógica de domínio ao fake, mais que uma correção direta, sem impacto em produção.

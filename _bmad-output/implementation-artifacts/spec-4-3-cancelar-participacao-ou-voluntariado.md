---
title: 'Story 4.3: Cancelar participação ou voluntariado'
type: 'feature'
created: '2026-10-07'
status: 'ready-for-dev'
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

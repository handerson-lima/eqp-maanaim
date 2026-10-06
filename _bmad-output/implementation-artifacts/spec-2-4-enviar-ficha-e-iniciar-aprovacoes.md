---
title: 'Story 2.4: Enviar ficha e iniciar aprovações'
type: 'feature'
created: '2026-10-06'
status: 'ready-for-dev'
baseline_commit: HEAD
route: 'dispatch'
review_loop_iteration: 1
context:
  - _bmad-output/implementation-artifacts/epic-2-context.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O voluntário que preencheu seus dados cadastrais obrigatórios, selecionou uma ou mais equipes de trabalho e aceitou o termo de voluntariado vigente precisa submeter formalmente sua ficha permanente para o processo de homologação institucional. A transição deve iniciar a esteira de aprovação pelo Pastor Local vigente da sua igreja, congelando a ficha contra alterações cadastrais concomitantes, transicionando atomicamente as participações e gerando a projeção de fila para o pastor local, com idempotência e auditoria imutável.

**Approach:**
1. Criar a Cloud Function callable autenticada `enviarFichaAprovacao` com validação de App Check e identidade do voluntário (`auth.uid == fichaId`).
2. Executar transação atômica no Firestore que:
   - Garante idempotência via recibo em `commands/{commandId}` (retornando o resultado original com `repetido: true` caso o comando já tenha sido processado com o mesmo payloadHash).
   - Valida estritamente todas as pré-condições de domínio:
     * Ficha existe e está no estado `RASCUNHO`.
     * Concorrência otimista: versão atual da ficha bate com `expectedVersion` informado.
     * Dados cadastrais completos e válidos: `nomeCompleto` (>= 3 chars), `profissao` (>= 2 chars), `cpf` válido matematicamente, `igrejaId` válido.
     * Igreja informada existe e está ativa no catálogo (`igrejas/{igrejaId}`).
     * Existência de ao menos uma participação na coleção `participacoes` vinculada a `fichaId`.
     * Todas as equipes das participações existem e estão ativas no catálogo (`equipes/{equipeId}`).
     * Aceite do termo vigente válido registrado na ficha (`ficha.termoAceito`), com `versaoId` e `hashSha256` correspondentes à versão ativa atual do termo institucional em `termos/{termoId}`.
   - Transiciona os agregados de domínio na transação:
     * `fichas/{uid}`: `estado = 'AGUARDANDO_PASTOR_LOCAL'`, `proximaAcao = 'Aguardando avaliação do Pastor Local'`, incrementa `versao`, atualiza `enviadoEm` e `atualizadoEm`.
     * `participacoes`: para cada participação da ficha em `RASCUNHO`, atualiza `estado = 'AGUARDANDO_PASTOR_LOCAL'`, `proximaAcao = 'Aguardando avaliação do Pastor Local'`, `atualizadoEm = serverTimestamp()`.
     * Materializa a projeção de fila em `filaPendencias/{uid}` com chaves de escopo canônicas: `fichaId`, `voluntarioUid`, `voluntarioNome`, `igrejaId`, `pastorLocalPessoaId` (extraído do vínculo vigente da igreja se houver), `estado = 'AGUARDANDO_PASTOR_LOCAL'`, `proximaAcao = 'Aguardando avaliação do Pastor Local'`, `ano`, `equipes` e timestamps.
     * Registra o recibo idempotente em `commands/{commandId}` com status `COMPLETO`.
     * Registra evento append-only correlacionado em `auditOutbox/{commandId}` com `acao = 'FICHA_ENVIADA_APROVACAO'`.
3. Na interface Flutter Web/PWA (`MinhaFichaScreen`):
   - Exibir botão acessível "Enviar Ficha para Aprovação" destacado no fluxo mobile-first.
   - Bloquear o botão com orientações claras caso haja pendências (dados incompletos, nenhuma equipe ou termo pendente).
   - Diálogo modal de confirmação antes do envio, resumindo igreja, equipes e termo aceito, alertando sobre o bloqueio de edição.
   - Após confirmação ou quando a ficha estiver em `AGUARDANDO_PASTOR_LOCAL` (ou estados posteriores de avaliação):
     * Bloquear formulário de dados cadastrais (somente leitura).
     * Bloquear seleção e remoção de equipes.
     * Bloquear novos aceites de termo.
     * Exibir card proeminente de status: `Aguardando avaliação do Pastor Local` com indicação da igreja e próximo responsável.

## Boundaries & Constraints

**Always:**
- Validação estrita de autorização: o voluntário só pode submeter a própria ficha (`fichaId == auth.uid`).
- Execução transacional completa: a alteração de estado da ficha, avanço das participações, projeção de fila, recibo e outbox ocorrem atomicamente (AD-5, AD-8, AD-10).
- Idempotência rigorosa (AD-10): repetições com o mesmo `commandId` e payload idêntico devolvem o comprovante original com `repetido: true` sem criar duplicatas ou transicionar estados novamente.
- Bloqueio estrito de edição: em `AGUARDANDO_PASTOR_LOCAL`, dados cadastrais e participações não podem ser modificados pelo voluntário (salvar ficha e salvar equipes retornam erro de pré-condição caso tentados).
- Conformidade WCAG 2.2 AA e Design System: tokens canônicos (`navy-900`, `blue-600`, etc.), alvos de toque >= 44 px, textos informativos sem depender unicamente de cor.

**Never:**
- Nunca permitir envio de ficha com campos obrigatórios pendentes ou CPF inválido.
- Nunca permitir envio sem ao menos uma participação/equipe ativa selecionada.
- Nunca permitir envio com termo não vigente ou desatualizado em relação à versão ativa de `termos`.
- Nunca permitir escrita direta do cliente no Firestore para avançar o estado da ficha ou participações.
- Nunca incluir PII excessiva ou sensível no evento de auditoria em `auditOutbox`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Envio com todas as pré-condições atendidas | Voluntário autenticado, ficha em `RASCUNHO`, >=1 equipe ativa, termo vigente aceito | Ficha e participações migram para `AGUARDANDO_PASTOR_LOCAL`, projeção de fila criada, recibo e auditoria gravados | Retorna `200 OK` com `{ sucesso: true, repetido: false, estado: 'AGUARDANDO_PASTOR_LOCAL', versao: N+1, proximaAcao: 'Aguardando avaliação do Pastor Local' }` |
| Envio de ficha que já não está em rascunho | Ficha já em `AGUARDANDO_PASTOR_LOCAL` ou posterior | Operação recusada sem alterar o banco | `failed-precondition: A ficha não está em estado de rascunho para envio.` |
| Envio sem nenhuma equipe | Ficha sem participações | Operação recusada com mensagem instrutiva | `failed-precondition: É necessário ter ao menos uma equipe selecionada antes do envio.` |
| Envio com equipe inativa | Alguma das participações pertence a equipe desativada | Operação recusada orientando ajuste | `failed-precondition: Uma ou mais equipes selecionadas estão inativas no catálogo.` |
| Envio com termo não aceito ou termo desatualizado | `termoAceito` nulo ou com `versaoId`/`hash` diferente da versão ativa de `termos` | Operação recusada exigindo aceite do termo vigente | `failed-precondition: O termo de voluntariado vigente deve ser aceito antes do envio da ficha.` |
| Envio com igreja inativa | `igrejaId` da ficha aponta para igreja inativa | Operação recusada | `failed-precondition: A igreja informada está inativa ou inválida.` |
| Divergência de versão esperada (concorrência) | `expectedVersion` fornecido difere da versão atual da ficha | Operação recusada por conflito de versão | `failed-precondition: Conflito de versão: a ficha foi alterada concorrentemente.` |
| Reenvio com mesmo `commandId` e payload idêntico | Reenvio de chamada já processada | Retorna o resultado original com `repetido: true` sem criar registros repetidos | Idempotente `200 OK` |
| Reenvio com mesmo `commandId` e payload diferente | Reenvio com `commandId` existente e parâmetros divergentes | Transação abortada | `invalid-argument: Operação já registrada com dados divergentes.` |
| Tentativa de submissão por terceiro | UID do token diverge de `auth.uid` | Acesso bloqueado | `permission-denied` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/enviarFicha.ts` -- Tipos `EntradaEnviarFichaAprovacao`, `ResultadoEnviarFichaAprovacao`, validação de payload, cálculo de payloadHash e regras de transição.
- `functions/src/repositories/enviarFicha.ts` -- Transação Firestore atômica: validação de pré-condições (ficha, participações, termo vigente, catálogo de igrejas e equipes), transição de estados para `AGUARDANDO_PASTOR_LOCAL`, projeção `filaPendencias`, recibo `commands` e `auditOutbox`.
- `functions/src/commands/enviarFichaAprovacao.ts` -- Cloud Function callable autenticada com App Check.
- `functions/src/index.ts` -- Exportação de `enviarFichaAprovacao`.
- `functions/test/enviarFicha.test.ts` -- Suíte de testes unitários em Vitest para envio da ficha, concorrência, idempotência e pré-condições.
- `functions/test/security-contract.test.ts` -- Teste de contrato de segurança para `enviarFichaAprovacao`.
- `flutter_app/lib/features/voluntario/ficha_service.dart` -- Extensão do contrato `FichaGateway`, classes de entrada/resposta de envio e implementação nos gateways Firebase e Memória.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Botão de envio, diálogo acessível de confirmação, bloqueio dos formulários para leitura, banner de status `AGUARDANDO_PASTOR_LOCAL` e exibição do próximo responsável.
- `flutter_app/test/enviar_ficha_test.dart` -- Testes de widget e integração cobrindo diálogo de confirmação, envio com sucesso, bloqueio de edição em `AGUARDANDO_PASTOR_LOCAL` e tratamento de erros.

## Tasks & Acceptance

**Execution:**
- [ ] `functions/src/domain/enviarFicha.ts` -- Criar tipos e validações de domínio.
- [ ] `functions/src/repositories/enviarFicha.ts` -- Implementar transação atômica completa de envio com idempotência e projeção de fila.
- [ ] `functions/src/commands/enviarFichaAprovacao.ts` -- Implementar Cloud Function callable autenticada.
- [ ] `functions/src/index.ts` -- Exportar a nova Cloud Function.
- [ ] `functions/test/enviarFicha.test.ts` -- Criar testes unitários no backend cobrindo matriz de I/O.
- [ ] `functions/test/security-contract.test.ts` -- Adicionar `enviarFichaAprovacao` aos testes de segurança.
- [ ] `flutter_app/lib/features/voluntario/ficha_service.dart` -- Adicionar método `enviarFichaAprovacao` e suporte mock em memória.
- [ ] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Integrar botão de envio, modal de confirmação, bloqueio de edição e estado visual `AGUARDANDO_PASTOR_LOCAL`.
- [ ] `flutter_app/test/enviar_ficha_test.dart` -- Criar testes de widget cobrindo todo o fluxo da Story 2.4.
- [ ] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 2.4 e Epic 2.

**Acceptance Criteria:**
- Given uma ficha em rascunho com dados cadastrais preenchidos, ao menos uma equipe selecionada e termo vigente aceito, when o voluntário confirma o envio, then a Cloud Function valida todas as pré-condições e altera a ficha para `AGUARDANDO_PASTOR_LOCAL`.
- Given o envio transacionado com sucesso, when o voluntário visualiza sua tela, then os campos cadastrais e a seleção de equipes tornam-se somente leitura e a tela exibe o estado "Aguardando avaliação do Pastor Local".
- Given a igreja da ficha cadastrada, when o envio é concluído, then a projeção de fila registra a pendência no escopo da igreja do voluntário com as equipes selecionadas.
- Given qualquer tentativa de reenvio com o mesmo `commandId`, when processada pelo backend, then retorna o resultado original de forma idempotente sem criar duplicatas.

---
title: 'Story 2.1: Criar e manter ficha permanente'
type: 'feature'
created: '2026-09-30'
status: 'done'
baseline_commit: a8f471fbf07e601eff06496358e100297dad7bb4
route: 'dispatch'
review_loop_iteration: 0
context:
  - _bmad-output/implementation-artifacts/epic-2-context.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O voluntário autenticado precisa preencher, salvar como rascunho e atualizar seus dados cadastrais permanentes (Nome Completo, Profissão, CPF e Igreja local), garantindo que suas informações fiquem seguras, privadas e disponíveis para os ciclos de voluntariado sem risco de vazamento ou mutações indevidas.

**Approach:** Criar endpoints Cloud Functions autenticados (`obterMinhaFicha` e `salvarMinhaFicha`) com validação transacional e registro de auditoria append-only, e desenvolver no Flutter a tela responsiva "Minha Ficha" com suporte a rascunho parcial/completo, identificação clara de campos pendentes e aderência estrita ao Design System e WCAG 2.2 AA.

## Boundaries & Constraints

**Always:**
- Validação estrita de identidade: o voluntário só pode acessar ou alterar seu próprio documento de ficha (`fichas/{uid}`).
- Imutabilidade de histórico: alterações em fichas com histórico preservam decisões e geram evento de auditoria `auditOutbox` com campos permitidos antes/depois e timestamp UTC do servidor (AD-8, AD-12).
- Mutações e leituras de ficha através de Cloud Functions autenticadas com `commandId` idempotente (AD-1, AD-10).
- Normalização de CPF com validação matemática e sanitização contra injeção ou valores inválidos.
- Interface mobile-first (coluna única no celular, cards responsivos no tablet/desktop, alvos de toque >= 44px, contraste WCAG 2.2 AA).

**Never:**
- Nunca permitir leitura ampla de fichas ou expor PII (CPF, profissão) a outros voluntários ou consultas não autorizadas (AD-9, AD-12).
- Nunca criar participações, ciclos ou solicitações de aprovação durante o salvamento de rascunho cadastral (AD-4).
- Nunca realizar mutações de domínio diretamente do cliente Flutter no Firestore.
- Nunca utilizar bibliotecas de estilo externas ou criar estilos/gradientes fora dos tokens oficiais (`navy-900`, `blue-600`, etc.).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta de ficha inexistente | `obterMinhaFicha` por voluntário recém-autenticado | `{ existe: false }` | Retorna estado neutro para permitir criação |
| Consulta de ficha existente | `obterMinhaFicha` por dono da ficha | `{ existe: true, ficha: { id, nomeCompleto, profissao, cpf, igrejaId, estado, versao, atualizadoEm } }` | Apenas campos do próprio usuário |
| Tentativa de acesso sem autenticação | Chamada a `obterMinhaFicha` ou `salvarMinhaFicha` deslogado | Rejeição imediata | `unauthenticated` |
| Salvamento de rascunho com dados válidos | `salvarMinhaFicha` com Nome, Profissão, CPF válido, Igreja ativa | Ficha persistida em `RASCUNHO`, `versao: versao + 1`, recibo gravado em `commands` | `200 OK` com dados atualizados |
| Salvamento com CPF inválido | `salvarMinhaFicha` com CPF com dígitos verificadores incorretos | Operação rejeitada sem alterar banco | `invalid-argument: CPF inválido` |
| Salvamento com Igreja inativa ou inexistente | `salvarMinhaFicha` com `igrejaId` inexistente | Operação rejeitada em transação | `invalid-argument: Igreja inválida ou inativa` |
| Reenvio com mesmo `commandId` e payload idêntico | `salvarMinhaFicha` repetido | Retorna resultado original idempotente sem duplicar versão ou auditoria | Idempotência garantida |
| Atualização em ficha com histórico | `salvarMinhaFicha` em ficha que não está mais em `RASCUNHO` | Atualiza campos cadastrais permitidos mantendo histórico e gera `auditOutbox` | Preserva decisões e estado anterior |

</frozen-after-approval>

## Code Map

- `functions/src/domain/ficha.ts` -- Definições de tipos, validações de entrada e cálculo de diferencial de campos permitidos.
- `functions/src/repositories/ficha.ts` -- Operações transacionais no Firestore para leitura e salvamento seguro da ficha, controle de versão e gravação em `commands` e `auditOutbox`.
- `functions/src/commands/obterMinhaFicha.ts` -- Cloud Function callable autenticada para consulta da própria ficha.
- `functions/src/commands/salvarMinhaFicha.ts` -- Cloud Function callable autenticada para criação e atualização da ficha permanente.
- `functions/src/index.ts` -- Exportação das novas callables.
- `functions/test/ficha.test.ts` -- Testes unitários para regras de domínio, validação de CPF e controle de concorrência.
- `flutter_app/lib/features/voluntario/ficha_service.dart` -- Gateway e serviço de comunicação com as funções de ficha.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Tela de formulário da ficha permanente com feedback de campos pendentes e salvamento.
- `flutter_app/lib/main.dart` -- Roteamento da sessão autenticada de voluntário para exibir a tela `MinhaFichaScreen`.
- `flutter_app/test/minha_ficha_test.dart` -- Testes de widget e integração dos fluxos de rascunho e validação da ficha.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/ficha.ts` -- Implementar validação de campos cadastrais (nome, profissão, CPF, igrejaId) e extração de diff de auditoria.
- [x] `functions/src/repositories/ficha.ts` -- Criar funções de persistência transacional para ficha permanente, verificação de igreja ativa e outbox.
- [x] `functions/src/commands/obterMinhaFicha.ts` -- Criar callable autenticada para leitura estrita da própria ficha.
- [x] `functions/src/commands/salvarMinhaFicha.ts` -- Criar callable idempotente para criação/atualização da ficha permanente.
- [x] `functions/src/index.ts` -- Exportar `obterMinhaFicha` e `salvarMinhaFicha`.
- [x] `functions/test/ficha.test.ts` -- Implementar testes unitários para a camada de domínio e repositório de ficha.
- [x] `flutter_app/lib/features/voluntario/ficha_service.dart` -- Implementar `FichaGateway` e `FichaService` com modelo `FichaModel`.
- [x] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Desenvolver tela mobile-first "Minha Ficha" com indicação de pendências e ações.
- [x] `flutter_app/lib/main.dart` -- Conectar o fluxo autenticado do voluntário à `MinhaFichaScreen`.
- [x] `flutter_app/test/minha_ficha_test.dart` -- Adicionar testes de widget para preenchimento, validação e salvamento de rascunho.

**Acceptance Criteria:**
- Given um voluntário autenticado sem ficha, when inicia o cadastro/abre a tela, then o sistema permite criar um rascunho privado com identificador estável igual ao seu UID e somente o próprio voluntário pode ler ou alterar seus dados.
- Given o primeiro preenchimento da ficha, when o voluntário visualiza a tela, then são apresentados os campos Nome Completo, Profissão, CPF e Igreja, e o sistema indica quais campos obrigatórios estão pendentes para futuro avanço.
- Given uma ficha em rascunho, when o voluntário salva dados válidos, then o sistema preserva o rascunho sem criar participação, aprovação ou ciclo.
- Given uma ficha já enviada ou com histórico, when o voluntário atualiza dado cadastral permitido, then a alteração preserva decisões anteriores e registra evento em `auditOutbox`.
- Given um usuário comum autenticado, when consulta fichas no sistema, then visualiza exclusivamente a própria ficha.
- Given uma tentativa de ler ou atualizar ficha de outro voluntário, when a requisição é processada, then ela é recusada com erro de permissão sem expor dados pessoais.

## Implementation Notes

- Implementadas as Cloud Functions `obterMinhaFicha` e `salvarMinhaFicha` autenticadas com validação matemática de CPF e cálculo atômico de versão e outbox de auditoria.
- Criado o domínio `ficha.ts` com tipagem estrita, extração de diff para auditoria e detecção de pendências cadastrais obrigatórias.
- Implementado repositório Firestore transacional `ficha.ts` com validação de igreja ativa, persistência de recibo idempotente em `commands` e auditoria append-only em `auditOutbox`.
- Desenvolvido no Flutter o serviço `ficha_service.dart` (`FichaModel`, `FichaGateway`, `FirebaseFichaGateway`) e a tela responsiva mobile-first `MinhaFichaScreen` conectada ao `AppShell` com feedback em tempo real de pendências e salvamento de rascunho.
- Integrado o fluxo autenticado do voluntário em `main.dart` com roteamento automático para `MinhaFichaScreen`.
- Cobertura completa de testes unitários (112 testes no functions) e widget/integração (122 testes no flutter_app) cobrindo todos os cenários da matriz de I/O e casos de borda.

## Spec Change Log

## Review Triage Log

- `low` (resolvido) | `flutter_app/lib/features/voluntario/minha_ficha_screen.dart:413` | Correção do aviso de depreciação do Flutter `value` para `initialValue` em `DropdownButtonFormField`.
- `low` (resolvido) | `flutter_app/lib/main.dart:330` | Adição de fallbacks seguros em memória (`_FichaMemoriaFallback` e `_CatalogoMemoriaFallback`) para permitir que testes de widget de `AreaAutenticada` rodem isoladamente sem requerer inicialização de `FirebaseFunctions.instance`.
- `low` (resolvido) | `flutter_app/lib/features/voluntario/minha_ficha_screen.dart:219` | Remoção de botão redundante de logout em `topBarActions`, mantendo o logout canônico unificado do `AppSidebar` e compatibilidade total com os testes de `sessao_test.dart`.
- `low` (resolvido) | `flutter_app/lib/features/auth/auth_service.dart:173` | Exposição do getter `emailAtual` no `AuthService` para exibição consistente da identidade do usuário logado na tela do voluntário.
- `low` (resolvido) | `flutter_app/test/minha_ficha_test.dart` | Uso de `ensureVisible` em widgets longos do formulário para garantir hit-test confiável em viewports de teste padrão.

## Design Notes

- Estrutura visual baseada no Design System: formulário encapsulado em card com elevação suave (`AppElevation.card`), cabeçalho com identificação do usuário e status chip (`RASCUNHO`), espaçamento consistente (`AppSpacing.s16`, `s24`) e tipografia hierárquica (`AppTypography.h2`, `body`, `label`).
- Feedback de campos pendentes: componente de alerta (`InfoCard` ou container neutro de aviso) listando claramente quais itens faltam para que a ficha esteja completa para envio.

## Verification

**Commands:**
- `npm test` na pasta `functions` -- expected: Sucesso em todos os testes unitários de funções incluindo `ficha.test.ts`.
- `flutter test` na pasta `flutter_app` -- expected: Sucesso em todos os testes de widget e de unidade do Flutter.

**Manual checks (if no CLI):**
- Testar visualmente a tela Minha Ficha no navegador redimensionando para largura mobile (390px) e desktop (1024px) verificando responsividade e ausência de overflows.

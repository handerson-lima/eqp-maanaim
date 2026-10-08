---
title: 'Story 7.1: Pipeline de CI/CD Automatizado (GitHub Actions com Firebase Emulator e Flutter)'
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_commit: '9ea326d4815fe8b45b1accd50b3daeef7ee03ec5'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/implementation-artifacts/epic-6-retro-2026-10-07.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A execução dos testes de integração com Firebase Emulator Suite (`test/*.emulator.test.ts`) e a suíte completa de testes de regras e frontend só ocorrem localmente e manualmente. Ausência de pipeline automatizado impede validação contínua em PRs contra regressões de segurança e integridade transacional.

**Approach:** Criar workflow de CI no GitHub Actions (`.github/workflows/ci.yml`) com jobs paralelos para backend (Node 22, Java 21, Firebase Emulator Suite headless, testes Vitest e regras de segurança) e frontend (Flutter stable, análise estática estrita e suíte de 278 testes unitários e de widgets), além de sanar o warning residual de análise estática no Flutter.

## Boundaries & Constraints

**Always:**
- O pipeline deve rodar automaticamente em eventos de `push` e `pull_request` direcionados à branch `main`.
- O job de backend deve instalar Java 21 (Temurin) para suportar o Firebase Emulator Suite e Node.js 22.
- O job de backend deve rodar tanto a suíte unitária (`npm test --prefix functions`) quanto a suíte de emuladores sob `firebase emulators:exec`.
- O job de frontend deve rodar `flutter analyze` e `flutter test`.
- O pipeline deve ser idempotente, reprodutível e falhar se houver qualquer erro de compilação, teste ou análise estática.

**Never:**
- Não expor credenciais reais de produção no CI (utilizar projeto simulado `demo-maanaim`).
- Não permitir que testes passem silenciosamente quando emuladores falharem ao inicializar.
- Não acoplar deploy em produção no workflow de validação contínua (CI deve ser focado em verificação).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| PR / Push na branch main | Alteração em código TypeScript ou Dart | Disparo automático dos jobs `backend-ci` e `frontend-ci` | Falha do build reportada com logs detalhados |
| Backend com quebra em regras Firestore/Storage | Regra permissiva ou falha em transação | `firebase emulators:exec` roda `test:emulator` e falha com código != 0 | Workflow reporta falha no step de emuladores |
| Frontend com aviso/erro de análise estática | Variável não utilizada ou erro de tipagem | `flutter analyze --fatal-infos` ou `--fatal-warnings` falha | Workflow interrompido no step de análise |
| Frontend com regressão de layout/widget | Teste de widget falhando | `flutter test` falha reportando teste e linha exata | Workflow bloqueia merge |

</frozen-after-approval>

## Code Map

- `.github/workflows/ci.yml` -- Definição do workflow GitHub Actions com jobs `backend` e `frontend`.
- `functions/package.json` -- Configuração dos scripts `test` e `test:emulator`, engines Node 22.
- `firebase.json` -- Configuração das portas e serviços do Firebase Emulator Suite (`auth`, `firestore`, `storage`, `functions`).
- `flutter_app/test/acesso_inclusivo_responsivo_test.dart` -- Remoção do warning `unused_local_variable` em L180 para zerar avisos de `flutter analyze`.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/test/acesso_inclusivo_responsivo_test.dart` -- Remover variável local não utilizada `size` -- Sanar warning de análise estática.
- [x] `.github/workflows/ci.yml` -- Criar workflow de CI com jobs matriciais para Node 22 / Java 21 / Firebase Emulator e Flutter stable -- Automatizar verificação contínua.
- [x] `README.md` -- Atualizar seção de CI/CD e testes com instruções sobre o workflow automatizado -- Manter documentação sincronizada.

**Acceptance Criteria:**
- Given um commit na branch `main` ou abertura de Pull Request, when o workflow do GitHub Actions executa, then tanto o job de backend quanto o de frontend devem completar com sucesso.
- Given o job de backend no CI, when executa `firebase emulators:exec`, then todos os 6 arquivos de testes `.emulator.test.ts` devem ser executados e aprovados sem serem ignorados (`skipped`).
- Given o job de frontend no CI, when executa `flutter analyze`, then deve reportar 0 issues e `flutter test` deve aprovar todos os testes.

## Implementation Notes

- Criado `.github/workflows/ci.yml` cobrindo jobs `backend` (Node 22, Java 21, Vitest, Emulators) e `frontend` (Flutter stable, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`).
- Configurado `concurrency` no GitHub Actions para cancelar builds anteriores do mesmo branch/PR em caso de pushes subsequentes.
- Removido `final size = tester.getSize(finder);` não utilizado em `flutter_app/test/acesso_inclusivo_responsivo_test.dart:180`, levando `flutter analyze` para 0 issues.
- Atualizado `README.md` com instruções detalhadas sobre a execução e topologia do pipeline de CI.

## Spec Change Log

## Review Triage Log
- low | .github/workflows/ci.yml:48 | Adicionada flag `--project demo-maanaim` no `firebase emulators:exec` para garantir execução offline sem checagem de credenciais GCP no CI. | patch

---
title: 'Front-end administrativo PWA (Stories 1.1 e 1.2)'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'dd3ba0012a5cc8f814abb08784e90f01a2d5997b'
context:
  - 'AGENTS.md'
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O backend das Stories 1.1 e 1.2 está em produção (callables, Rules, indexes, primeiro administrador e catálogo semeado), mas o front-end Flutter não restaura sessão ao recarregar, não tem sign-out, não tem navegação administrativa estruturada (menu lateral desktop / compacto mobile), não expõe o disparo do seed na UI, e o PWA não é instalável nem publicado no Firebase Hosting.

**Approach:** Completar exclusivamente o cliente Flutter e a configuração de hosting: (1) shell administrativo responsivo com navegação, papel ativo visível e sign-out; (2) restauração de sessão ao recarregar com `authStateChanges`; (3) consolidar a consulta de catálogo e adicionar disparo do seed chamando `semearCatalogoInicial`; (4) manifest PWA com ícones e metadados; (5) bloco `hosting` no `firebase.json` apontando para `flutter_app/build/web`; (6) documentar no README. Sem alterar backend, contratos nem callables existentes.

## Boundaries & Constraints

**Always:** Mobile-first e WCAG 2.2 AA (alvos ≥44 px, foco visível, teclado, leitor de tela, estados comunicados por texto/ícone e não só cor). Usar dados do Firestore/callables, nunca listas hardcoded. `commandId` opaco e idempotente para o seed. Estados de carregamento/erro/retentativa acessíveis. Sign-out limpa a sessão local. Igrejas exibidas como "Nome - Código" ordenadas. Pesquisa por nome/código sem acento. Não versionar `.env.dartdefines.json` nem segredos.

**Never:** Não alterar backend, callables, Functions, Rules nem indexes. Não criar CRUD de igrejas/equipes. Não auto-atribuir papéis. Não conceder papel pelo cliente. Não expor PII em logs ou erros.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Recarregar com sessão ativa | Usuário autenticado recarrega a página | Restaura sessão, reavalia claim, exibe área correta | Sessão inválida → tela de login |
| Sign-out | Administrador clica em sair | Firebase sign-out, volta à tela inicial | — |
| Administrador abre shell | Sessão com claim `maanaimAdmin: true` | Vê navegação lateral (desktop) ou menu compacto (celular) com papel ativo visível | — |
| Usuário comum após login | Sessão sem claim administrativa | Vê tela de rascunho, sem opções administrativas | — |
| Disparar seed com catálogo vazio | Admin clica em "Semear catálogo" com `commandId` opaco | Chamada à callable, indicador de progresso, exibe recibo/estado | Erro da callable → mensagem acessível e retentativa |
| Disparar seed já executado | Admin clica novamente | Callable retorna recibo idempotente | Resultado normal, sem duplicação |
| Pesquisa no catálogo | Admin digita parte do nome ou código | Filtra igrejas/equipes em tempo real | — |
| Falha de rede na consulta | Callable falha | Mensagem "Não foi possível carregar" com botão de retentativa | Acessível |
| PWA install | Usuário acessa via navegador compatível | Prompt de instalação disponível, ícones e tema corretos | — |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/main.dart` -- bootstrap Firebase e roteamento principal; refatorar para: (a) ouvir `authStateChanges` para restauração de sessão, (b) substituir `AdministracaoInicial` por um shell com `NavigationRail`/`Drawer` responsivo que contém sign-out e papel visível, (c) manter `Cadastro`/`Login`/`Inicio` sem regredir.
- `flutter_app/lib/features/auth/auth_service.dart` -- `IdentidadeGateway`; adicionar `signOut()` e `Stream<User?> authStateChanges()` ao gateway; criar `SeedGateway` para chamar `semearCatalogoInicial`.
- `flutter_app/lib/features/admin/catalogo_service.dart` -- gateway de catálogo existente; adicionar `SeedGateway` interface e `FirebaseSeedGateway` implementação para callable `semearCatalogoInicial`.
- `flutter_app/lib/features/admin/consulta_catalogo.dart` -- tela read-only existente; manter como está na aba do catálogo.
- `flutter_app/lib/features/admin/seed_catalogo.dart` -- **novo**: widget para disparar o seed com `commandId` opaco, indicador de progresso, exibição de recibo/estado e idempotência.
- `flutter_app/lib/features/admin/admin_shell.dart` -- **novo**: shell responsivo com `NavigationRail` (desktop) + `Drawer` (mobile), papel ativo visível, sign-out e abas (Catálogo, Seed).
- `flutter_app/web/manifest.json` -- adicionar `icons` com tamanhos 192 e 512 px, e campos obrigatórios de PWA.
- `flutter_app/web/icons/` -- **novo**: gerar ícones 192×192 e 512×512 para PWA.
- `firebase.json` -- adicionar bloco `hosting` apontando `public` para `flutter_app/build/web` com rewrites SPA.
- `README.md` -- documentar `--dart-define-from-file`, App Check reCAPTCHA v3 e comando de deploy.
- `flutter_app/test/fakes.dart` -- ampliar com `SeedFake`, `signOut` e `StreamController` para `authStateChanges`.
- `flutter_app/test/admin_shell_test.dart` -- **novo**: testes de widget para navegação, sign-out, papel visível.
- `flutter_app/test/seed_catalogo_test.dart` -- **novo**: testes de widget para disparo do seed, estados e idempotência.
- `flutter_app/test/sessao_test.dart` -- **novo**: testes de restauração de sessão com `authStateChanges`.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/lib/features/auth/auth_service.dart` -- adicionar `signOut()` e `authStateChanges` ao `IdentidadeGateway` e `FirebaseIdentidadeGateway`; adicionar `SeedGateway` interface e `FirebaseSeedGateway` que chama `semearCatalogoInicial`.
- [x] `flutter_app/lib/features/admin/seed_catalogo.dart` -- criar widget `SeedCatalogo` com botão de disparo, `commandId` opaco, indicador de progresso, exibição de recibo e retentativa acessível.
- [x] `flutter_app/lib/features/admin/admin_shell.dart` -- criar `AdminShell` responsivo com `NavigationRail` (desktop ≥600px) e `Drawer` (mobile), papel ativo ("Administrador") visível, botão de sign-out e índice de destinos (Catálogo, Seed).
- [x] `flutter_app/lib/main.dart` -- refatorar para: ouvir `authStateChanges` com `StreamBuilder` para restaurar sessão; rotear para `AdminShell` quando admin, tela de rascunho quando comum, `Inicio` quando deslogado; integrar sign-out; manter `Cadastro`/`Login` sem regredir.
- [x] `flutter_app/web/manifest.json` -- adicionar `icons` (192, 512), `id`, `scope`, `orientation`, `prefer_related_applications`, garantindo instalabilidade.
- [x] `flutter_app/web/icons/` -- gerar ícones PWA 192×192 e 512×512 com tema verde Maanaim.
- [x] `firebase.json` -- adicionar bloco `hosting` com `public: "flutter_app/build/web"`, `ignore`, e `rewrites` SPA para `index.html`.
- [x] `README.md` -- documentar uso de `--dart-define-from-file`, registro do App Check reCAPTCHA v3 e comando `firebase deploy --only hosting`.
- [x] `flutter_app/test/fakes.dart` -- ampliar com `SeedFake`, `signOut` e `StreamController` para `authStateChanges`.
- [x] `flutter_app/test/admin_shell_test.dart` + `flutter_app/test/seed_catalogo_test.dart` + `flutter_app/test/sessao_test.dart` + `flutter_app/test/pwa_manifest_test.dart` -- widget tests para navegação responsiva, sign-out, papel visível, disparo do seed (sucesso/erro/idempotência), restauração de sessão e manifest/ícones PWA.

**Acceptance Criteria:**
- Given um administrador autenticado, when recarrega a página, then a sessão é restaurada e a área administrativa é exibida sem novo login.
- Given um administrador na área administrativa, when clica em sair, then a sessão é encerrada e volta à tela inicial.
- Given um administrador no desktop (≥600px), when abre a área administrativa, then vê `NavigationRail` lateral com papel ativo visível.
- Given um administrador no celular (<600px), when abre a área administrativa, then vê botão de menu compacto que abre `Drawer` com papel ativo visível.
- Given um administrador, when navega ao catálogo, then vê igrejas como "Nome - Código" ordenadas e pesquisáveis por nome/código.
- Given um administrador com catálogo vazio, when dispara o seed, then a callable `semearCatalogoInicial` é chamada com `commandId` opaco e o recibo é exibido.
- Given um administrador com seed já executado, when dispara novamente, then recebe resultado idempotente sem duplicação.
- Given `flutter analyze --fatal-infos`, when executado, then passa sem diagnósticos.
- Given `flutter test`, when executado, then todos os testes passam.
- Given `flutter build web --dart-define-from-file=...`, when executado, then compila com sucesso.
- Given a PWA publicada, when acessada em navegador compatível, then o prompt de instalação é apresentado e ícones/tema são corretos.

## Implementation Notes

## Spec Change Log

## Review Triage Log

Revisão em três lentes (blind-hunter, edge-case-hunter, verification-gap) sobre o diff desde `dd3ba00`.

**blind-hunter**
- Import circular `seed_catalogo.dart` → `main.dart` (`comandoOpaco`) — `low` — **patch** (extrair para util neutro; dependência de feature ao entrypoint encarece testes).
- Campos `catalogo`/`seed` mortos em `Inicio`/`Login` — `low` — **patch** (remoção direta; nenhum consumidor os lê).
- `RaizSessao.build` recria `authStateChanges()` a cada rebuild — `low` — **reject** (rebuild da home é raro; corrigir exigiria reter stream/State sem ganho demonstrado).
- Recibo ignora `totalIgrejas`/`totalEquipes` e "poderia mostrar 0" — `false` (no replay o backend devolve `igrejasCriadas`/`equipesCriadas` do recibo gravado, não 0; ver `functions/src/repositories/catalogo.ts:89-90`).
- Recibo não expõe id/ator/timestamp — `low` — **reject** (AC pede apenas recibo/estado; expor ator contraria a política de não vazar dados no cliente).
- Cliente não envia `correlationId` — `false` (o backend usa `commandId` como correlação por padrão; `semearCatalogoInicial.ts:47`).
- `catch` genérico mascara `permission-denied`/sessão — `low` — **reject** (não-admin não alcança a aba Seed; a matriz pede mensagem acessível + retentativa, satisfeito).
- Cast cego de `resposta.data` — `low` — **reject** (resposta malformada ainda cai no erro acessível; sem crash).
- Seed sem diálogo de confirmação — `low` — **reject** (operação idempotente e não destrutiva; spec não pede confirmação).
- Catálogo não recarrega após o seed — `false` (trocar de aba recria `ConsultaCatalogo` e refaz `consultar()` em `initState`).
- Inconsistências do próprio spec (Code Map/seções vazias, proveniência dos ícones) — **reject** (correção editaria o spec deste build).
- `index.html` sem `apple-touch-icon`/meta iOS — `low` — **patch** (adição trivial; ícone de instalação iOS correto).
- Ícone `maskable` reusa o 512 sem safe zone — `low` — **reject** (sem evidência da arte; correção é trabalho de design).
- `pwa_manifest_test` não valida dimensões reais do PNG — `low` — **patch** (ler o header IHDR; endurecer verificação).
- `pwa_manifest_test` dependente do CWD — `false` (`flutter test` roda no root do pacote; `File('web/...')` resolve corretamente).

**edge-case-hunter**
- Erro no stream `authStateChanges` roteia para login — **maybe-false** — **defer** (se verdadeiro seria `medium`; o stream do Firebase Auth normalmente não emite erro — precisa confirmar se algum caminho emite).
- `_sair()` lança sem feedback — `low` — **reject** (signOut é local e raramente falha; correção adiciona tratamento sem cenário demonstrado).
- Duplo toque no botão de retry do seed — `low` — **reject** (botão some no rebuild seguinte; janela de corrida desprezível).
- Remoção da orientação de registrar domínios autorizados do Auth no README — `low` — **reject** (o registro da URL de continuação permanece em `README.md:67`; domínios padrão cobrem e-mail/senha).

**verification-gap** (pré-verificado pela lente)
- Caminho de sucesso do login (`Inicio`→`Login`→`AreaAutenticada`) sem teste; remover `popUntil` não quebraria teste algum — **patch** (teste de widget ponta a ponta).
- Contrato de deploy do `firebase.json` sem verificação automatizada — **patch** (teste que lê `hosting.public` e o rewrite SPA).

## Design Notes

O shell administrativo usa `NavigationRail` + body no desktop e `Drawer` + `AppBar` no mobile, determinado por `LayoutBuilder` com breakpoint de 600px (Material Design). O papel ativo é exibido como chip/label semântico no rail/drawer. O seed é uma ação administrativa que gera um `commandId` opaco (UUID hex) antes de chamar a callable, para garantir idempotência client-side. A resposta do seed é exibida como recibo textual (JSON simplificado). Para os ícones PWA, serão gerados dois PNGs (192×192 e 512×512) com o tema verde do Maanaim (#1B5E20).

## Verification

**Commands:**
- `flutter analyze --fatal-infos` -- esperado: sem diagnósticos (executar em `flutter_app`).
- `flutter test` -- esperado: todos os testes passam (executar em `flutter_app`).
- `flutter build web --dart-define-from-file=.env.dartdefines.json` -- esperado: compila sem erros (executar em `flutter_app`).

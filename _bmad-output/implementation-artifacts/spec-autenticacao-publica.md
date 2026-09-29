---
title: 'Autenticação pública de voluntários'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '6ec97d57d0677b7a4665e0cc720fae4a62c81cfa'
context:
  - 'AGENTS.md'
  - '_bmad-output/specs/spec-autenticacao-publica/SPEC.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Voluntários não possuem uma entrada pública para criar a identidade que inicia sua ficha, e pessoas pré-cadastradas administrativamente, inclusive pastores, não possuem na interface um caminho seguro para definir ou recuperar senha. A identidade precisa ser criada sem permitir que login conceda autoridade de domínio.

**Approach:** Entregar telas públicas Flutter para cadastro e recuperação e conectá-las a Firebase Authentication por e-mail/senha. Depois de autenticar, criar ou retomar o rascunho privado somente por Cloud Function, mantendo papéis, vínculos, escopos e qualquer transição de domínio fora desse fluxo.

## Boundaries & Constraints

**Always:** Usar Firebase Authentication para e-mail/senha e recuperação; coletar no cadastro Nome Completo, Profissão, CPF, igreja administrável, e-mail e senha; realizar mutação de rascunho exclusivamente em Cloud Function autenticada com App Check; manter Firestore deny-by-default para domínio; usar IDs opacos e tempo de servidor; apresentar resposta neutra à recuperação; proteger PII de logs, erros, auditoria e notificações; respeitar Flutter Web/PWA mobile-first, WCAG 2.2 AA, teclado, leitor de tela, foco visível e alvos de 44 px.

**Never:** Conceder ou inferir papel, vínculo ou escopo no cadastro/redefinição; aceitar escrita direta de ficha, participação, ciclo, papéis ou vínculos; enviar convite automático a pastores importados; usar igrejas/equipes hardcoded; guardar senha, token ou e-mail em auditoria, notificação ou telemetry; implementar aprovação, seleção definitiva de equipes, MFA ou provedores sociais nesta entrega.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cadastro válido | Visitante sem sessão; campos obrigatórios e senha válidos | Firebase Auth cria identidade; função autenticada cria/retoma rascunho privado associado ao UID | Mostra próxima ação; nenhuma elevação de privilégio |
| Dados inválidos | Campo obrigatório ausente, e-mail malformado ou senha recusada | Nenhuma escrita de domínio é concluída | Erro acessível por campo, sem ecoar PII ou detalhe interno |
| Retentativa após falha | Identidade criada, mas função de rascunho falhou | Sessão pode retentar e função cria/retoma um único rascunho permitido | Resultado idempotente e mensagem segura |
| Redefinição | E-mail informado na tela de login | Firebase Auth envia link seguro se a conta existir | Resposta sempre neutra; não enumera contas |
| Pastor importado | Conta administrativa criada sem senha/invite | Mesmo fluxo permite definir senha | Não cria/muda papel ou vínculo |
| Escrita de cliente | Cliente tenta mutar domínio no Firestore | Rules recusam | Falha genérica, sem dados de domínio |

</frozen-after-approval>

## Code Map

- `AGENTS.md` -- política obrigatória de domínio, PII, autorização contextual e acessibilidade.
- `_bmad-output/specs/spec-autenticacao-publica/SPEC.md` e `authentication-flow.md` -- contrato da mudança, jornadas e critérios de sistema.
- `_bmad-output/specs/spec-gestao-voluntarios-maanaim/SPEC.md` -- contrato principal; CAP-1, restrições e companions vinculantes.
- `_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md` -- AD-1, AD-2, AD-9, AD-10 e AD-12 governam Auth, Functions, Rules e PII.
- `_bmad-output/planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/{DESIGN,EXPERIENCE}.md` -- padrões mobile-first, tokens e jornada de primeiro cadastro.
- `_bmad-output/implementation-artifacts/spec-importacao-inicial-de-pastores-e-vinculos.md` -- contrato já aprovado: carga cria contas de pastores sem convite e aponta para esta recuperação.
- Repositório de código -- ainda não há bootstrap Flutter, Firebase, Functions, Rules, configurações ou testes; esta entrega estabelece o substrato mínimo sem alterar a carga administrativa.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/`, `pubspec.yaml` e configuração PWA/Firebase por ambiente -- criar bootstrap Flutter Web responsivo, inicialização segura de Firebase e dependências de Auth sem segredos versionados.
- [x] `flutter_app/lib/features/auth/` -- implementar início, cadastro, login e recuperação com validação acessível, indicadores sem cor exclusiva e ações de 44 px.
- [x] `functions/commands/criarOuRetomarRascunho.*` e módulos de domínio/repositório -- criar comando autenticado, validado por App Check e idempotente, que recebe somente dados permitidos e não concede autorização.
- [x] `firestore.rules`, índices/configuração Firebase e `functions` de bootstrap -- negar escrita direta de domínio, permitir somente leituras mínimas necessárias de dados administráveis e configurar o projeto para Emulator.
- [x] `flutter_app/test/`, `functions/**/*.test.*` e testes Emulator -- cobrir cadastro, recuperação neutra, falha/retentativa, negação de escrita e ausência de elevação de privilégio/PII em saídas; testes de contrato passaram, mas a Firebase CLI falhou antes de iniciar o Emulator neste ambiente.
- [x] `README.md` ou documentação operacional -- fixar versões/comandos de bootstrap, configuração de domínios/URLs de redefinição por ambiente e fluxo de pastor importado sem registrar valores sensíveis.

**Acceptance Criteria:**
- Given um visitante em celular ou desktop, when abre a tela inicial, then encontra e opera “Cadastre-se” por toque ou teclado com rótulo anunciado pelo leitor de tela.
- Given um cadastro válido, when a identidade e o rascunho são criados, then o usuário só pode ler seu estado permitido e não obtém papel, vínculo, escopo, participação ou aprovação.
- Given um e-mail cadastrado, when usuário solicita recuperação, then recebe link de Firebase Auth para nova senha; and a resposta da interface não revela se o e-mail existe.
- Given pastores cadastrados pela carga, when acessam recuperação, then podem definir senha sem convite automático e preservam os papéis/vínculos já administrados.
- Given regras, Functions e UI sob teste, when uma tentativa inclui escrita direta, dados inválidos ou telemetria de falha, then a mutação é recusada/segura e nenhum e-mail, CPF, senha ou token é exposto.

## Implementation Notes

- Bootstrap Flutter/Firebase, Functions, Rules e documentação foram criados. App Check Web é ativado antes da UI por chave pública fornecida em `dart-define`; nenhuma configuração de ambiente foi versionada, e falha de bootstrap cai em `ConfiguracaoAusente`.
- O `commandId` é opaco (`Random.secure()`) e preservado pela tela durante retentativas após criação de identidade; o recibo grava `payloadHash` e `correlationId`, então replay do mesmo comando com dados diferentes é recusado e não há recibo/outbox adicional para retomada sem mutação.
- Rodada de review (2) aplicou as correções do triage log: vínculo de identidade por e-mail, recibo ligado ao conteúdo, evidência correlacionada, ficha não legível pelo cliente, alvos de 44 px, login não concorrente, seleção de igrejas resiliente, guarda de bootstrap, formatador de CPF e testes executáveis do handoff/resposta neutra.
- `flutter analyze`, `flutter test` (8), `npm test --prefix functions` (8, com typecheck) e `npm run build --prefix functions` passaram. `firebase emulators:exec` não iniciou devido a falha da Firebase CLI que produziu `firepit-log.txt`; integração Emulator permanece pendente de ambiente funcional.

## Spec Change Log

## Review Triage Log

Rodada 2 (retomada): as camadas blind-hunter, edge-case-hunter e verification-gap foram reexecutadas sobre o diff desde o baseline. Cada achado recebeu um verdicto; `carried` marca os que já constavam da rodada anterior.

### Patch — corrigidos nesta rodada

- `flutter_app/lib/features/auth/auth_service.dart:18` — (carried) sessão de qualquer conta pulava a criação de identidade e podia gravar nova inscrição sob UID alheio; retentativa não distinguia resultado. Corrigido com `precisaCriarIdentidade(emailAtual, alvo)`, que só reaproveita a sessão do mesmo e-mail, e gateways `IdentidadeGateway`/`RascunhoGateway` testáveis.
- `functions/src/commands/criarOuRetomarRascunho.ts:17` — (carried) recibo idempotente não vinculava o comando ao conteúdo nem preservava resultado; mesmo `commandId` com dados diferentes descartava a edição, e recibo sem ficha reportava sucesso. Corrigido: `hashRascunho` grava `payloadHash`; replay divergente é recusado (`already-exists`) e ficha ausente é recriada na mesma transação.
- `functions/src/commands/criarOuRetomarRascunho.ts:25` — (carried) criação de rascunho não gerava evidência correlacionada. Corrigido: recibo e `auditOutbox` carregam `commandId`/`correlationId`/`actorUid`, sem PII.
- `firestore.rules:5` — (carried) leitura direta expunha a ficha (CPF/PII) e o catálogo completo. Corrigido: leitura direta de `fichas` negada (estado permitido vem só da callable); `igrejas/{id}` mantém `get`/`list` apenas de itens `ativo`, com escrita negada.
- `flutter_app/lib/main.dart:67` — (carried) alvos de toque abaixo de 44 px e login aceitava envios concorrentes. Corrigido: temas de `ElevatedButton`/`OutlinedButton`/`TextButton` com `minimumSize (44, 48)`; `carregando` desabilita o botão durante o `entrar`.
- `flutter_app/lib/main.dart:214` — (carried) seletor de igrejas falhava em silêncio e podia quebrar quando o valor selecionado saía dos itens. Corrigido: trata `hasError`/`!hasData`, reconcilia a seleção e usa `key` pelo conjunto de IDs.
- `flutter_app/lib/main.dart:146` — (carried) `commandId` previsível não atendia a identificador opaco. Corrigido: `comandoOpaco()` gera 16 bytes de `Random.secure()` em hex.
- `flutter_app/lib/main.dart:350` — `setState` após descarte na falha de login. Corrigido: guardas `mounted` no `catch` e `finally`.
- `flutter_app/lib/main.dart:39` — `Firebase.initializeApp`/App Check sem guarda derrubavam a tela em branco. Corrigido: `try/catch` com fallback `ConfiguracaoAusente`.
- `flutter_app/lib/main.dart:212` — CPF aceitava qualquer caractere. Corrigido: `FilteringTextInputFormatter.digitsOnly`.
- `README.md:3` — versão Dart divergia do lock (`>=3.5` vs `>=3.11`). Corrigido: `pubspec.yaml` e README alinhados a `>=3.11`.
- `README.md:7` — (carried) enumeração de e-mail sem proteção documentada. Corrigido: seções de recuperação/enumeração e modelo de dados das coleções.
- `firebase.json:3` / `functions` — `test/` publicado no deploy, testes fora do typecheck e formato ESM ambíguo. Corrigido: `ignore` de `test`, `tsconfig.test.json` com `typecheck` no `test`, `"type": "module"`.
- `functions/test/security-contract.test.ts:28` — asserções vacuosas (`?? ''`). Corrigido: regex passou a exigir match (`toBeDefined`) e ganhou asserções de `payloadHash`/`correlationId`/rules; `hashRascunho` tem teste de determinismo e sensibilidade a cada campo.
- `flutter_app/lib/features/auth/auth_service.dart:12` / `main.dart:291` — (carried) handoff Auth→callable e resposta neutra sem teste executável. Corrigido: `auth_service_test.dart` (fakes) cobre criação, retentativa, UID alheio e recuperação; `login_recuperacao_test.dart` verifica a resposta neutra quando a recuperação falha.

### Defer — registrados em `deferred-work.md`

- Integração por Firebase Emulator da transação da callable e das Rules permanece pendente (a CLI falha ao iniciar neste ambiente) — item já aberto.
- Manifesto PWA sem ícones; sem `hosting`/`.firebaserc`; sem restauração de sessão/sign-out; sem verificação de e-mail; sem unicidade de CPF; ficha modelada por UID; estado da callable descartado no cliente; `commands`/`auditOutbox` sem consumidor/TTL; verificação automatizada de acessibilidade; CI; retenção/minimização de PII; validação duplicada Dart/TS.

### Rejeitados

- `false` — recuperação "engole" erros: a resposta uniforme é requisito explícito do intent (anti-enumeração); manter neutra é o comportamento correto.
- `false` — `igrejas.list` sem App Check nas Rules: Rules do Firestore não expressam App Check (é configuração de projeto) e o catálogo não contém PII.
- (carried) `false` — `flutter_app/pubspec.lock` contém uma única entrada `clock`, portanto não há chave YAML duplicada.
- (carried) `false` — `expectedVersion` não é necessário para a criação imutável de um agregado inexistente nem para a retomada sem mutação; a transação já serializa ambas as condições.

## Design Notes

Separar identidade de domínio evita que a criação de conta contorne a cadeia de aprovação. O rascunho precisa tolerar o intervalo entre Firebase Auth bem-sucedido e a primeira chamada autenticada, para que uma falha de rede não gere uma segunda ficha. A recuperação usa confirmação uniforme porque diferenças observáveis transformariam a tela pública em oráculo de contas.

## Verification

**Commands:**
- `flutter test` -- esperado: validação de formulário, semântica/fluxos de UI e cliente de Auth aprovados.
- `npm test --prefix functions` -- esperado: comando de rascunho, autorização e redaction aprovados.
- `firebase emulators:exec <suite>` -- esperado: Rules e Functions recusam escrita direta e cobrem fluxos autenticados.

**Manual checks:**
- Abrir o app em largura móvel e desktop; concluir cadastro, pedir recuperação e navegar integralmente por teclado/leitor de tela, confirmando foco, mensagens neutras e alvos de 44 px.

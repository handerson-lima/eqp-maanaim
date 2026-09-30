---
title: 'Publicação e versionamento do primeiro termo'
type: 'feature'
created: '2026-09-30'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '69223c50d73063a3886fa0be519234f4a041ed37'
context:
  - 'AGENTS.md'
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema não possui mecanismo para publicar e versionar o termo de adesão ao voluntariado. Sem um termo canônico com conteúdo imutável, hash criptográfico e data/hora UTC auditável, os voluntários nos Epics 2 e 5 não teriam como registrar aceites juridicamente inequívocos e referenciáveis.

**Approach:** Criar comandos de backend em Cloud Functions (`publicarTermo`, `consultarTermos`, `obterTermoVigente`) com RBAC administrativo, App Check e transação Firestore atômica (versão imutável, hash SHA-256, recibo idempotente em `commands/{commandId}` e evento em `auditOutbox/{commandId}`), regras no Firestore negando qualquer alteração ou exclusão de versões publicadas, e uma superfície administrativa mobile-first no Flutter integrada ao `AdminShell` com componentes do design system.

## Boundaries & Constraints

**Always:** Mutações críticas executadas exclusivamente por Cloud Function v2 autenticada com App Check ativado e autoridade administrativa revalidada em transação (`podeAdministrar`); cada versão publicada é estritamente imutável (impossível alterar ou excluir via API ou Rules); cada versão possui identificador opaco, número sequencial da versão (`versao`), título, conteúdo canônico, hash SHA-256 em hexadecimal, `publicadoEm` (Timestamp UTC do servidor), `publicadoPorUid` e ponteiro para a versão anterior (`versaoAnteriorId`); o documento pai `termos/{termoId}` aponta atomicamente para a `versaoVigenteId`, `versaoVigenteNumero`, `hashSha256` e `atualizadoEm`; publicação de nova versão preserva integralmente as versões anteriores e identifica o quantitativo de voluntários ativos impactados na auditoria sem alterar aceites históricos; todo comando utiliza padrão idempotente com `commandId`, `correlationId`, `payloadHash`, recibo `commands/{commandId}` e auditoria `auditOutbox/{commandId}` no mesmo commit transacional; respostas de erro neutras sem vazamento de PII ou estrutura interna; interface Flutter Web/PWA mobile-first, acessível (WCAG 2.2 AA, alvos ≥44px, foco, semáforo semântico com ícone+texto) e reutilizando os componentes canônicos (`PageHeader`, `AppCard`, `PrimaryButton`, `StatusChip`, tokens de `tokens.dart`).

**Never:** Não permitir edição direta, atualização pontual (`update`) ou exclusão física (`delete`) de versão de termo já publicada — correções exigem obrigatoriamente a publicação de nova versão; não permitir publicação sem autenticação, sem App Check ou por usuário sem autoridade administrativa vigente; não permitir conteúdo ou título vazios; não armazenar PII em recibos, logs ou auditoria; não expor dados de voluntários fora do escopo; não usar cores ou gradientes fora do design system institucional.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Primeira publicação de termo | Admin autenticado, termo inexistente, título e conteúdo válidos, `commandId` | Cria `termos/{termoId}` e versão 1 imutável em `termos/{termoId}/versoes/{versaoId}`; gera SHA-256 e UTC; registra recibo e auditoria com `totalImpactados: 0` | Sucesso (`concluido: true`, `versao: 1`) |
| Publicação de nova versão | Admin autenticado, termo existente com versão 1 vigente, novo texto | Cria versão 2 imutável com `versaoAnteriorId` apontando para a versão 1; atualiza ponteiro vigente no termo pai; versão 1 permanece intacta; audita total de voluntários impactados | Sucesso (`concluido: true`, `versao: 2`) |
| Replay de comando idêntico | Mesmo `commandId` e mesmo `payloadHash` | Retorna resultado original idempotente sem criar nova versão duplicada | Retorna recibo persistido (`repetido: true`) |
| Replay com payload divergente | Mesmo `commandId` com `payloadHash` distinto | Rejeição imediata por tentativa de reuso de comando com dados divergentes | `aborted` |
| Tentativa de edição/exclusão de versão | Chamada client-side direta no Firestore ou API | Regras de segurança e ausência de endpoints rejeitam a operação | `permission-denied` |
| Chamada sem autoridade | Usuário sem credencial ou sem claim administrativa ativa | Operação recusada antes de qualquer mutação | `permission-denied` genérico |
| Título ou conteúdo em branco | Título < 3 caracteres ou conteúdo < 20 caracteres | Validação de domínio rejeita a entrada | `invalid-argument` |
| Conflito de versão concorrente | `versaoEsperada` divergente da versão vigente atual no banco | Operação abortada para evitar saltos ou concorrência descontrolada | `aborted` |
| Consulta administrativa | Admin autenticado consulta lista de versões do termo | Retorna histórico ordenado decrescente por versão, com hashes, datas UTC e texto completo | Sucesso |
| Consulta pública do termo vigente | Voluntário ou visitante autenticado consulta termo para leitura | Retorna dados da versão atualmente vigente (título, conteúdo, versão, hash, data) | Sucesso |

</frozen-after-approval>

## Code Map

- `functions/src/domain/termos.ts` -- Definição de tipos, cálculo de hash SHA-256 canônico, validação de payload, regras de versão e erros de domínio.
- `functions/src/repositories/termos.ts` -- Operações transacionais Firestore: idempotência (`commands`), criação imutável de versões (`termos/{id}/versoes/{id}`), atualização do ponteiro vigente, contagem de impactados e outbox de auditoria (`auditOutbox`).
- `functions/src/commands/publicarTermo.ts` -- Cloud Function callable v2 para publicação segura e idempotente do termo com App Check e checagem de autoridade.
- `functions/src/commands/consultarTermos.ts` -- Cloud Function callable v2 para listagem do histórico completo de versões para administradores.
- `functions/src/commands/obterTermoVigente.ts` -- Cloud Function callable v2 para obtenção segura dos dados do termo vigente para leitura institucional.
- `functions/src/index.ts` -- Exportação das novas callables no entrypoint do Cloud Functions.
- `firestore.rules` -- Regras de segurança explícitas garantindo escrita negada (`allow write: if false;`) para coleções de termos e subcoleções de versões.
- `functions/test/termos.test.ts` -- Testes unitários de domínio: hash SHA-256, validação de entradas, controle de versão incremental.
- `functions/test/termos.emulator.test.ts` -- Testes de integração no emulador: publicação inicial, nova versão, preservação histórica, idempotência e auditoria.
- `functions/test/security-contract.test.ts` -- Validação estática dos contratos de segurança (App Check, exportações, regras Firestore, ausência de PII e ausência de console.log).
- `flutter_app/lib/features/admin/termos_service.dart` -- Contrato `TermosGateway`, modelos de dados e implementação `FirebaseTermosService`.
- `flutter_app/lib/features/admin/termos_screen.dart` -- Interface administrativa mobile-first com abas/seções de termo vigente, nova versão (com modal de confirmação de imutabilidade) e histórico de versões.
- `flutter_app/lib/features/admin/admin_shell.dart` -- Inclusão da aba "Termos" no menu lateral e gaveta com injeção do gateway.
- `flutter_app/test/fakes.dart` -- Implementação de `TermosFake` para testes unitários e de widget.
- `flutter_app/test/termos_test.dart` -- Testes de widget e de fluxo da tela de gestão de termos (renderização, publicação, confirmação, erros e histórico).
- `flutter_app/test/admin_shell_test.dart` -- Atualização do teste do shell para cobrir a navegação para a aba "Termos".

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/termos.ts` -- Criar módulo de domínio de termos -- Validação de regras de negócio, cálculo canônico de SHA-256 e erros específicos.
- [x] `functions/src/repositories/termos.ts` -- Implementar repositório transacional de termos -- Garantir atômica criação de versão imutável, recibo, auditoria e ponteiro de termo vigente.
- [x] `functions/src/commands/publicarTermo.ts` -- Criar callable de publicação de termo -- Endpoint seguro com App Check e RBAC para mutação de termos.
- [x] `functions/src/commands/consultarTermos.ts` -- Criar callable de consulta do histórico de versões -- Leitura administrativa autorizada do acervo de versões.
- [x] `functions/src/commands/obterTermoVigente.ts` -- Criar callable para obter o termo vigente -- Leitura autorizada da versão ativa atual.
- [x] `functions/src/index.ts` -- Exportar callables de termos no entrypoint -- Disponibilizar funções para invocação pelo cliente e emuladores.
- [x] `firestore.rules` -- Atualizar regras para termos e subcoleções de versões -- Negar explicitamente qualquer escrita direta do cliente (`allow write: if false;`).
- [x] `functions/test/termos.test.ts` -- Testes unitários do domínio de termos -- Verificar cálculo de SHA-256, incremento de versão e validação.
- [x] `functions/test/termos.emulator.test.ts` -- Testes com Firestore Emulator -- Testar ciclo de publicação, idempotência, nova versão e auditoria.
- [x] `functions/test/security-contract.test.ts` -- Atualizar contratos de segurança executáveis -- Validar App Check, ausência de PII e exportações das callables de termos.
- [x] `flutter_app/lib/features/admin/termos_service.dart` -- Implementar serviço e gateway de termos -- Comunicação tipada com o backend Firebase.
- [x] `flutter_app/lib/features/admin/termos_screen.dart` -- Implementar tela de gestão e publicação de termos -- Interface responsiva com `PageHeader`, `SectionCard`, `PrimaryButton`, diálogo de confirmação de imutabilidade e visualizador de histórico.
- [x] `flutter_app/lib/features/admin/admin_shell.dart` -- Adicionar aba "Termos" no AdminShell -- Navegação integrada via sidebar e drawer responsivo.
- [x] `flutter_app/test/fakes.dart` -- Adicionar `TermosFake` aos utilitários de teste -- Simular operações de publicação e consulta de termos.
- [x] `flutter_app/test/termos_test.dart` -- Criar testes unitários e de widget da tela de termos -- Garantir cobertura completa de visualização, formulário, diálogo de confirmação e estados de erro.
- [x] `flutter_app/test/admin_shell_test.dart` -- Atualizar testes do AdminShell -- Validar seleção e renderização da aba "Termos".

**Acceptance Criteria:**
- Given administrador autenticado com autoridade vigente e termo inicial, when publica primeira versão com título e conteúdo válidos, then sistema persiste documento imutável com número de versão 1, hash SHA-256 correspondente, timestamp UTC do servidor, define-o como vigente e gera recibo e auditoria na mesma transação.
- Given termo já publicado com versão 1 vigente, when administrador submete publicação de nova versão com novo conteúdo, then sistema gera versão 2 imutável preservando a versão 1 integralmente, atualiza o ponteiro de vigência para a versão 2 e registra na auditoria a quantidade de voluntários ativos impactados sem alterar aceites históricos.
- Given qualquer usuário ou cliente, when tenta atualizar (`update`) ou excluir (`delete`) versão já publicada, then a operação é recusada com erro de permissão pelas regras de segurança e nenhuma alteração ocorre.
- Given requisição de publicação com `commandId` já processado e mesmo `payloadHash`, when enviada novamente, then sistema responde com o recibo original persistido sem gerar versões duplicadas.
- Given interface administrativa de termos no Flutter, when renderizada em celular ou desktop, then apresenta termo vigente destacado com hash SHA-256, botão para nova versão com modal de confirmação explicativo sobre imutabilidade e histórico de versões anteriores consultável.

## Implementation Notes

- Implementado o ciclo completo da Story 1.5 seguindo estritamente TDD.
- Backend:
  - `functions/src/domain/termos.ts`: módulo puro contendo validação de parâmetros, cálculo de hash SHA-256 canônico (`calcularHashConteudo`), hash de comando idempotente (`calcularPayloadHash`) e classes de erro de domínio.
  - `functions/src/repositories/termos.ts`: operações transacionais atômicas no Firestore; garantida idempotência de comando com gravação em `commands/{commandId}`, evento em `auditOutbox/{commandId}` sem PII, versão imutável em `termos/{termoId}/versoes/{versaoId}` e ponteiro de termo vigente atualizado.
  - Callables v2 com App Check e checagem de autoridade administrativa: `publicarTermo`, `consultarTermos` e `obterTermoVigente`.
  - `firestore.rules`: negação explícita de escrita para termos e versões publicadas (`allow write: if false;`).
  - Suíte de testes `termos.test.ts`, `termos.emulator.test.ts` e `security-contract.test.ts` passando com 100% de sucesso.
- Frontend:
  - `flutter_app/lib/features/admin/termos_service.dart`: modelos `VersaoTermo`, `TermoVigente`, `ResultadoPublicarTermo`, interface `TermosGateway` e implementação `FirebaseTermosService`.
  - `flutter_app/lib/features/admin/termos_screen.dart`: UI responsiva construída sobre o design system (`PageHeader`, `SectionCard`, `EmptyState`, `PrimaryButton`, `SecondaryButton`, `StatusChip`), com modal de confirmação de imutabilidade e visualizador de versões.
  - `flutter_app/lib/features/admin/admin_shell.dart` e `flutter_app/lib/main.dart`: aba "Termos" adicionada com ícone de documento e injeção de gateway.
  - `flutter_app/test/fakes.dart`, `flutter_app/test/termos_test.dart`, `flutter_app/test/admin_shell_test.dart`: testes unitários e de widget cobrindo 100% dos fluxos. Suíte completa do Flutter (115 testes) passando com sucesso.

## Spec Change Log

## Review Triage Log

- `low` (resolvido) | `flutter_app/test/fakes.dart:363` | tipagem explícita de `listaVersoes` como `<VersaoTermo>[]` corrigida para compatibilidade estrita do Dart.
- `low` (resolvido) | `flutter_app/lib/features/admin/termos_screen.dart` | alinhamento dos nomes de componentes com o design system existente (`SectionCard`, `EmptyState`, `PrimaryButton`, `SecondaryButton`, tokens de `tokens.dart`).
- `low` (resolvido) | `firestore.rules` | alinhamento das instruções de permissão de subcoleção de versões ao padrão estrito do teste de segurança estrutural (`allow read, write: if false;`).
- `low` (resolvido) | `flutter_app/test/termos_test.dart` | escopo do teste do modal bottom sheet refinado para buscar dentro do widget `BottomSheet`.

## Design Notes

- **Imutabilidade e Hash Canônico:** O hash SHA-256 é calculado sobre o conteúdo UTF-8 normalizado (`titulo.trim() + "\n\n" + conteudo.trim()`). Uma vez gravado o documento na subcoleção `termos/{termoId}/versoes/{versaoId}`, o campo `imutavel: true` e a ausência total de comandos de mutação garantem a integridade documental.
- **Preparação para Epics 2 e 5:** Ao publicar uma nova versão, o backend realiza uma contagem de fichas com estado `ATIVA` e grava no registro de auditoria `totalVoluntariosImpactados`. Os documentos de aceites históricos (`aceitesTermo`) permanecem inalterados, preservando a validade dos termos aceitos anteriormente.
- **Experiência do Administrador (Sally):** Ao clicar em "Publicar Nova Versão", um diálogo modal de revisão exibe o título, prévia do texto e aviso em destaque: *"Atenção: A publicação de uma versão de termo é definitiva e imutável. Não será possível editar ou excluir este texto após a publicação. Deseja confirmar a publicação da versão N?"*. Isso evita publicações acidentais.

## Verification

**Commands:**
- `cd functions && npm test` -- expected: Todos os testes unitários e de contrato passam com 100% de sucesso.
- `cd flutter_app && flutter test` -- expected: Todos os testes unitários e de widget do Flutter passam com sucesso.

**Manual checks (if no CLI):**
- Inspecionar na tela de Termos a exibição do card de termo vigente com selo de status, hash SHA-256 e o histórico de versões ordenado cronologicamente decrescente.
- Validar no formulário de publicação o bloqueio de envio com campos vazios e a exibição do diálogo de confirmação de imutabilidade.

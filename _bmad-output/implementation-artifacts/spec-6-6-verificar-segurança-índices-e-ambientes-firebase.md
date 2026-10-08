---
title: 'Story 6.6: Verificar segurança, índices e ambientes Firebase'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_commit: '246dbe2242711a0c7490d49550293221967bc59e'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Para a conclusão segura do Épico 6 e prontidão para produção, o sistema necessita de validação rigorosa de ponta a ponta dos seus pilares de segurança e infraestrutura no Firebase. Faltam: uma suíte automatizada sob emuladores que prove a negação estrita de escrita direta pelo cliente no Firestore e Storage sob múltiplos papéis e cenários adversos (tentativas diretas de mutação, violação de escopo, vínculos expirados e documentos privados); comprovação automatizada de idempotência (`commandId`), atomicidade transacional e correlação de auditoria/evidência sob retry e concorrência; consolidação e auditoria dos índices compostos em `firestore.indexes.json` para todas as consultas de filas, relatórios e dashboards operacionais; e validação formal de isolamento de ambientes (dev, staging, prod), menor privilégio de service accounts e inexistência de segredos no cliente.

**Approach:** Implementar uma suíte abrangente de testes de segurança com Firebase Emulator Suite e testes automatizados de infraestrutura: (1) `seguranca-regras.emulator.test.ts` para testar contra o Firestore e Storage Emulator a negação irrestrita de qualquer mutação de domínio pelo cliente, integridade das regras em coleções-grupo e isolamento de escopo; (2) `idempotencia-concorrencia.test.ts` para testar concorrência real com promessas simultâneas de comandos críticos sob o mesmo `commandId`, validação de payload hash e atomicidade transacional; (3) consolidar os índices compostos em `firestore.indexes.json` e validar contratualmente em `indices-ambientes.test.ts` que nenhuma query de filas, relatórios ou dashboards remove filtros para contornar índices; e (4) definir a configuração formal de múltiplos ambientes em `infra/ambientes-firebase.json` e `.firebaserc`, auditando ausência de segredos no cliente e políticas de menor privilégio de service accounts.

## Boundaries & Constraints

**Always:**
- Backend como única autoridade de mutação (AD-1): Firestore e Cloud Storage negam qualquer criação, atualização ou exclusão direta por clientes em coleções de domínio (`igrejas`, `equipes`, `fichas`, `participacoes`, `termos`, `commands`, `auditoria`, `auditOutbox`, `alertasOperacionais`, etc.).
- Armazenamento de PDFs em bucket privado (`storage.rules`): leitura e escrita direta estritamente negadas pelo cliente (`allow read, write: if false;`), acessíveis exclusivamente via Cloud Functions autorizadas que geram URLs assinadas revogáveis com TTL curto (AD-12).
- Idempotência rigorosa e atomicidade transacional (AD-8, AD-10): todo comando exige `commandId`, valida hash do payload, impede comandos divergentes com mesmo identificador, registra recibo transacional e vincula evidência e `auditOutbox` atomicamente.
- Menor privilégio e segredos (AD-12): o cliente Web/PWA Flutter não armazena credenciais de serviço ou segredos administrativos; ambientes de desenvolvimento, homologação e produção possuem isolamento de projeto Firebase e contas de serviço dedicadas.
- Preservação das decisões e convenções arquiteturais (AD-1 a AD-13): timestamps em UTC, identificadores opacos, estados em `UPPER_SNAKE_CASE` e ausência de PII em logs, recibos ou erros.

**Never:**
- Não permitir que qualquer regra de segurança Firestore ou Storage conceda permissão de escrita direta de domínio baseada em token ou `request.auth` do cliente.
- Não expor consultas sem índice que contornem filtros obrigatórios de escopo ou de tenant.
- Não incluir chaves privadas de conta de serviço, senhas ou segredos no bundle do cliente Flutter.
- Não admitir transições parciais ou descorrelacionadas em comandos com retry ou chamadas concorrentes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tentativa de escrita direta pelo cliente no Firestore | Cliente autenticado ou anônimo tenta criar/editar documento em `fichas`, `participacoes`, `commands` ou `auditoria` | Operação bloqueada pelas regras com erro `PERMISSION_DENIED` | Regra avalia `allow write: if false` e rejeita imediatamente |
| Tentativa de escrita/leitura direta no Storage | Cliente tenta baixar ou enviar arquivo em `pdfs/{fichaId}/{docId}.pdf` | Operação bloqueada com erro `PERMISSION_DENIED` | `storage.rules` nega acesso direto a qualquer caminho de bucket |
| Comandos concorrentes com mesmo `commandId` | Duas requisições paralelas idênticas disparadas simultaneamente para comando transacional | Exatamente uma execução processa a mutação; a segunda reconhece o recibo idempotente sem duplicar eventos ou estado | Retorna resultado idempotente idêntico sem efeitos colaterais duplicados |
| Retry com payload divergente | Requisição subsequente reutilizando `commandId` existente com parâmetros alterados | Comando rejeitado imediatamente com erro de comando divergente | Erro `COMANDO_DIVERGENTE` ou `ALREADY_EXISTS` com código seguro |
| Consulta operacional filtrada | Busca em filas/relatórios combinando estado e ordenação ou múltiplos filtros de escopo | Execução eficiente respaldada por índices compostos em `firestore.indexes.json` | Sem erro de missing index ou remoção indevida de filtros |
| Inspeção de segredos no cliente | Análise estática do código-fonte do cliente Flutter e variáveis públicas | Nenhuma credencial de service account, chave privada ou segredo embutido | Teste de verificação falha se detectar padrões de chave privada |

</frozen-after-approval>

## Code Map

- `firestore.rules` -- Regras de segurança do Firestore com negação estrita de escrita direta e leitura restrita.
- `storage.rules` -- Regras de segurança do Cloud Storage com negação total de acesso direto.
- `firestore.indexes.json` -- Definição e consolidação de índices compostos para consultas de filas, histórico, auditoria e relatórios.
- `.firebaserc` -- Mapeamento de múltiplos projetos/ambientes (dev, staging, prod).
- `infra/ambientes-firebase.json` -- Matriz normativa de configuração de ambientes, políticas IAM de menor privilégio e verificação de segredos.
- `functions/test/seguranca-regras.emulator.test.ts` -- Testes automatizados de validação de regras Firestore e Storage no Emulator.
- `functions/test/idempotencia-concorrencia.test.ts` -- Testes de concorrência e idempotência transacional sob retry e race conditions.
- `functions/test/indices-ambientes.test.ts` -- Testes de auditoria de índices compostos, isolamento de ambientes e integridade de segredos.
- `functions/package.json` -- Configuração dos scripts de teste da suíte de segurança e emuladores.

## Tasks & Acceptance

**Execution:**
- [x] `firestore.indexes.json` -- Consolidar índices compostos para todas as coleções com filtros compostos (`participacoes`, `fichas`, `filaPendencias`, `filaPendenciasEquipe`, `auditoria`, `alertasOperacionais`, `vinculosPastorIgreja`, `vinculosPastorEquipe`).
- [x] `infra/ambientes-firebase.json` -- Criar especificação técnica declarativa dos ambientes isolados (dev, homologação/staging, produção), papéis IAM de menor privilégio para Cloud Functions e regras de bloqueio de promoção.
- [x] `.firebaserc` -- Configurar aliases formais dos ambientes de desenvolvimento, homologação e produção (`eqp-maanaim-dev`, `eqp-maanaim-staging`, `eqp-maanaim-prod`).
- [x] `functions/test/seguranca-regras.emulator.test.ts` -- Implementar suíte de testes de regras Firestore/Storage no Emulator cobrindo escrita direta negada, leitura de catálogo público vs dados protegidos, e bucket privado de PDFs.
- [x] `functions/test/idempotencia-concorrencia.test.ts` -- Implementar testes de idempotência e concorrência para comandos transacionais (concorrência de `commandId`, retry com mesmo payload, rejeição de payload divergente e integridade de `auditOutbox`).
- [x] `functions/test/indices-ambientes.test.ts` -- Implementar testes de validação contratual de índices compostos, isolamento de ambientes, menor privilégio de IAM e ausência de segredos no cliente Flutter.
- [x] `functions/package.json` -- Atualizar scripts de teste para incluir as novas suítes de verificação.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da história 6.6 para `in-progress` e posteriormente `done`.

**Acceptance Criteria:**
- Given regras de segurança Firestore e Storage implantadas, when avaliadas contra tentativas diretas de escrita e leitura de clientes, then todas as operações diretas de domínio são rejeitadas com permissão negada.
- Given comandos críticos transacionais, when submetidos a requisições concorrentes ou retries com mesmo `commandId`, then comprovam idempotência estrita sem duplicação de entidades ou eventos de auditoria.
- Given consultas com múltiplos filtros em filas e relatórios, when confrontadas com `firestore.indexes.json`, then todos os índices compostos necessários estão declarados e nenhum filtro de escopo é suprimido.
- Given as configurações dos ambientes dev, staging e prod, when auditadas, then comprovam projetos isolados, papéis IAM restritos e ausência de segredos no código cliente.

## Implementation Notes

- Índices compostos consolidados em `firestore.indexes.json` cobrindo participações, fichas, filas de aprovação por igreja/equipe, vínculos de responsabilidade, auditoria imutável e alertas operacionais.
- Ambientes dev, staging e prod isolados em `infra/ambientes-firebase.json` e declarados no `.firebaserc`, com menor privilégio para contas de serviço e política restrita de promoção via testes de emulador.
- Criada a suíte `functions/test/seguranca-regras.emulator.test.ts` que comprova a negação estrita de escrita direta pelo cliente no Firestore e Storage sob o Firebase Emulator Suite.
- Criada a suíte `functions/test/idempotencia-concorrencia.test.ts` que atesta idempotência, bloqueio de comandos divergentes e atomicidade transacional sob concorrência intensa de `commandId`.
- Criada a suíte `functions/test/indices-ambientes.test.ts` validando a integridade dos índices compostos, ausência de credenciais privadas ou segredos no cliente Flutter e papéis IAM de menor privilégio.
- 100% de aprovação obtida nas suítes do Emulator Suite (`6 passed`, `55 passed`), na suíte de testes de funções (`39 test files passed`, `473 tests passed`) e na suíte Flutter (`278 tests passed`).

## Spec Change Log

## Review Triage Log

| Finding / Pergunta de Revisão | Veredito | Evidência / Refutação |
|---|---|---|
| Blind-Hunter: Cobertura de queryScope COLLECTION vs COLLECTION_GROUP em índices | `false` | As coleções afetadas (`participacoes`, `fichas`, `filaPendencias`, etc.) operam sob escopo padrão e são validadas em `indices-ambientes.test.ts`. |
| Blind-Hunter: Dependência de emuladores para CI básico | `false` | Os testes possuem fallbacks contratuais e em memória para `npm test` regular e suíte dedicada de emuladores para `emulators:exec`. |
| Blind-Hunter: Governança declarativa de ambientes em JSON | `false` | A matriz `infra/ambientes-firebase.json` alinha-se ao `scripts/aplicar-controles-operacionais.mjs` e satisfaz os requisitos do AD-12. |
| Edge-Case: Orçamento de 500 operações em concorrência de lote | `false` | O limite de escritas atômicas é respeitado individualmente por `commandId` único em cada transação conforme AD-8. |
| Edge-Case: Chamadas simultâneas gerando múltiplos registros de auditoria | `false` | Teste em `idempotencia-concorrencia.test.ts` comprova que exatamente 1 registro é criado em `auditoria/:commandId` sob 5 execuções simultâneas. |
| Verification-Gap: Detecção de segredos em arquivos auxiliares | `false` | Varredura recursiva cobre toda a árvore `flutter_app/lib` e valida ausência de padrões de chave privada, service accounts ou tokens hardcoded. |
| Verification-Gap: Negação de escrita e leitura direta pelo cliente | `false` | Testado no Emulator com chamadas REST HTTP retornando 403 PERMISSION_DENIED em `seguranca-regras.emulator.test.ts`. |

## Verification

**Commands:**
- `npm --prefix functions test` -- expected: Todas as suítes de testes unitários e contratuais passam com sucesso.
- `npm --prefix functions run typecheck` -- expected: TypeScript compila sem erros ou advertências.
- `git status` -- expected: Exibe alterações controladas e prontas para commit.

---
title: 'Importação inicial de pastores e vínculos'
type: 'feature'
created: '2026-09-29'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/specs/spec-gestao-voluntarios-maanaim/SPEC.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A operação inicial precisa cadastrar os pastores locais e associá-los às igrejas corretas, a partir da planilha fornecida, sem expor dados pessoais nem tornar essas relações listas fixas no aplicativo.

**Approach:** Criar uma carga administrativa idempotente, executada no backend, que valide a planilha local, crie ou reutilize identidades pastorais e estabeleça um único vínculo vigente por igreja com rastreabilidade.

**Decisões:** A planilha define vínculos exclusivamente pelos códigos de igreja; os nomes canônicos não serão substituídos. Os vínculos ausentes são `240005` para Vicente de Paulo Braga e `240029` para Mauro Azevedo Inacio, sem o sufixo `| RN`. A carga criará contas no Firebase Authentication sem disparar convite; o pastor iniciará a recuperação de senha pela tela de login a ser entregue posteriormente. A vigência inicia na execução da carga, interpretada no fuso UTC−3 e persistida em UTC. A auditoria identificará a origem como `seed-inicial-do-sistema`.

## Boundaries & Constraints

**Always:** Usar os códigos de igreja como `String`, IDs opacos, tempo UTC do servidor, transações e `commandId`; manter pessoa, identidade e vínculo separados; impedir escrita direta do domínio pelo cliente; manter nomes/e-mails fora de logs, erros, auditoria e versionamento; preservar vínculos e decisões anteriores de forma append-only.

**Never:** Transformar a carga em upload público, atribuir papéis pelo cliente, usar e-mails como IDs, sobrescrever dados administrativos posteriores ou incluir a planilha com PII no repositório.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Carga inicial válida | Planilha local com igreja, pastor e e-mail; igreja sem vínculo | Cria/reutiliza o pastor e cria vínculo local vigente auditável | Resultado por linha sem PII, com correlação e contagens |
| Reexecução | Mesma planilha após carga concluída | Não duplica pessoas, contas, igrejas ou vínculos; preserva edições posteriores | Retorna recibo idempotente |
| Igreja desconhecida/inativa | Código ausente da base canônica ou igreja inativa | Não cria vínculo parcial | Falha atômica da linha, relatório seguro e acionável |
| Conflito de vínculo vigente | Igreja já possui outro Pastor Local vigente | Não encerra nem substitui silenciosamente | Recusa a linha e exige fluxo explícito de substituição |
| Dados inválidos | Cabeçalho, código, nome ou e-mail inválido/duplicado de modo ambíguo | Nenhuma gravação daquela entrada | Validação antes da mutação, sem vazar PII |

</frozen-after-approval>

## Code Map

- `AGENTS.md` -- invariantes obrigatórias: mutações críticas em Cloud Functions, privacidade, papéis e vínculos temporais.
- `_bmad-output/planning-artifacts/epics.md` -- Stories 1.2, 1.3 e 1.4 descrevem seed administrável, pessoas/papéis e um Pastor Local vigente por igreja.
- `_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md` -- AD-1, AD-2, AD-3, AD-8, AD-9, AD-10 e AD-12 governam a implementação.
- `_bmad-output/planning-artifacts/PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md` -- define a base canônica inicial de igrejas e a relação um-pastor-para-múltiplas-igrejas.
- `/Users/usuario/Downloads/igreja-pastor-email - Página1.csv` -- fonte local de PII para carga; não versionar, não copiar ao projeto nem registrar valores em telemetria.
- Repositório -- ainda não há bootstrap Flutter/Firebase, Functions, Rules ou testes; a entrega deve estabelecer o substrato mínimo necessário antes da carga.

## Tasks & Acceptance

**Execution:**
- [ ] `functions/` e configuração Firebase versionada -- estabelecer comandos administrativos autenticados, schema mínimo, Rules deny-by-default e suporte a Emulator para a carga segura.
- [ ] `functions/commands/importarPastoresIniciais.*` -- validar fonte local, deduplicar pessoa por identidade definida, criar vínculos transacionais e gerar recibo/auditoria sem PII.
- [ ] `scripts/importar-pastores-iniciais.*` -- disponibilizar uma execução administrativa local, com validação prévia, modo de simulação e saída agregada segura.
- [ ] `functions/**/*.test.*` e testes Emulator -- cobrir idempotência, vínculo único, conflito, dados inválidos e ausência de escrita parcial.
- [ ] `.gitignore` e documentação operacional -- impedir commit da planilha e documentar pré-requisitos, execução e recuperação segura.

**Acceptance Criteria:**
- Given uma base com as igrejas canônicas e uma planilha validada, when administrador autorizado executa a carga, then cada linha cria ou reutiliza um pastor e seu vínculo vigente sem expor PII.
- Given um pastor associado a várias igrejas, when a carga termina, then uma única pessoa/identidade representa o pastor e cada igreja tem seu vínculo próprio.
- Given a mesma carga executada novamente, when os dados já foram persistidos, then o resultado é idempotente e não substitui nomes, estados ou vínculos modificados posteriormente.
- Given qualquer entrada inválida ou vínculo atual conflitante, when a carga é processada, then o sistema recusa a entrada sem estado parcial e retorna diagnóstico seguro.
- Given um cliente comum, when tenta gravar pessoas, papéis ou vínculos diretamente, then Rules e backend negam a mutação.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

A carga é uma operação inicial controlada, não uma funcionalidade de importação genérica. A fonte mantém-se local; a implementação registra somente IDs, ação, timestamp, `commandId` e `correlationId`.

## Verification

**Commands:**
- `firebase emulators:exec <suite-de-testes>` -- esperado: testes de Rules, transações e idempotência aprovados.
- `<comando-de-importação> --dry-run <arquivo-local>` -- esperado: validação completa e contagens agregadas, sem gravar nem exibir PII.

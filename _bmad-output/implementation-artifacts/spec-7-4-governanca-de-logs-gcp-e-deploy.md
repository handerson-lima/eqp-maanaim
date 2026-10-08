---
title: 'Story 7.4: Governança de Logs GCP & Deploy (action item epic-6-retro-item-1-gcp-data-access-logs)'
type: 'feature'
created: '2026-10-08'
status: 'ready-for-dev'
baseline_commit: 'd5146701f9d01fc5943667b22a8926e9c65655c1'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/implementation-artifacts/epic-6-retro-2026-10-07.md'
  - '_bmad-output/implementation-artifacts/deferred-work.md'
  - 'infra/alertas-monitoramento.json'
  - 'infra/ambientes-firebase.json'
  - 'infra/storage-lifecycle.json'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 
No Google Cloud Platform, os registros de auditoria de atividade administrativa (*Admin Activity*) são ativados por padrão, mas os registros de acesso a dados (*Data Access Audit Logs* — compreendendo `DATA_READ`, `DATA_WRITE` e `ADMIN_READ`) para o serviço `storage.googleapis.com` permanecem **desabilitados por padrão** devido a custos e volume.
No sistema Maanaim, os termos de adesão assinados contendo dados pessoais de voluntários (PII) são persistidos privadamente em `gs://<bucket>/pdfs/:fichaId/:documentoId.pdf` (AD-12 e AD-13). Sem os logs de Data Access explicitamente habilitados:
1. O acesso de leitura a termos privados e geração de download não geram trilha forense imutável de acesso no nível de infraestrutura GCP (lacuna LGPD Art. 37 e 46).
2. O alerta operacional de deleções (`DELETION`) configurado em `infra/alertas-monitoramento.json` para o método `storage.objects.delete` torna-se ineficaz e silencioso, pois o evento de exclusão não é emitido pelo Cloud Storage sem `DATA_WRITE` ativo (item deferido em `deferred-work.md:113`).
3. Não há automação padronizada, idempotente e reproduzível para aplicar a configuração de auditoria nos projetos dos três ambientes (`dev`, `staging`, `prod`), nem um checklist formal de homologação e prontidão operacional para deploy em produção.

**Approach:** 
1. **Winston (Architect):** Desenhar a arquitetura canônica de governança e auditoria no GCP Cloud Audit Logs, especificando a política de IAM `auditConfigs` para `storage.googleapis.com` (`DATA_READ`, `DATA_WRITE`, `ADMIN_READ`), a política de retenção dos logs no Cloud Logging por 5 anos (1825 dias alinhado a AD-12) e o checklist formal com portões de qualidade para homologação e deploy em produção.
2. **Amelia (Senior Software Engineer):** Implementar scripts idempotentes de automação via Google Cloud SDK (`scripts/setup-gcp-data-access-logs.sh` e `scripts/verificar-governanca-gcp.sh`), com suporte a `--dry-run`, `--project` e tratamento seguro de mesclagem JSON/IAM sem corromper bindings existentes. Criar testes automatizados de infraestrutura em Vitest (`functions/test/governancaLogsGcp.test.ts`), documentar o checklist operacional e atualizar o rastreamento de sprint em `_bmad-output/implementation-artifacts/sprint-status.yaml`.

## Boundaries & Constraints

**Always:**
- **Idempotência estrita:** Os scripts de provisionamento de auditoria devem poder ser executados repetidas vezes no mesmo projeto sem duplicar blocos de `auditLogConfigs` e sem remover bindings de IAM pré-existentes.
- **Modo Simulação Seguro (`--dry-run`):** O script `setup-gcp-data-access-logs.sh` deve oferecer modo dry-run por padrão ou via flag explícita, exibindo exatamente as alterações na política de IAM antes da aplicação real.
- **Proteção contra vazamento de PII:** Os Cloud Audit Logs devem auditar apenas metadados canônicos (identidade autenticada/Service Account, método da chamada, timestamp UTC, recurso afetado `gs://bucket/pdfs/...`), garantindo que nenhum dado sensível ou conteúdo de PDF seja exposto em filtros ou logs públicos.
- **Trilha de 5 anos (AD-12):** A governança de retenção de logs deve prescrever e documentar a configuração do Cloud Logging Bucket (`_Default` ou sink dedicado) com retenção de 1825 dias, espelhando a retenção de dados da ficha e do Storage.
- **Isolamento de Ambientes:** As configurações devem respeitar os projetos declarados em `infra/ambientes-firebase.json` (`eqp-maanaim-dev`, `eqp-maanaim-staging`, `eqp-maanaim-prod`).
- **Verificação Automatizada:** Incluir suíte de testes unitários em TypeScript/Vitest validando schemas, integridade de filtros, geração correta de comandos e idempotência da manipulação da política IAM.

**Never:**
- **Nunca sobrescrever bindings de IAM ou configurações de auditoria de outros serviços:** A mesclagem deve ser cirúrgica, focada no serviço `storage.googleapis.com`, preservando papéis existentes e auditorias de outros serviços (`allServices`, `bigquery.googleapis.com`, etc.).
- **Nunca aplicar Bucket Lock permanente (`retentionPolicy.isLocked: true`) no Cloud Storage:** A retenção é mantida operacionalmente via `storage-lifecycle.json` (AD-12).
- **Nunca permitir acesso anônimo ou leitura pública:** Nenhuma alteração de IAM deve conceder `allUsers` ou `allAuthenticatedUsers`.
- **Nunca desabilitar Admin Activity logs:** Eles são mantidos mandatórios e incondicionais pelo GCP.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Execução com `--dry-run` | `setup-gcp-data-access-logs.sh --project eqp-maanaim-prod --dry-run` | Imprime a política IAM resultante contendo o bloco `auditConfigs` para `storage.googleapis.com` sem efetivar no GCP | Finaliza com código 0 |
| Projeto já possui `auditConfigs` para outros serviços | Política IAM contém `auditConfigs` para `allServices` | Adiciona ou mescla `storage.googleapis.com` sem remover `allServices` | Preserva integrações existentes |
| Projeto já possui `storage.googleapis.com` configurado | Política IAM já contém `DATA_READ`, `DATA_WRITE`, `ADMIN_READ` | Detecta conformidade e não gera alterações desnecessárias (idempotente) | Reporta "Configuração já conforme" |
| Execução sem especificar `--project` nem `.firebaserc` | Nenhuma flag informada e arquivo `.firebaserc` inexistente | Erro informativo orientando uso de `--project <ID>` | Interrompe com código 1 antes de qualquer chamada |
| Falha de autenticação no `gcloud` | Usuário não autenticado ou token expirado | Detecta falha no comando `gcloud` e exibe mensagem amigável | Falha com código retornado pelo `gcloud` |
| Verificação de governança | `verificar-governanca-gcp.sh --project eqp-maanaim-prod` | Avalia Data Access logs, alertas do Cloud Monitoring e bucket lifecycle, gerando relatório de conformidade | Retorna 0 (conforme) ou 2 (inconforme) |

</frozen-after-approval>

## Code Map

- `infra/gcp-audit-logs-storage.json` -- Definição declarativa canônica da configuração de auditoria para `storage.googleapis.com` (`DATA_READ`, `DATA_WRITE`, `ADMIN_READ`).
- `scripts/setup-gcp-data-access-logs.sh` -- Script shell de automação para extrair a IAM policy do projeto GCP, mesclar cirurgicamente a configuração de Data Access logs do Storage e reaplicar via `gcloud projects set-iam-policy`.
- `scripts/verificar-governanca-gcp.sh` -- Script de auditoria e validação que inspeciona o projeto ativo e valida se os logs de auditoria, políticas de monitoramento e retenção estão em conformidade.
- `docs/checklist-homologacao-deploy.md` -- Checklist formal normativo de homologação e prontidão para deploy em produção (portões de qualidade, passos operacionais e critérios de aceite).
- `infra/README.md` -- Atualização do guia operacional de infraestrutura incluindo a governança de logs e o relacionamento com os alertas de `storage.objects.delete`.
- `functions/test/governancaLogsGcp.test.ts` -- Suíte de testes automatizados Vitest verificando schemas, regras de idempotência e scripts de governança.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualização do status do action item `epic-6-retro-item-1-gcp-data-access-logs` para rastreabilidade contínua.

## Tasks & Acceptance

**Planejamento & Arquitetura (Winston):**
- [ ] Definir a especificação técnica formal do GCP Cloud Audit Logs para `storage.googleapis.com` e sua retenção de 5 anos no Cloud Logging.
- [ ] Validar a compatibilidade entre a ativação de `DATA_WRITE` no Storage e o filtro de alerta `storage.objects.delete` em `infra/alertas-monitoramento.json`.
- [ ] Redigir o checklist formal de homologação e portões de promoção de ambiente (`dev` -> `staging` -> `prod`).

**Implementação & Engenharia (Amelia):**
- [ ] Criar `infra/gcp-audit-logs-storage.json` com o bloco canônico de `auditConfigs`.
- [ ] Implementar `scripts/setup-gcp-data-access-logs.sh` com suporte a `--dry-run`, `--project`, flags de ajuda e mesclagem idempotente.
- [ ] Implementar `scripts/verificar-governanca-gcp.sh` para auditoria do ambiente GCP.
- [ ] Criar `functions/test/governancaLogsGcp.test.ts` e validar execução com `npm test --prefix functions`.
- [ ] Criar `docs/checklist-homologacao-deploy.md` com o checklist detalhado de pré e pós deploy.
- [ ] Atualizar `infra/README.md` documentando o script e a governança de logs.
- [ ] Atualizar `_bmad-output/implementation-artifacts/sprint-status.yaml` refletindo o status da Story 7.4 e do action item `epic-6-retro-item-1-gcp-data-access-logs`.

---

## 🏛️ Desenho de Arquitetura de Governança (Winston)

### 1. Cloud Audit Logs no GCP e Serviços Abrangidos
No Google Cloud, os registros de auditoria são divididos em:
- **Admin Activity Logs:** Registram chamadas de criação, alteração ou exclusão de recursos de gerenciamento. Sempre ativados, sem cobrança e retidos por 400 dias.
- **Data Access Logs:** Registram chamadas de API que criam, modificam ou leem dados de usuários (como leitura e escrita de objetos no Cloud Storage). Vêm **desativados por padrão**.

Para atender às garantias do **ARCHITECTURE-SPINE.md** (AD-12: privilégio operacional, proteção de termos e PDFs privados, e retenção de 5 anos) e à LGPD:
- O serviço `storage.googleapis.com` deve ter seus Data Access logs habilitados no nível do projeto GCP com os seguintes tipos:
  1. `DATA_READ`: Registra acessos de leitura aos objetos (`storage.objects.get`), permitindo auditar quem (usuário, serviço ou Cloud Function) obteve ou gerou download de um PDF assinado.
  2. `DATA_WRITE`: Registra uploads (`storage.objects.create`) e exclusões (`storage.objects.delete`). **Essencial para que o alerta de deleção em `infra/alertas-monitoramento.json` funcione.**
  3. `ADMIN_READ`: Registra operações de metadados e listagem de buckets e ACLs (`storage.buckets.get`, etc.).

### 2. Formato Canônico da Política IAM (`auditConfigs`)
```json
{
  "service": "storage.googleapis.com",
  "auditLogConfigs": [
    {
      "logType": "DATA_READ"
    },
    {
      "logType": "DATA_WRITE"
    },
    {
      "logType": "ADMIN_READ"
    }
  ]
}
```

### 3. Retenção de Logs e Alinhamento LGPD (5 Anos / 1825 Dias)
- Por padrão, o bucket `_Default` do Cloud Logging retém logs por 30 dias.
- Para manter a rastreabilidade forense alinhada ao prazo de 5 anos da ficha do voluntário e dos termos em PDF (AD-12), prescreve-se:
  - Configuração da retenção do log bucket `_Default` para 1825 dias via comando:
    ```bash
    gcloud logging buckets update _Default --location=global --retention-days=1825 --project=<PROJECT_ID>
    ```
  - Em alternativa para projetos corporativos com SIEM centralizado: configuração de Log Sink imutável exportando para Cloud Storage Bucket de auditoria com retenção correspondente.

### 4. Resolução da Lacuna de Monitoramento (deferred-work.md:113)
A ativação de `DATA_WRITE` no Cloud Storage sana a dependência do filtro:
```text
protoPayload.methodName="google.firestore.v1.FirestoreAdmin.DeleteDocumentBatch" OR protoPayload.methodName="storage.objects.delete"
```
Com `DATA_WRITE` ativo, qualquer tentativa de deleção de objeto em `gs://<bucket>/pdfs/*` passa a gerar log `cloudaudit.googleapis.com/data_access` com `methodName="storage.objects.delete"`, disparando a notificação de severidade `WARNING` no Cloud Monitoring.

---

## 📋 Checklist Formal de Homologação e Deploy (Winston & Amelia)

### Portão 1: Validação de Qualidade de Código & Testes (CI)
- [ ] Suíte unitária do backend passando integralmente: `npm test --prefix functions` (473+ testes).
- [ ] Suíte de emuladores do backend passando: `npm run test:emulator --prefix functions`.
- [ ] Suíte de testes do frontend Flutter passando integralmente: `flutter test` (278+ testes).
- [ ] Análise estática limpa: `flutter analyze --fatal-infos --fatal-warnings`.
- [ ] Regras de segurança validadas: Firestore e Storage negam escrita direta e exclusão client-side.

### Portão 2: Governança de Infraestrutura & GCP
- [ ] Projetos isolados confirmados no `.firebaserc` (`development`, `staging`, `production`).
- [ ] `setup-gcp-data-access-logs.sh` executado e validado no projeto de homologação e produção.
- [ ] `verificar-governanca-gcp.sh` executado com status `OK` (conformidade total).
- [ ] Lifecycle de retenção de 5 anos aplicado no bucket (`infra/storage-lifecycle.json`).
- [ ] Políticas de alerta do Cloud Monitoring aplicadas (`infra/alertas-monitoramento.json`).
- [ ] Retenção de 1825 dias configurada no log bucket `_Default` do Cloud Logging.

### Portão 3: Homologação Pré-Deploy (Staging)
- [ ] Teste de ponta a ponta de submissão de ficha e aprovação completa (Pastor -> Responsável -> Coordenador).
- [ ] Geração de PDF do termo oficial persistido em `gs://eqp-maanaim-staging.appspot.com/pdfs/*`.
- [ ] Verificação de log de `DATA_READ` gerado no Cloud Audit Logs após download do PDF.
- [ ] Tentativa simulada de deleção de objeto no Storage gerando log `DATA_WRITE` e disparando alerta de teste.

### Portão 4: Execução de Deploy em Produção
- [ ] Deploy de Firestore Indexes: `firebase deploy --only firestore:indexes --project production`.
- [ ] Deploy de Security Rules: `firebase deploy --only firestore:rules,storage --project production`.
- [ ] Deploy de Cloud Functions: `firebase deploy --only functions --project production`.
- [ ] Build e deploy do Flutter Web/PWA: `flutter build web --release` e `firebase deploy --only hosting --project production`.
- [ ] Verificação de sanidade imediata pós-deploy (`smoke tests` nas rotas públicas e autenticadas).

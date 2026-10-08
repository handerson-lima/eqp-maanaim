# Controles operacionais de retenção e segurança (AD-12)

Este diretório versiona a configuração de **retenção de 5 anos** e os **alertas de
monitoramento** exigidos pela Story 6.4. Nada aqui é aplicado automaticamente pelo
deploy do Firebase: a aplicação é feita pelo script
[`scripts/aplicar-controles-operacionais.mjs`](../scripts/aplicar-controles-operacionais.mjs),
que por padrão apenas imprime os comandos `gcloud` e só altera o ambiente com
`--executar`.

## Arquivos

- `storage-lifecycle.json` — regra de lifecycle do bucket privado: objetos em
  `pdfs/` só são removidos após **1825 dias (5 anos)**. Não há *bucket lock*
  (`retentionPolicy` com `isLocked`) no repositório, conforme AD-12: a retenção é
  operacional e reversível por um administrador autorizado.
- `alertas-monitoramento.json` — políticas de alerta (Cloud Monitoring) que
  cobrem, por categoria:
  - `IAM` — alterações de política de IAM;
  - `RULES` — alterações de Firestore/Storage Rules;
  - `SERVICE_ACCOUNT` — criação/alteração/remoção de contas de serviço;
  - `DELETION` — deleções de documentos/objetos;
  - `BACKUP_FAILURE` — falhas de exportação/backup do Firestore.
- `gcp-audit-logs-storage.json` — configuração canônica declarativa de Data Access
  audit logs (`DATA_READ`, `DATA_WRITE`, `ADMIN_READ`) para `storage.googleapis.com` (Story 7.4).

## Uso

### 1. Controles operacionais e lifecycle

```bash
# Simulação (padrão): apenas imprime os comandos gcloud
node scripts/aplicar-controles-operacionais.mjs --projeto meu-projeto

# Aplicação real
node scripts/aplicar-controles-operacionais.mjs --projeto meu-projeto --executar
```

O bucket padrão é `<projeto>.appspot.com`; use `--bucket` para sobrescrever.

### 2. Ativação de Data Access Audit Logs no GCP (Story 7.4)

Necessário para que o evento `storage.objects.delete` seja capturado pelos alertas de monitoramento e para auditar acessos de leitura aos PDFs privados (LGPD):

```bash
# Simulação / Dry-run
./scripts/setup-gcp-data-access-logs.sh --project meu-projeto --dry-run

# Aplicação real com retenção de 5 anos no Cloud Logging
./scripts/setup-gcp-data-access-logs.sh --project meu-projeto --apply --retention-5y
```

### 3. Verificação de Governança e Auditoria do Ambiente GCP

Inspeciona o projeto GCP ativo e emite relatório com status de conformidade:

```bash
./scripts/verificar-governanca-gcp.sh --project meu-projeto
```

Para o checklist completo de homologação e deploy em produção, consulte [`docs/checklist-homologacao-deploy.md`](../docs/checklist-homologacao-deploy.md).

## Princípios

- **Menor privilégio**: contas de serviço recebem apenas os papéis necessários.
- **Auditoria**: alterações de IAM, Rules, contas de serviço, deleções e backup
  são monitoradas por Cloud Audit Logs. Acessos aos termos privados no Storage
  possuem trilha imutável via Data Access logs.
- **Sem trava irreversível**: nenhuma retenção é aplicada como *lock* permanente
  no repositório, permitindo correção operacional sob obrigação legal superior.
- **Retenção**: ficha, auditoria, PDFs e backups são retidos por 5 anos; a rotina
  autorizada (`executarRotinaRetencao`) anonimiza fichas elegíveis e expurga
  rascunhos abandonados, sem apagar auditoria, evidências ou termos.

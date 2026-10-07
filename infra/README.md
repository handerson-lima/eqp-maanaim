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

## Uso

```bash
# Simulação (padrão): apenas imprime os comandos gcloud
node scripts/aplicar-controles-operacionais.mjs --projeto meu-projeto

# Aplicação real
node scripts/aplicar-controles-operacionais.mjs --projeto meu-projeto --executar
```

O bucket padrão é `<projeto>.appspot.com`; use `--bucket` para sobrescrever.

## Princípios

- **Menor privilégio**: contas de serviço recebem apenas os papéis necessários.
- **Auditoria**: alterações de IAM, Rules, contas de serviço, deleções e backup
  são monitoradas por Cloud Audit Logs.
- **Sem trava irreversível**: nenhuma retenção é aplicada como *lock* permanente
  no repositório, permitindo correção operacional sob obrigação legal superior.
- **Retenção**: ficha, auditoria, PDFs e backups são retidos por 5 anos; a rotina
  autorizada (`executarRotinaRetencao`) anonimiza fichas elegíveis e expurga
  rascunhos abandonados, sem apagar auditoria, evidências ou termos.

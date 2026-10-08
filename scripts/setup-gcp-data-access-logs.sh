#!/usr/bin/env bash
# ==============================================================================
# Setup de Data Access Audit Logs no GCP (storage.googleapis.com)
# Story 7.4 / Action Item epic-6-retro-item-1-gcp-data-access-logs
# Conforme ARCHITECTURE-SPINE.md (AD-12) e LGPD (Art. 37 e 46)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_ID=""
DRY_RUN=false
APPLY=false
SET_LOG_RETENTION=false

mostrar_ajuda() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Configura de forma idempotente os Cloud Audit Logs de Data Access (DATA_READ,
DATA_WRITE, ADMIN_READ) para o serviço storage.googleapis.com no projeto GCP,
garantindo rastreabilidade de acessos aos PDFs de termos e acionamento dos alertas
de deleção (AD-12).

Opções:
  -p, --project <ID>       ID do projeto GCP (se omitido, lê do .firebaserc)
  -d, --dry-run            Modo simulação: exibe a política resultante sem aplicar
  -a, --apply              Aplica a política no projeto GCP usando gcloud
  --retention-5y           Também atualiza a retenção do log bucket _Default para 1825 dias (5 anos)
  -h, --help               Exibe esta mensagem de ajuda

Exemplos:
  $(basename "$0") --project eqp-maanaim-prod --dry-run
  $(basename "$0") --project eqp-maanaim-prod --apply
  $(basename "$0") --project eqp-maanaim-prod --apply --retention-5y
EOF
}

# Processamento de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -a|--apply)
      APPLY=true
      shift
      ;;
    --retention-5y)
      SET_LOG_RETENTION=true
      shift
      ;;
    -h|--help)
      mostrar_ajuda
      exit 0
      ;;
    *)
      echo "Erro: Opção desconhecida: $1" >&2
      mostrar_ajuda
      exit 1
      ;;
  esac
done

# Descobrir projeto a partir do .firebaserc se não informado
if [[ -z "${PROJECT_ID}" ]]; then
  if [[ -f "${ROOT_DIR}/.firebaserc" ]]; then
    PROJECT_ID=$(node -e "
      try {
        const rc = JSON.parse(require('fs').readFileSync('${ROOT_DIR}/.firebaserc', 'utf8'));
        console.log(rc.projects?.default || rc.projects?.production || '');
      } catch (e) {
        console.log('');
      }
    ")
  fi
fi

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Erro: Projeto GCP não especificado. Use --project <ID> ou configure o .firebaserc." >&2
  exit 1
fi

# Se nem --dry-run nem --apply foram especificados, assumimos dry-run por segurança
if [[ "${DRY_RUN}" = false && "${APPLY}" = false ]]; then
  echo "Aviso: Nenhuma ação (--apply ou --dry-run) foi especificada. Operando em modo --dry-run por segurança."
  DRY_RUN=true
fi

echo "=================================================================="
echo "Maanaim - Governança de Logs GCP & Data Access (Story 7.4)"
echo "Projeto Alvo: ${PROJECT_ID}"
echo "Modo: $(if [[ "${APPLY}" = true ]]; then echo "APLICAÇÃO REAL"; else echo "SIMULAÇÃO (DRY-RUN)"; fi)"
echo "=================================================================="

# Verificar se gcloud está disponível
if ! command -v gcloud &> /dev/null; then
  echo "Erro: O utilitário 'gcloud' não foi encontrado no PATH." >&2
  exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

CURRENT_POLICY_FILE="${TEMP_DIR}/current_policy.json"
NEW_POLICY_FILE="${TEMP_DIR}/new_policy.json"
CONFIG_STORAGE="${ROOT_DIR}/infra/gcp-audit-logs-storage.json"

if [[ ! -f "${CONFIG_STORAGE}" ]]; then
  echo "Erro: Arquivo canônico ${CONFIG_STORAGE} não encontrado." >&2
  exit 1
fi

echo "1. Obtendo a política IAM atual do projeto ${PROJECT_ID}..."
if ! gcloud projects get-iam-policy "${PROJECT_ID}" --format=json > "${CURRENT_POLICY_FILE}"; then
  echo "Erro: Falha ao obter a política IAM do projeto ${PROJECT_ID}. Verifique suas credenciais no gcloud." >&2
  exit 1
fi

echo "2. Mesclando a configuração canônica de Data Access logs para storage.googleapis.com..."
node -e "
  const fs = require('fs');
  const policy = JSON.parse(fs.readFileSync('${CURRENT_POLICY_FILE}', 'utf8'));
  const storageConfig = JSON.parse(fs.readFileSync('${CONFIG_STORAGE}', 'utf8'));

  if (!policy.auditConfigs) {
    policy.auditConfigs = [];
  }

  let storageIndex = policy.auditConfigs.findIndex(c => c.service === 'storage.googleapis.com');
  if (storageIndex === -1) {
    policy.auditConfigs.push(storageConfig);
    console.log('   -> Adicionada nova entrada de auditConfigs para storage.googleapis.com');
  } else {
    const existing = policy.auditConfigs[storageIndex];
    if (!existing.auditLogConfigs) existing.auditLogConfigs = [];
    
    const requiredTypes = ['DATA_READ', 'DATA_WRITE', 'ADMIN_READ'];
    let modified = false;
    for (const reqType of requiredTypes) {
      if (!existing.auditLogConfigs.some(log => log.logType === reqType)) {
        existing.auditLogConfigs.push({ logType: reqType });
        modified = true;
      }
    }
    if (modified) {
      console.log('   -> Atualizada entrada existente de storage.googleapis.com com tipos de log faltantes');
    } else {
      console.log('   -> storage.googleapis.com já possui todos os tipos de log requeridos (idempotente)');
    }
  }

  fs.writeFileSync('${NEW_POLICY_FILE}', JSON.stringify(policy, null, 2), 'utf8');
"

if [[ "${DRY_RUN}" = true ]]; then
  echo ""
  echo "=================================================================="
  echo "SIMULAÇÃO CONCLUÍDA (--dry-run):"
  echo "A política resultante conteria a seguinte seção de auditConfigs:"
  echo "=================================================================="
  node -e "
    const fs = require('fs');
    const policy = JSON.parse(fs.readFileSync('${NEW_POLICY_FILE}', 'utf8'));
    console.log(JSON.stringify(policy.auditConfigs, null, 2));
  "
  echo "=================================================================="
  echo "Nenhuma alteração foi realizada no GCP."
  echo "Para aplicar de fato, execute: $0 --project ${PROJECT_ID} --apply"
  if [[ "${SET_LOG_RETENTION}" = true ]]; then
    echo "Comando adicional para retenção de 5 anos no Cloud Logging:"
    echo "gcloud logging buckets update _Default --location=global --retention-days=1825 --project=${PROJECT_ID}"
  fi
  exit 0
fi

if [[ "${APPLY}" = true ]]; then
  echo "3. Aplicando nova política IAM no projeto GCP ${PROJECT_ID}..."
  gcloud projects set-iam-policy "${PROJECT_ID}" "${NEW_POLICY_FILE}"
  echo "   ✓ Política IAM atualizada com sucesso!"

  if [[ "${SET_LOG_RETENTION}" = true ]]; then
    echo "4. Atualizando retenção do Cloud Logging (_Default) para 1825 dias (5 anos)..."
    gcloud logging buckets update _Default --location=global --retention-days=1825 --project="${PROJECT_ID}"
    echo "   ✓ Retenção do Cloud Logging configurada para 1825 dias!"
  fi

  echo ""
  echo "=================================================================="
  echo "SUCESSO: Data Access Audit Logs ativados para storage.googleapis.com!"
  echo "Alertas de deleção (storage.objects.delete) agora estão operacionais."
  echo "=================================================================="
fi

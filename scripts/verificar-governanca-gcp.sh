#!/usr/bin/env bash
# ==============================================================================
# Verificação e Auditoria de Governança GCP (Story 7.4)
# Valida Data Access Logs, Lifecycle de Storage e Políticas de Alerta
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_ID=""
BUCKET_NAME=""

mostrar_ajuda() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Inspeciona o ambiente GCP e emite relatório formal de conformidade com a política
de governança (AD-12 e Story 7.4):
  - Habilitação de Data Access audit logs em storage.googleapis.com
  - Retenção e lifecycle de 5 anos no bucket de storage
  - Registro das políticas de alerta do Cloud Monitoring

Opções:
  -p, --project <ID>       ID do projeto GCP (se omitido, lê do .firebaserc)
  -b, --bucket <NOME>      Nome do bucket de Storage (padrão: <PROJETO>.appspot.com)
  -h, --help               Exibe esta mensagem de ajuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -b|--bucket)
      BUCKET_NAME="$2"
      shift 2
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

if [[ -z "${BUCKET_NAME}" ]]; then
  if gcloud storage buckets describe "gs://${PROJECT_ID}.firebasestorage.app" &>/dev/null; then
    BUCKET_NAME="${PROJECT_ID}.firebasestorage.app"
  else
    BUCKET_NAME="${PROJECT_ID}.appspot.com"
  fi
fi

if ! command -v gcloud &> /dev/null; then
  echo "Erro: O utilitário 'gcloud' não foi encontrado no PATH." >&2
  exit 1
fi

echo "=================================================================="
echo "Relatório de Governança e Auditoria GCP - Maanaim (Story 7.4)"
echo "Projeto: ${PROJECT_ID}"
echo "Bucket Alvo: gs://${BUCKET_NAME}"
echo "Data/Hora: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "=================================================================="

TOTAL_CHECKS=0
TOTAL_PASS=0
TOTAL_WARN=0
TOTAL_FAIL=0

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# 1. Checagem de Data Access Logs
echo -n "1. Cloud Audit Logs (storage.googleapis.com): "
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if gcloud projects get-iam-policy "${PROJECT_ID}" --format=json > "${TEMP_DIR}/iam_policy.json" 2>/dev/null; then
  CHECK_LOGS=$(node -e "
    const fs = require('fs');
    const policy = JSON.parse(fs.readFileSync('${TEMP_DIR}/iam_policy.json', 'utf8'));
    const sc = policy.auditConfigs?.find(c => c.service === 'storage.googleapis.com');
    if (!sc || !sc.auditLogConfigs) {
      console.log('MISSING');
      process.exit(0);
    }
    const types = sc.auditLogConfigs.map(l => l.logType);
    const hasRead = types.includes('DATA_READ');
    const hasWrite = types.includes('DATA_WRITE');
    const hasAdmin = types.includes('ADMIN_READ');
    if (hasRead && hasWrite && hasAdmin) {
      console.log('OK');
    } else {
      console.log('PARTIAL:' + types.join(','));
    }
  ")

  if [[ "${CHECK_LOGS}" = "OK" ]]; then
    echo "[OK] Habilitado (DATA_READ, DATA_WRITE, ADMIN_READ)"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  elif [[ "${CHECK_LOGS}" =~ ^PARTIAL ]]; then
    echo "[AVISO] Parcialmente configurado (${CHECK_LOGS#PARTIAL:})"
    TOTAL_WARN=$((TOTAL_WARN + 1))
  else
    echo "[FALHA] Não configurado ou ausente"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
else
  echo "[ERRO] Não foi possível obter política IAM (verifique credenciais)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

# 2. Checagem de Lifecycle do Bucket de Storage
echo -n "2. Lifecycle de 5 anos no bucket gs://${BUCKET_NAME}: "
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if gcloud storage buckets describe "gs://${BUCKET_NAME}" --format=json > "${TEMP_DIR}/bucket.json" 2>/dev/null; then
  CHECK_LIFECYCLE=$(node -e "
    const fs = require('fs');
    const b = JSON.parse(fs.readFileSync('${TEMP_DIR}/bucket.json', 'utf8'));
    const rules = b.lifecycle_config?.rule || b.lifecycle?.rule || [];
    const delete5y = rules.find(r => 
      (r.action?.type === 'Delete' || r.action?.type === 'delete') &&
      r.condition?.age >= 1825 &&
      (r.condition?.matchesPrefix || r.condition?.matches_prefix || []).some(p => p.startsWith('pdfs'))
    );
    console.log(delete5y ? 'OK' : 'MISSING');
  ")

  if [[ "${CHECK_LIFECYCLE}" = "OK" ]]; then
    echo "[OK] Configurado (expurgo de pdfs/ após 1825 dias)"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    echo "[AVISO] Regra de lifecycle para 1825 dias não detectada no bucket"
    TOTAL_WARN=$((TOTAL_WARN + 1))
  fi
else
  echo "[INFO] Bucket não acessível ou ainda não provisionado no ambiente"
  TOTAL_WARN=$((TOTAL_WARN + 1))
fi

# 3. Checagem de Políticas de Alerta
echo -n "3. Políticas de Alerta de Segurança (Cloud Monitoring): "
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if gcloud monitoring policies list --project="${PROJECT_ID}" --format=json > "${TEMP_DIR}/policies.json" 2>/dev/null; then
  CHECK_POLICIES=$(node -e "
    const fs = require('fs');
    const list = JSON.parse(fs.readFileSync('${TEMP_DIR}/policies.json', 'utf8')) || [];
    const expected = JSON.parse(fs.readFileSync('${ROOT_DIR}/infra/alertas-monitoramento.json', 'utf8')).policies || [];
    const foundCount = expected.filter(exp => list.some(p => p.displayName === exp.displayName)).length;
    console.log(foundCount + '/' + expected.length);
  ")

  if [[ "${CHECK_POLICIES}" =~ ^5/5 ]]; then
    echo "[OK] Todas as 5 políticas de alerta ativas (${CHECK_POLICIES})"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    echo "[AVISO] ${CHECK_POLICIES} políticas ativas encontradas"
    TOTAL_WARN=$((TOTAL_WARN + 1))
  fi
else
  echo "[AVISO] Não foi possível listar políticas de monitoramento"
  TOTAL_WARN=$((TOTAL_WARN + 1))
fi

echo "=================================================================="
echo "Resumo da Avaliação: Total: ${TOTAL_CHECKS} | Conformes: ${TOTAL_PASS} | Avisos: ${TOTAL_WARN} | Falhas: ${TOTAL_FAIL}"
if [[ ${TOTAL_FAIL} -eq 0 && ${TOTAL_WARN} -eq 0 ]]; then
  echo "Status Geral: CONFORME COM A GOVERNANÇA (AD-12 / Story 7.4)"
  exit 0
elif [[ ${TOTAL_FAIL} -eq 0 ]]; then
  echo "Status Geral: ATENÇÃO (Configurações recomendadas pendentes)"
  exit 0
else
  echo "Status Geral: NÃO CONFORME (Itens críticos pendentes de correção)"
  exit 2
fi

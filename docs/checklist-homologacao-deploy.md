# Checklist Formal de Homologação e Prontidão de Deploy (AD-1, AD-12, AD-13, AD-14)

Este documento estabelece o protocolo canônico e normativo para validação, homologação e promoção de releases do sistema **eqp_maanaim** para os ambientes de Homologação (`staging`) e Produção (`production`).

---

## 🛡️ Portão 1: Validação de Código, Tipagem e Testes Automatizados (CI)

Antes de qualquer aprovação de PR ou disparo de deploy, todos os testes e verificações estáticas devem passar com código de saída zero (`exit code 0`):

- [ ] **Typecheck e Lint do Backend (Cloud Functions):**
  ```bash
  npm run typecheck --prefix functions
  npm run lint --prefix functions
  ```
- [ ] **Suíte de Testes Unitários e de Integração do Backend:**
  ```bash
  npm test --prefix functions
  ```
  *(Verificar se todos os 485+ testes foram executados e aprovados).*
- [ ] **Suíte de Testes do Firebase Emulator Suite (Headless):**
  ```bash
  npm run test:emulator --prefix functions
  ```
  *(Garante integridade transacional, regras de segurança do Firestore/Storage e concorrência).*
- [ ] **Análise Estática Estrita do Frontend Flutter:**
  ```bash
  flutter analyze --fatal-infos --fatal-warnings
  ```
  *(Sem avisos, dead code ou warnings de tipagem).*
- [ ] **Suíte de Testes de Unidade, Componentes e Acessibilidade do Flutter:**
  ```bash
  flutter test
  ```
  *(Todos os 278+ testes passando).*
- [ ] **Segurança de Regras (Firestore & Storage):**
  - Proibição absoluta de escrita direta do cliente no Firestore (`allow write: if false;`).
  - Proibição de escrita e leitura direta sem autoridade no Storage (`allow read, write: if false;`).

---

## 🏛️ Portão 2: Governança de Infraestrutura, Auditoria e GCP

Verificar e aplicar as políticas de conformidade no projeto GCP alvo antes do deploy de código:

- [ ] **Isolamento de Ambientes (`.firebaserc` e `infra/ambientes-firebase.json`):**
  - Confirmar que o ambiente de destino está corretamente selecionado:
    - Homologação: `eqp-maanaim-staging`
    - Produção: `eqp-maanaim-prod`
- [ ] **Ativação de Cloud Audit Logs (Data Access para `storage.googleapis.com`):**
  - Executar simulação prévia:
    ```bash
    ./scripts/setup-gcp-data-access-logs.sh --project <PROJECT_ID> --dry-run
    ```
  - Aplicar no GCP com retenção de 5 anos no Cloud Logging:
    ```bash
    ./scripts/setup-gcp-data-access-logs.sh --project <PROJECT_ID> --apply --retention-5y
    ```
- [ ] **Aplicação de Controles Operacionais de Retenção (5 Anos):**
  - Aplicar lifecycle no bucket privado (`infra/storage-lifecycle.json`):
    ```bash
    node scripts/aplicar-controles-operacionais.mjs --projeto <PROJECT_ID> --executar
    ```
- [ ] **Políticas de Alerta de Segurança (Cloud Monitoring):**
  - Confirmar as 5 políticas ativas: IAM, RULES, SERVICE_ACCOUNT, DELETION e BACKUP_FAILURE.
- [ ] **Relatório de Governança Automatizado:**
  - Executar o script de verificação formal:
    ```bash
    ./scripts/verificar-governanca-gcp.sh --project <PROJECT_ID>
    ```
  - *Critério de Aceite:* Status Geral `[CONFORME COM A GOVERNANÇA]`.

---

## 🧪 Portão 3: Homologação Pré-Deploy (Staging)

No ambiente de `staging`, executar a validação funcional e de conformidade:

- [ ] **Fluxo Ponta a Ponta de Aprovação:**
  - Submissão de ficha com consentimento LGPD de voluntário.
  - Aprovação do Pastor Local (`aprovarPastorLocal`).
  - Aprovação do Responsável de Equipe (`aprovarResponsavelEquipe`).
  - Conclusão e ativação pelo Coordenador (`concluirCoordenador`).
- [ ] **Geração e Rastreabilidade do Termo Oficial em PDF:**
  - Invocação do endpoint callable autenticado `gerarPdfParticipacao`.
  - Verificação de persistência física sob `gs://<bucket>/pdfs/:fichaId/:documentoId.pdf`.
  - Invocação de `obterUrlDownloadPdf` e download via URL assinada (TTL de 15 minutos).
  - Consulta aos logs do GCP Cloud Logging confirmando emissão do evento `DATA_READ` em `storage.googleapis.com`.
- [ ] **Teste de Proteção contra Deleções:**
  - Confirmar que qualquer tentativa indevida de exclusão dispara evento `DATA_WRITE` e alerta correspondente no Cloud Monitoring.

---

## 🚀 Portão 4: Execução do Deploy em Produção

Com os Portões 1, 2 e 3 devidamente aprovados:

1. **Deploy de Índices Compostos do Firestore:**
   ```bash
   firebase deploy --only firestore:indexes --project production
   ```
2. **Deploy das Regras de Segurança (Firestore & Storage):**
   ```bash
   firebase deploy --only firestore:rules,storage --project production
   ```
3. **Deploy das Cloud Functions (Node 22):**
   ```bash
   firebase deploy --only functions --project production
   ```
4. **Compilação e Deploy do Frontend Web/PWA:**
   ```bash
   flutter build web --release \
     --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
     --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID" \
     --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
     --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
     --dart-define=FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY="$RECAPTCHA_KEY"
   firebase deploy --only hosting --project production
   ```
5. **Smoke Tests Imediatos Pós-Deploy:**
   - Carregamento da página inicial (`Inicio`) e login com App Check ativo.
   - Navegação no shell administrativo (`AdminShell`).
   - Verificação de zero erros no Google Cloud Error Reporting / Cloud Logging nas primeiras 24 horas.

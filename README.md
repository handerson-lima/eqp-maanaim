# eqp_maanaim

Bootstrap de autenticação pública. Use Flutter estável (Dart >=3.11, conforme `flutter_app/pubspec.lock`), Node 20 e Firebase CLI compatível.

## Ambiente local

Nunca versione chaves ou URLs de produção. Instale dependências com `flutter pub get --directory flutter_app` e `npm install --prefix functions`. Execute testes com `flutter test` dentro de `flutter_app` e `npm test --prefix functions`.

Para iniciar a PWA, passe os valores do projeto de desenvolvimento via `--dart-define`: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `PASSWORD_RESET_CONTINUE_URL` e `FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY`. Todos são obrigatórios na inicialização; cadastre a URL de continuação e os domínios autorizados no Firebase Authentication de cada ambiente. Registre a chave pública reCAPTCHA v3 no Firebase App Check e ative a proteção da callable. Não versione nenhuma configuração de ambiente. Para emuladores, use `firebase emulators:start` e configure o cliente para os hosts locais no bootstrap do ambiente.

Para conectar o cliente aos emuladores, declare explicitamente `--dart-define=FIREBASE_USE_EMULATORS=true`. Opcionalmente use `FIREBASE_EMULATOR_HOST` (padrão `127.0.0.1`); sem a flag, nenhum host de emulador é usado.

## Recuperação de senha e enumeração de contas

A tela de recuperação sempre mostra uma mensagem neutra, sem revelar se o e-mail existe. O provedor é o Firebase Authentication, que já responde de forma uniforme para contas inexistentes; não substitua por um endpoint próprio que diferencie os casos. Mantenha a proteção contra enumeração habilitada no console (Authentication → Settings → User actions) em cada ambiente e registre a URL de continuação.

## Modelo de dados (Firestore)

- `igrejas/{igrejaId}` — catálogo administrável, sem PII. O cliente só lê igrejas ativas; escrita negada.
- `fichas/{uid}` — ficha privada (contém CPF e demais PII). Nunca é lida ou gravada diretamente pelo cliente; o estado permitido vem da callable.
- `commands/{commandId}` — recibo idempotente correlacionado ao comando; sem PII.
- `auditOutbox/{commandId}` — evidência auditável append-only; sem PII.

Regras deny-by-default em `firestore.rules`: toda a escrita de domínio e toda leitura de ficha são negadas ao cliente.

## Pastores importados

Pastores importados não recebem convite automático. Eles definem a primeira senha por **Esqueci minha senha**, como qualquer conta existente; esse fluxo não cria nem altera papel, vínculo ou escopo.

## Carga inicial de pastores e vínculos

Carga administrativa, idempotente e transacional que associa um Pastor Local vigente a cada igreja a partir da planilha local `igreja,pastor,email`. A planilha nunca é versionada e o relatório nunca ecoa PII.

### Pré-requisitos

- Igrejas canônicas já semeadas em `igrejas/{id}` com `codigo` como `String` e `ativo: true` (Story 1.2). Código ausente ou igreja inativa recusam a linha sem gravar vínculo parcial.
- `npm run build --prefix functions` antes de executar o script (ele consome `functions/lib`).
- Credenciais administrativas por Application Default Credentials (produção) ou variáveis do Emulator (`FIREBASE_AUTH_EMULATOR_HOST`, `FIRESTORE_EMULATOR_HOST`, `GCLOUD_PROJECT`).

### Execução

```bash
# 1) simulação: valida planilha e base, sem gravar nada
node scripts/importar-pastores-iniciais.mjs --dry-run "/caminho/local/igreja-pastor-email.csv"

# 2) execução (emulador ou credenciais administrativas)
node scripts/importar-pastores-iniciais.mjs --executar "/caminho/local/igreja-pastor-email.csv"
```

O script imprime o `ResultadoImportacao` em JSON: `commandId`, `origem`, `modo`, `status`, as contagens (`total`, `criados`, `jaVigentes`, `simulados`, `recusados`) e `linhas`, cada uma com `codigoIgreja`, `status` e, quando recusada, `motivo` — nunca nomes, e-mails ou CPF. Sai com código `1` se houver qualquer linha recusada.

### Comportamento

- Deduplica a pessoa pela conta Firebase Authentication (e-mail); um pastor em várias igrejas gera uma única `pessoas/{uid}` e um vínculo próprio por igreja.
- Cria a conta sem senha e sem convite; o pastor define a senha por recuperação na tela de login.
- Mantém no máximo um Pastor Local vigente por igreja; se a igreja já tem outro responsável, recusa a linha e exige o fluxo explícito de substituição.
- Os vínculos ausentes na planilha são acrescentados por referência a outra igreja do mesmo pastor: Macau (`240005`) pela identidade de Mossoró (`240006`) e Ponta Negra (`240029`) pela de Monte Alegre (`240022`), sem o sufixo `| RN`.
- A vigência inicia na execução, em UTC; recibo (`commands`), evidência (`vinculosPastorIgreja`) e `auditOutbox` são gravados na mesma transação do vínculo.
- Reexecutar é idempotente: não duplica pessoas, contas, igrejas ou vínculos e preserva nomes/vínculos editados depois.

### Recuperação segura

Se a Firebase CLI/emulador falhar, nenhuma transação parcial é confirmada: corrija o ambiente e reexecute o mesmo comando (ou a mesma planilha com novo `--command-id`). Linhas recusadas podem ser corrigidas e reenviadas; vínculos já criados retornam `JA_VIGENTE`.

Coleções envolvidas: `igrejas` (catálogo e ponteiro vigente), `pessoas` (PII mínima), `vinculosPastorIgreja` (histórico append-only), `commands` e `auditOutbox` (correlação sem PII). Toda escrita direta do cliente é negada pelas Rules.

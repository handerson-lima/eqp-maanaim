# eqp_maanaim

PWA administrativa para gestão de voluntários do Maanaim. Use Flutter estável (Dart >=3.11, conforme `flutter_app/pubspec.lock`), Node 22 e Firebase CLI compatível.

## Ambiente local

Nunca versione chaves ou URLs de produção. Instale dependências com `flutter pub get --directory flutter_app` e `npm install --prefix functions`. Execute testes com `flutter test` dentro de `flutter_app` e `npm test --prefix functions`.

## Integração Contínua (CI/CD)

O projeto possui validação contínua automatizada via GitHub Actions (`.github/workflows/ci.yml`), disparada em `push` e `pull_request` na branch `main`:
- **Backend CI (`backend-ci`):** Executa em Ubuntu com Node 22 e Java 21 (Temurin). Instala dependências, roda checagem de tipos (`typecheck`), compilação TypeScript (`build`), suíte de testes unitários (`npm test`) e executa todos os 6 testes de emuladores e regras de segurança sob o Firebase Emulator Suite headless (`firebase emulators:exec --only auth,firestore,storage,functions "npm run test:emulator --prefix functions"`).
- **Frontend CI (`frontend-ci`):** Executa em Ubuntu com Flutter estável. Roda análise estática rigorosa (`flutter analyze --fatal-infos --fatal-warnings`) e a suíte completa de testes de widget e unidade (`flutter test`).


### Configuração com `--dart-define-from-file`

Crie `flutter_app/.env.dartdefines.json` (ignorado pelo Git) com as variáveis do projeto:

```json
{
  "FIREBASE_API_KEY": "...",
  "FIREBASE_APP_ID": "...",
  "FIREBASE_MESSAGING_SENDER_ID": "...",
  "FIREBASE_PROJECT_ID": "eqp-maanaim",
  "FIREBASE_AUTH_DOMAIN": "eqp-maanaim.firebaseapp.com",
  "PASSWORD_RESET_CONTINUE_URL": "https://eqp-maanaim.web.app/",
  "FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY": "..."
}
```

Comandos de execução:

```bash
# Desenvolvimento local
cd flutter_app
flutter run -d chrome --dart-define-from-file=.env.dartdefines.json

# Build de produção
flutter build web --dart-define-from-file=.env.dartdefines.json
```

Para conectar o cliente aos emuladores, adicione `"FIREBASE_USE_EMULATORS": "true"` ao JSON ou use `--dart-define=FIREBASE_USE_EMULATORS=true`. Opcionalmente use `FIREBASE_EMULATOR_HOST` (padrão `127.0.0.1`); sem a flag, nenhum host de emulador é usado.

### App Check (reCAPTCHA v3)

A variável `FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY` é obrigatória. Para registrar:

1. Abra o [Console Firebase App Check](https://console.firebase.google.com/project/eqp-maanaim/appcheck).
2. Selecione o app "Maanaim Web".
3. Escolha reCAPTCHA v3 e copie a **chave do site**.
4. Adicione os domínios autorizados: `eqp-maanaim.web.app`, `eqp-maanaim.firebaseapp.com`, `localhost`.
5. Cole a chave no arquivo `.env.dartdefines.json`.

Para desenvolvimento local com emuladores, a chave pode ser um placeholder (o Functions Emulator não valida App Check).

### Deploy no Firebase Hosting

```bash
# 1. Build do Flutter Web
cd flutter_app
flutter build web --dart-define-from-file=.env.dartdefines.json

# 2. Deploy
cd ..
firebase deploy --only hosting
```

A PWA será publicada em `https://eqp-maanaim.web.app/`. O bloco `hosting` no `firebase.json` aponta `public` para `flutter_app/build/web` com rewrite SPA.


## Recuperação de senha e enumeração de contas

A tela de recuperação sempre mostra uma mensagem neutra, sem revelar se o e-mail existe. O provedor é o Firebase Authentication, que já responde de forma uniforme para contas inexistentes; não substitua por um endpoint próprio que diferencie os casos. Mantenha a proteção contra enumeração habilitada no console (Authentication → Settings → User actions) em cada ambiente e registre a URL de continuação.

## Modelo de dados (Firestore)

- `igrejas/{igrejaId}` — catálogo administrável, sem PII. O cliente só lê igrejas ativas; escrita negada.
- `equipes/{equipeId}` — catálogo administrável, sem PII. O cliente só lê equipes ativas; escrita negada.
- `fichas/{uid}` — ficha privada (contém CPF e demais PII). Nunca é lida ou gravada diretamente pelo cliente; o estado permitido vem da callable.
- `commands/{commandId}` — recibo idempotente correlacionado ao comando; sem PII.
- `auditOutbox/{commandId}` — evidência auditável append-only; sem PII.
- `autoridadesAdministrativas/{uid}` — autoridade canônica de administração (fonte de verdade do papel); a Custom Claim é apenas projeção reconciliada. Sem PII.

Regras deny-by-default em `firestore.rules`: toda a escrita de domínio e toda leitura de ficha são negadas ao cliente.

## Primeiro administrador

Após criar a identidade no Firebase Authentication, compile as Functions (`npm run build --prefix functions`, o script consome `functions/lib`) e execute o processo local com ADC/IAM e o UID somente em memória: `UID_ADMINISTRADOR=<uid> npm run conceder-primeiro-admin --prefix functions`. O script não aceita e-mail, senha ou token, não imprime o UID e pode ser repetido para retomar a reconciliação da Custom Claim. A variável segura é `UID_ADMINISTRADOR` (não versione seu valor). O operador precisa de acesso mínimo a Firebase Auth e Firestore; não existe endpoint HTTP para esse bootstrap. As dependências são resolvidas a partir de `functions/node_modules` (não há `node_modules` na raiz).

`storage.rules` também nega leitura e escrita direta. Para validar Rules no Emulator, inicie `firebase emulators:exec --only firestore,storage,functions "npm test --prefix functions"`.

## Pastores importados

Pastores importados não recebem convite automático. Eles definem a primeira senha por **Esqueci minha senha**, como qualquer conta existente; esse fluxo não cria nem altera papel, vínculo ou escopo.

## Catálogo inicial de igrejas e equipes

O catálogo canônico (25 igrejas e 14 equipes do PRD) é semeado pela callable `semearCatalogoInicial`, restrita a administrador autorizado com App Check. O comando é idempotente por chave natural (código `String` da igreja; nome normalizado da equipe): cria só o ausente, nunca sobrescreve alterações administrativas, grava `commands/{commandId}` e `auditOutbox/{commandId}` na mesma transação e aceita replay apenas com o mesmo `commandId`/`payloadHash` (comando divergente é recusado). A callable `consultarCatalogo`, também read-only e autorizada, devolve igrejas como "Nome - Código", ordenadas por nome e pesquisáveis por nome ou código. A leitura de `igrejas`/`equipes` ativas é permitida ao cliente (dropdown público); a escrita permanece negada.

### Seed operacional

Na área administrativa, a aba **Seed** dispara `semearCatalogoInicial` com um `commandId` opaco, mostra o recibo (incluindo replay idempotente) e oferece retentativa acessível. Para execução local/operacional com ADC ou emulador, o script também continua disponível (o UID é usado só como chave da autoridade canônica e nunca aparece na saída):

```bash
npm run build --prefix functions
UID_ADMINISTRADOR=<uid> npm run semear-catalogo-inicial --prefix functions -- --dry-run   # simula, sem gravar
UID_ADMINISTRADOR=<uid> npm run semear-catalogo-inicial --prefix functions -- --executar  # aplica o seed
```

O script valida `autoridadesAdministrativas/{uid}` antes de qualquer gravação, cria apenas o ausente e imprime o recibo em JSON. Reexecutar é idempotente.

> **Break-glass.** O caminho preferido e canônico de mutação é a callable `semearCatalogoInicial` (Auth + App Check). O script acima é uma exceção operacional break-glass: roda via Admin SDK/ADC, fora da fronteira App Check, e exige que o operador já tenha autoridade administrativa vigente (`autoridadesAdministrativas/{uid}`). Use-o apenas quando a área administrativa/PWA não estiver disponível, nunca como fluxo rotineiro.

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

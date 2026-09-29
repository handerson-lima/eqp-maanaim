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

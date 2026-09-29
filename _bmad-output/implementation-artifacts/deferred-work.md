- source_spec: none
  summary: Implementar cadastro público de voluntários e recuperação de senha por e-mail.
  evidence: Foi separado da importação administrativa de pastores e vínculos, pois pode ser entregue e validado como fluxo público independente.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Executar a integração por Firebase Emulator da transação da callable e das Rules.
  evidence: A verificação só existe sob `firebase emulators:exec`; a Firebase CLI falha ao iniciar o Emulator neste ambiente (firepit-log.txt), então Rules e transação seguem cobertas apenas por testes de contrato/domínio.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Tornar a PWA instalável com ícones e alvo de deploy (`hosting`/`.firebaserc`).
  evidence: O manifesto não declara `icons` e não há bloco `hosting` nem alias de projeto; impacta instalabilidade e publicação, fora do bootstrap de autenticação.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Restaurar sessão ao recarregar e permitir encerrar sessão.
  evidence: `main.dart` sempre abre `Inicio` e `AreaAutenticada` não tem sign-out, deixando o usuário autenticado sem retorno ao rascunho; a entrega atual cobre apenas cadastro/login/recuperação.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Adicionar verificação de e-mail e unicidade de CPF.
  evidence: Nenhuma etapa exige e-mail verificado nem impede UIDs distintos com o mesmo CPF; são regras de domínio/identidade não previstas nesta entrega.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Definir consumidor, TTL/retenção de `commands` e `auditOutbox` e minimização de PII da ficha.
  evidence: Recibo e auditoria são gravados sem política de retenção documentada e a ficha guarda CPF em texto plano sem minimização definida.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Unificar a validação Dart/TS, expor o estado da callable ao cliente e cobrir acessibilidade/CI.
  evidence: Regras de campo e mensagem genérica duplicadas em `validadores.dart`/`rascunho.ts`; `cadastrar` descarta `estado`/`retomado`; não há verificação automatizada de teclado/44 px/leitor de tela nem workflow de CI.
- source_spec: `_bmad-output/implementation-artifacts/spec-importacao-inicial-de-pastores-e-vinculos.md`
  summary: Orquestrar a suíte de Emulator da carga inicial em runner automatizado.
  evidence: A persistência real (adapter Firestore/Auth de `firestoreImportacao.ts`) só é exercitada por `importacao.emulator.test.ts`, marcada com `skipIf` sem `FIRESTORE_EMULATOR_HOST`/`FIREBASE_AUTH_EMULATOR_HOST`; o script `test:emulator` não chama `firebase emulators:exec` e não há CI, então o comando padrão passa com a suíte pulada.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Exercitar no Emulator a callable de administração, o reconciliador de claim, o script operacional e as Rules de Firestore/Storage.
  evidence: A verificação depende de Auth/Firestore/Storage Emulator; a CLI falha ao iniciar o Emulator neste ambiente (mesma causa registrada para `spec-autenticacao-publica`), então a cobertura segue em testes de domínio e contratos de texto.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Definir consumidor/materializador de `auditOutbox` e retomada de recibos `PENDENTE_CLAIM`.
  evidence: A transação grava recibo e outbox, mas nenhum worker drena a outbox nem finaliza a claim após falha entre a gravação canônica e a projeção externa; um crash deixa estado recuperável apenas manualmente.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Compartilhar o nome da Custom Claim administrativa entre Dart e TypeScript.
  evidence: `maanaimAdmin` é literal em `auth_service.dart` e em `functions/src/domain/autoridadeAdministrativa.ts`; sem contrato compartilhado, uma renomeação de um lado silenciosamente desautoriza o outro.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Serializar a escrita de Custom Claims para não perder claims de outros domínios em corridas.
  evidence: `setCustomUserClaims` substitui o mapa inteiro; duas reconciliações sobrepostas (callable + bootstrap) podem reescrever claims alheias a partir de uma leitura anterior, e o teto de tentativas apenas detecta a corrida da revisão canônica.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Revalidar a existência da identidade de destino dentro da transação.
  evidence: A callable valida `getUser` antes da transação, mas um alvo excluído entre a validação e o commit grava autoridade ativa para conta inexistente e deixa o recibo em `PENDENTE_CLAIM`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-seed-idempotente-de-igrejas-e-equipes.md`
  summary: Gestão administrativa de igrejas e equipes (edição e inativação sem exclusão física).
  evidence: O núcleo desta story ficou no seed idempotente e na consulta read-only (AC1–AC3); a inativação (AC4) e a edição do catálogo foram diferidas para conter o escopo e o tamanho do spec, e serão retomadas em uma story de gestão administrativa.

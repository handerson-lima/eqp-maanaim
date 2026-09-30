<!-- bmad:context -->
<!-- Verified 2026-09-28; no Git repository detected. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## eqp_maanaim

Sistema Flutter Web/PWA mobile-first para gestão de voluntários do Maanaim, com Firebase e Google Cloud. O contrato canônico está em `_bmad-output/specs/spec-gestao-voluntarios-maanaim/SPEC.md`; decisões vinculantes estão no Architecture Spine. É um projeto greenfield: fixe versões e comandos de execução no bootstrap antes de tratá-los como convenção.

## Where things are

- Planejamento e histórias: `_bmad-output/planning-artifacts/epics.md`; progresso: `_bmad-output/implementation-artifacts/sprint-status.yaml`.
- Arquitetura e invariantes de domínio: `_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md`.
- UX e acessibilidade: `_bmad-output/planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/` e pacote normativo em `_bmad-output/planning-artifacts/ux/`.
- Antes de alterar requisitos, consulte o SPEC e seus companions.
- Toda implementação de UI/UX deve consultar `_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md` e a referência visual em `_bmad-output/planning-artifacts/ux/references/maanaim-ui-reference.png`.

## Policy

- Priorize mobile-first: projete e implemente primeiro para celular; expanda progressivamente para tablet e desktop.
- Obedeça ao Design System (`_bmad-output/planning-artifacts/ux/`): use tokens canônicos (`navy-900`, `blue-600`, etc.), não invente gradientes/glassmorphism e reutilize o catálogo de componentes.
- Trate responsividade como requisito central de toda interface: valide coluna única no celular, navegação lateral no desktop e tabelas em cartões no celular.
- Realize mutações críticas exclusivamente em Cloud Functions autenticadas; Firestore e Storage devem negar escrita direta de domínio.
- Nunca permita autoatribuição de papéis, nem autorize somente por papel: valide identidade, vínculo vigente, escopo, estado e tempo do servidor.
- Mantenha termos, decisões, ciclos, evidências e auditoria append-only/versionados; não apague nem sobrescreva histórico.
- Não inclua PII, assinaturas, tokens ou conteúdo sensível em logs, eventos, FCM ou erros; PDFs permanecem privados e exigem nova autorização para leitura.
- Não use enums, listas hardcoded ou constantes do Flutter para igrejas e equipes; trate-os como dados administráveis.

## Conventions that differ from defaults

- Modele ficha, participação e ciclo como agregados distintos; uma participação não pode alterar o histórico ou estado das demais.
- Centralize transições de estado no servidor, execute-as em transação, use `commandId` idempotente e compare a versão esperada do agregado.
- Registre evidência, recibo e outbox/auditoria correlacionados na mesma operação lógica; envie notificações apenas após o compromisso persistido.
- Use IDs Firestore opacos, código de igreja como `String`, timestamps UTC e estados em `UPPER_SNAKE_CASE`.
- Gere um PDF privado separado para cada participação aprovada, exclusivamente de registros e evidências persistidos; nunca aceite assinaturas ou estados enviados pelo cliente.
- Preserve WCAG 2.2 AA: não comunique estado apenas por cor, mantenha teclado/leitor de tela e alvos de toque de pelo menos 44 px.

## Known pitfalls

- Rejeição, cancelamento, expiração ou renovação de uma equipe não pode bloquear, reverter ou ocultar participações independentes.
- A ficha só é `ATIVA` com ao menos uma participação ativa; a redução de estados segue AD-11 do Architecture Spine.
- Uma equipe tem um único responsável canônico vigente; trocas preservam decisões já tomadas e redirecionam somente pendências não decididas.
- A mensagem ao voluntário para decisão negativa/cancelamento por responsável é exatamente “Procure o Pastor da igreja local para mais informações”; não exponha estado interno, motivo, ator ou “rejeitado”.
<!-- /bmad:context -->

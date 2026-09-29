---
id: SPEC-autenticacao-publica
companions:
  - authentication-flow.md
  - ../spec-gestao-voluntarios-maanaim/SPEC.md
  - ../../planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
  - ../../planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/EXPERIENCE.md
sources: []
---

> **Contrato canônico da mudança.** Este SPEC e seus companions são a referência para planejar, implementar e validar a autenticação pública; os ADs do Architecture Spine continuam vinculantes.

# Autenticação pública de voluntários

## Why

Voluntários precisam iniciar a inscrição digital sem intervenção administrativa e qualquer usuário existente, inclusive pastores carregados administrativamente, precisa recuperar o acesso de modo seguro. O fluxo deve criar identidade sem transformar autenticação em autorização ou expor dados pessoais.

## Capabilities

- **CAP-1 — Cadastro público de voluntário**
  - **intent:** Visitante pode acionar “Cadastre-se”, criar uma identidade por e-mail e senha e informar todos os dados obrigatórios da ficha para iniciar seu rascunho pessoal.
  - **success:** Uma identidade Firebase Auth válida e um rascunho associado ao seu UID são criados sem conceder papel, vínculo ou escopo; dados de igreja/equipe vêm de registros administráveis.

- **CAP-2 — Recuperação de senha**
  - **intent:** Usuário na tela de login pode acionar “Esqueci minha senha”, informar seu e-mail e receber um link seguro para definir nova senha.
  - **success:** Para conta cadastrada, Firebase Auth envia o link de redefinição; a tela sempre apresenta resposta neutra e não revela a existência da conta.

- **CAP-3 — Acesso inicial de pastores**
  - **intent:** Pastor criado pela carga administrativa pode definir a primeira senha pelo mesmo fluxo de recuperação.
  - **success:** A carga não envia convite automático e a recuperação não cria nem muda papel, vínculo ou escopo.

## Constraints

- Firebase Authentication usa e-mail/senha; senhas, e-mails, tokens e demais PII não entram em logs, erros, auditoria ou notificações.
- A criação da identidade é separada do domínio: somente Cloud Function autenticada pode criar/atualizar o rascunho privado de ficha; Firestore nega escrita direta nos recursos de domínio.
- Autenticação não concede papel, vínculo ou escopo; concessões/revogações permanecem exclusivamente no backend privilegiado e nas fontes separadas previstas em AD-2, AD-9 e AD-12.
- O formulário busca igrejas/equipes em dados administráveis, sem listas hardcoded, e valida os campos obrigatórios definidos para a ficha.
- Flutter Web/PWA é mobile-first e atende WCAG 2.2 AA: teclado, leitor de tela, foco visível, contraste/estado não dependente só de cor e alvos de 44 px.
- O fluxo respeita App Check, URLs de continuação permitidas por ambiente e regras de Firebase Auth; configurações e segredos de produção não são versionados.

## Non-goals

- Convites automáticos, autoatribuição de papéis, criação de vínculos e aprovação de voluntariado não fazem parte deste fluxo.
- Alterar senha de outro usuário, login por provedores sociais, MFA e redefinição por SMS não fazem parte desta entrega.

## Success signal

Em celular ou desktop, uma voluntária sem conta cria acesso e retoma um rascunho de ficha com os campos obrigatórios, enquanto um pastor importado redefine a senha pelo login. Em ambos os casos, nenhuma escrita direta de domínio ou elevação de privilégios é possível, e nenhum dado sensível aparece em telemetria ou mensagens.

## Assumptions

- Template de e-mail, URL de continuação autorizada e domínios Firebase Auth serão configurados por ambiente no bootstrap.

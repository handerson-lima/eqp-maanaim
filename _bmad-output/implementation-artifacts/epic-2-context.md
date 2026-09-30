# Epic 2 Context: Inscrição digital do voluntário

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permitir que o voluntário autenticado crie e mantenha sua ficha cadastral permanente vinculada à sua igreja local, pesquise e selecione de forma independente as equipes em que deseja servir, leia e dê aceite explícito na versão vigente do termo de voluntariado e envie uma solicitação rastreável para avaliação pelo Pastor Local, garantindo privacidade, integridade de dados e idempotência transacional.

## Stories

- Story 2.1: Criar e manter ficha permanente
- Story 2.2: Selecionar equipes e visualizar participações de rascunho
- Story 2.3: Ler e aceitar o termo vigente
- Story 2.4: Enviar ficha e iniciar aprovações

## Requirements & Constraints

- Autenticação e isolamento: apenas o próprio voluntário autenticado pode ler ou editar seus dados de rascunho. O acesso a fichas de terceiros é categoricamente recusado por regras de escopo e segurança.
- Campos cadastrais obrigatórios: Nome Completo, Profissão, CPF e Igreja local são requisitos obrigatórios para avançar para envio e posterior geração do termo/PDF.
- Preservação de rascunho: salvar rascunho não cria participações ativas, ciclos ou solicitações de aprovação; salva o progresso sem disparar validações de bloqueio prematuras.
- Versionamento e integridade: atualizações cadastrais em fichas já submetidas preservam decisões anteriores e registram eventos de auditoria com ator, timestamps UTC e diferencial de campos permitidos.
- Proibições de mutação direta: transições de estado do processo de envio e aprovações são executadas exclusivamente por Cloud Functions autenticadas via transações atômicas com `commandId`.

## Technical Decisions

- Entidades distintas (AD-4): `ficha`, `participacao` e `ciclo` são agregados distintos. A ficha permanente identifica o voluntário e preserva seu histórico de longo prazo.
- Identificadores e formato (Consistency Conventions): IDs Firestore opacos, timestamps UTC do servidor, estados em `UPPER_SNAKE_CASE` (`RASCUNHO`, `AGUARDANDO_PASTOR_LOCAL`, etc.). Código da igreja armazenado como `String`.
- Validação e segurança de dados (AD-12, AD-13): CPF, Nome Completo e Profissão validados e armazenados de forma estruturada. Auditoria mínima e sanitizada (sem logs com dados sensíveis desnecessários).
- Isolamento e Rules (AD-9): Firestore Security Rules garantem que voluntários comuns só tenham acesso de leitura e escrita ao seu próprio documento de rascunho/ficha privada (`request.auth.uid == userId`). Leituras amplas de fichas são proibidas.

## UX & Interaction Patterns

- Mobile-first responsivo: layout em coluna única no celular, adaptável para tablet e desktop com alvos de toque >= 44 px e foco acessível (WCAG 2.2 AA).
- Design System canônico: cores e tipografia oficiais (`navy-900`, `blue-600`, etc.), sem gradientes ou efeitos fora do padrão visual.
- Clareza de pendências: indicação objetiva de quais campos obrigatórios faltam antes de permitir o envio da ficha.
- Transparência de estado: feedback imediato ao salvar rascunho e navegação fluida entre os passos da inscrição.

## Cross-Story Dependencies

- Dependência do Epic 1: consome igrejas cadastradas/ativas e o termo de voluntariado publicado e versionado (Epic 1.5).
- Alimentação interna do Epic 2:
  - Story 2.1 cria e mantém a ficha permanente necessária para Story 2.2 (seleção de equipes) e Story 2.3 (aceite do termo).
  - Story 2.4 requer a ficha preenchida (2.1), equipes selecionadas (2.2) e aceite vigente (2.3) para disparar a transição para `AGUARDANDO_PASTOR_LOCAL` do Epic 3.

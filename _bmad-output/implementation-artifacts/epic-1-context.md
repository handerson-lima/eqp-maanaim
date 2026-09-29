# Epic 1 Context: Operação segura e configuração inicial do Maanaim

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permitir que um administrador prepare com segurança a primeira operação real do Maanaim: acessar exclusivamente as capacidades administrativas autorizadas, carregar a estrutura inicial sem destruir administração posterior, publicar um termo versionado e manter pessoas, papéis e responsáveis vigentes com histórico auditável. Isso estabelece os dados e os controles de confiança dos quais os fluxos de inscrição e aprovação dependem.

## Stories

- Story 1.1: Acesso administrativo seguro
- Story 1.2: Seed idempotente de igrejas e equipes
- Story 1.3: Gestão administrativa de pessoas e papéis
- Story 1.4: Gestão temporal de vínculos de responsabilidade
- Story 1.5: Publicação e versionamento do primeiro termo

## Requirements & Constraints

- A administração abrange usuários, pastores, coordenador, igrejas, equipes, vínculos vigentes e históricos, termos, configurações, permissões e relatórios autorizados. Pessoas, perfis e vínculos são informações distintas.
- Somente pessoas autenticadas e atualmente autorizadas podem ver superfícies ou dados administrativos. Trocar o contexto de papel não amplia autoridade; a autorização deve refletir imediatamente concessões e revogações.
- Igrejas e equipes são dados administráveis no Firestore, nunca enums, constantes ou listas hardcoded no Flutter. O seed inicial deve criar os registros previstos em base vazia ou parcial, sem duplicar nem sobrescrever alterações administrativas posteriores, e produzir resultado auditável.
- Igreja usa ID opaco e código `String` único. Consultas autorizadas pesquisam por nome ou código, apresentam “Nome - Código” e ordenam alfabeticamente. Entidades com histórico são inativadas, não excluídas fisicamente.
- Um Pastor Local vigente por igreja e um responsável canônico vigente por equipe são obrigatórios. A substituição encerra o vínculo anterior e inicia o próximo sem sobreposição; pendências não decididas usam o vínculo vigente, enquanto decisões passadas mantêm seu responsável em snapshot.
- Publicar termo cria uma versão imutável com identificador, conteúdo canônico, hash e data/hora. Nova publicação preserva versões e aceites anteriores; versões publicadas não podem ser alteradas ou excluídas.
- Mudanças administrativas relevantes devem ser rastreáveis, preservadas e protegidas contra alteração/exclusão. Auditoria de papéis registra ator, alvo, antes/depois permitido, data/hora e correlação, sem expor PII em eventos, logs ou erros.
- A interface é Flutter Web/PWA mobile-first, responsiva e WCAG 2.2 AA: coluna única e alvos de toque de pelo menos 44 px no celular; navegação lateral no desktop; teclado, foco visível, leitor de tela e estados comunicados também por texto/ícone.

## Technical Decisions

- Flutter é cliente de apresentação; Cloud Functions autenticadas são a única fronteira para mutações críticas. Firestore e Storage iniciam em `deny` e não aceitam escrita direta de domínio pelo cliente.
- Cada comando crítico valida em transação autenticação, App Check, papel, vínculo vigente, escopo, entidade-alvo, estado e pré-condições. A autorização nunca depende só de papel nem de dado gravável pelo cliente.
- Custom claims efetivas só podem ser emitidas ou revogadas por Cloud Function com IAM restrito. A concessão/revogação não pode alterar claims, documentos de papel ou projeções se o solicitante não for administrador autorizado.
- Todo comando usa `commandId` único, verifica a versão esperada do agregado e persiste resultado idempotente. Na mesma operação lógica, grava estado, evidência/evento mínimo e recibo/outbox de auditoria com `correlationId`; materialização posterior deve ser idempotente.
- Use timestamps UTC do servidor, estados em `UPPER_SNAKE_CASE`, IDs Firestore opacos e contratos de erro que não revelem dados fora do escopo. Registros de auditoria são append-only e separados das projeções operacionais.
- Vínculos usam vigência semiaberta em UTC e são criados, encerrados e substituídos transacionalmente sobre o documento canônico da igreja/equipe. Nunca congele um `pastorId` na pendência para decidir autoridade futura.
- O termo publicado e seu conteúdo/snapshot são versionados e imutáveis. Leituras administrativas usam apenas projeções mínimas autorizadas; dados pessoais do coordenador permanecem restritos às funções e leitores com escopo permitido.
- Projetos Firebase são isolados por ambiente; a Emulator Suite é obrigatória para testar Rules, Functions e transações. Contas de serviço seguem menor privilégio e alterações de regras/IAM são monitoradas.

## UX & Interaction Patterns

- Administração é uma superfície visível apenas pela navegação do administrador e inclui igrejas, equipes, termos, usuários e vínculos vigentes/históricos. No desktop usa menu lateral; no celular, menu compacto; o papel ativo é visível.
- Ações administrativas críticas seguem revisar alvo e consequência, informar justificativa quando aplicável, confirmar, aguardar o backend e apresentar o evento registrado. Não empilhar modais.
- A substituição de responsável mostra responsável atual, data efetiva e pendências que serão redirecionadas; a linha do tempo somente leitura mostra ator, papel/vínculo em snapshot, ação, data/hora e justificativa.
- Quando não houver permissão, ocultar a ação e explicar acessivelmente que o vínculo vigente ou estado não permite atuar. Em conflito ou atualização, recarregar o detalhe e não repetir a ação cegamente.

## Cross-Story Dependencies

- Story 1.1 estabelece autenticação, autorização e guardas de escrita que todas as demais stories administrativas exigem.
- Stories 1.2 e 1.3 fornecem igrejas, equipes, pessoas e papéis necessários para criar os vínculos temporais da Story 1.4.
- Story 1.5 depende do acesso administrativo seguro e disponibiliza o termo vigente para a inscrição e o aceite do Epic 2.
- Igrejas, equipes e vínculos vigentes deste épico alimentam a seleção e o roteamento de aprovações dos Epics 2 e 3.

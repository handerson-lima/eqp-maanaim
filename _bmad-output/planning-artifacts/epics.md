---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md
  - architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
  - ux-designs/ux-eqp_maanaim-2026-09-28/DESIGN.md
  - ux-designs/ux-eqp_maanaim-2026-09-28/EXPERIENCE.md
  - ../specs/spec-gestao-voluntarios-maanaim/SPEC.md
---

# eqp_maanaim - Epic Breakdown

## Overview

Decomposição do contrato consolidado para o Sistema de Gestão de Voluntários do Maanaim. PRD, UX, SPEC e Architecture Spine são fontes vinculantes; os ADs do spine orientam toda story.

## Requirements Inventory

### Functional Requirements

FR1: Usuário pode criar conta e autenticar-se individualmente.
FR2: Voluntário pode criar e atualizar ficha permanente vinculada à sua igreja.
FR3: Voluntário pode selecionar uma ou mais equipes e visualizar situação independente por participação.
FR4: Voluntário pode ler e aceitar eletronicamente a versão vigente do termo; o aceite preserva usuário, versão, ficha e data/hora.
FR5: Voluntário pode enviar ficha somente quando dados, equipes e termo forem válidos.
FR6: Sistema localiza o Pastor Local vigente da igreja e direciona a pendência de aprovação.
FR7: Pastor Local autorizado pode aprovar ou rejeitar, com justificativa e aceite autenticado quando aplicável.
FR8: Após aprovação local, sistema libera simultaneamente cada participação ao responsável vigente da respectiva equipe.
FR9: Pastor de Equipe autorizado pode aprovar ou rejeitar somente participações de equipes sob sua responsabilidade.
FR10: Rejeição de uma equipe não bloqueia a continuidade das demais equipes aprovadas.
FR11: Coordenador pode confirmar consulta à reunião de pastores, aprovar/rejeitar e registrar aceite autenticado.
FR12: Sistema ativa somente participações elegíveis e mantém estados de ficha, participação e ciclo consistentes.
FR13: Voluntário pode acompanhar pendências, aprovações, vigência e histórico da ficha e de cada participação.
FR14: Voluntário ativo pode solicitar equipe adicional sem recriar ficha e sem afetar participações ativas.
FR15: Atores autorizados podem cancelar participação ou voluntariado sem excluir histórico.
FR16: Voluntário pode solicitar reativação; reativação preserva histórico e percorre ciclo novo conforme a máquina de estados.
FR17: Sistema controla vigência de um ano a partir da aprovação final do Coordenador e sinaliza proximidade do vencimento.
FR18: Voluntário pode manifestar, por equipe, se deseja continuar no ciclo anual seguinte.
FR19: Sistema cria renovação independente por participação/ano e repete a cadeia de aprovação sem sobrescrever ciclos anteriores.
FR20: Administrador pode gerir igrejas, equipes, usuários, papéis, termos e configurações administráveis.
FR21: Administrador pode criar, encerrar e substituir vínculos Pastor–Igreja e Pastor–Equipe, preservando histórico e redirecionando pendências não decididas.
FR22: Sistema garante um único Pastor Local vigente por igreja e permite um pastor em múltiplas igrejas/equipes.
FR23: Sistema versiona termos; publicação de nova versão identifica afetados e preserva todos os aceites anteriores.
FR24: Sistema registra evidências e auditoria para toda mutação relevante, incluindo decisões, vínculos, ciclos, termos e documentos.
FR25: Usuários autorizados podem gerar PDF da ficha a partir de evidências persistidas.
FR26: Perfis autorizados podem consultar dashboards e relatórios filtráveis por igreja, equipe, estado, período, pastor, voluntário e ano.
FR27: Igrejas e equipes iniciais são carregadas como seed administrável, com busca por nome/código e sem listas hardcoded.
FR28: Quando a ficha tiver decisão negativa, o voluntário recebe a mensagem “Procure o Pastor da igreja local para mais informações”, sem exibir a palavra “rejeitado”; administradores e pastores preservam a visualização interna completa do fluxo.
FR29: No primeiro preenchimento da ficha após criar login, voluntário deve informar obrigatoriamente Nome Completo, Profissão e CPF para uso no termo aprovado.
FR30: Ao final da aprovação, sistema gera um PDF por equipe aprovada seguindo a estrutura do termo fornecido, com preenchimento automático dos dados do voluntário e do Coordenador do Maanaim.

### NonFunctional Requirements

NFR1: Aplicação deve operar como Flutter Web/PWA em desktop, tablet e smartphone.
NFR2: Operações críticas devem ser autenticadas, validar App Check e ser executadas exclusivamente por Cloud Functions.
NFR3: Autorização deve combinar papel não autoatribuível, vínculo vigente, escopo e estado, usando tempo do servidor.
NFR4: Firestore e Storage devem negar acesso por padrão; regras e testes Emulator cobrem acessos positivos e negativos.
NFR5: Transições, decisões e comandos devem ser idempotentes, concorrência-seguros e consistentes em transação.
NFR6: Evidências, termos e auditoria devem ser append-only/versionados; cada comando crítico deve ter correlação e outbox transacional.
NFR7: Dados pessoais devem ser minimizados; ficha, auditoria, PDF e backup têm retenção de 5 anos, salvo obrigação legal superior.
NFR8: PDFs devem permanecer em bucket privado, com autorização na emissão/download, URL curta revogável e registro de acesso.
NFR9: UI deve atender WCAG 2.2 AA, navegação por teclado, leitor de tela, foco visível e alvos de toque de pelo menos 44 px.
NFR10: Cor não pode ser o único sinal de estado; datas devem respeitar apresentação local e eventos devem registrar fuso configurado.
NFR11: Consultas Firestore devem usar projeções de escopo, paginação, índices versionados e filtros obrigatórios.
NFR12: Ambientes Firebase de desenvolvimento, homologação e produção devem ser isolados; Emulator Suite é obrigatório para testes de Rules, Functions e transições.

### Additional Requirements

- AD-1: Cloud Functions são a fronteira exclusiva de mutações críticas; Flutter não autoriza transições.
- AD-2/AD-3: vínculo de igreja/equipe é temporal, transacional e capturado em snapshot; um Pastor Local vigente por igreja.
- AD-4/AD-5/AD-11: ficha, participação e ciclo são agregados distintos; a máquina de estados e sua redução são centralizadas e testadas.
- AD-6/AD-7: decisões, assinaturas e termos são evidências imutáveis e versionadas; vigência inicia na aprovação final do Coordenador.
- AD-8/AD-10: `commandId`, recibo e outbox garantem execução idempotente, auditoria correlacionada e notificação apenas pós-compromisso.
- AD-9/AD-12: RBAC é separado de identidade e vínculo; PII tem schema mínimo, relatórios/auditoria são mediados quando Rules não provam escopo e IAM segue menor privilégio.
- Firestore deve materializar projeções de fila/dashboard com `igrejaId`, `equipeId`, `estado`, `ano` e `proximaAcao`.
- Estrutura de domínio inclui usuários, voluntários, fichas, participações, ciclos, evidências, termos/versões/aceites, vínculos e eventos.
- FCM é outbox idempotente, sem PII em payload e com reautorização no deep link.
- PDF é projetado de evidências reais; não pode usar assinatura apenas apresentada pelo cliente.
- Seed de igrejas/equipes é dados administráveis no Firestore, usando código de igreja como String e unicidade de código.

### UX Design Requirements

UX-DR1: Implementar tokens Material 3 e escala 4 px; aplicar estado textual+ícone e tokens de cor/raio definidos em `DESIGN.md`.
UX-DR2: Implementar layout responsivo: coluna única no celular, navegação lateral no desktop e tabelas convertidas em cartões no celular.
UX-DR3: Implementar início com próximas ações, vigência e alertas no contexto do papel ativo sem ampliar permissões.
UX-DR4: Implementar superfícies de ficha, participações, fila de aprovação, detalhe, renovação, administração e auditoria/relatórios.
UX-DR5: Implementar cartão de participação com equipe, ciclo, estado e próxima ação independentes.
UX-DR6: Implementar seletor de equipes múltiplo, termo versionado, linha de pendência e linha do tempo auditável somente leitura.
UX-DR7: Implementar confirmação de ação crítica com alvo, consequência, justificativa aplicável e retorno do evento registrado.
UX-DR8: Exibir estados de rascunho, análise por equipe, aguardando coordenador, ativa, renovação, expirada, sem permissão e conflito/atualização.
UX-DR9: Exibir erro de autorização/estado sem repetir cegamente comando e recarregar o detalhe quando houver conflito.
UX-DR10: Preservar filtros de igreja/equipe/ciclo e deep links autorizados para detalhes.
UX-DR11: Implementar renovação por equipe com escolha explícita de continuar/não continuar e desfechos separados.
UX-DR12: Implementar administração de troca de responsável com vigência, pendências transferidas e linha do tempo histórica.
UX-DR13: Garantir WCAG 2.2 AA, teclado, leitor de tela, ordem de foco, alvos de toque e estados não dependentes de cor.
UX-DR14: Usar linguagem direta que informa responsável, bloqueio, consequência e registro no histórico.
UX-DR15: Notificações devem levar ao detalhe e nunca executar decisão.
UX-DR16: Para decisão negativa da ficha, voluntário vê somente orientação neutra; responsáveis autorizados veem estado, justificativa e histórico completos.

### FR Coverage Map

FR1: Epic 1 — acesso seguro para operação administrativa.
FR2: Epic 2 — ficha permanente do voluntário.
FR3: Epic 2 — seleção e visualização de participações independentes.
FR4: Epic 2 — aceite eletrônico do termo vigente.
FR5: Epic 2 — envio validado da solicitação.
FR6: Epic 3 — roteamento ao Pastor Local vigente.
FR7: Epic 3 — decisão local autenticada.
FR8: Epic 3 — liberação paralela por equipe.
FR9: Epic 3 — decisão contextual do responsável de equipe.
FR10: Epic 3 — continuidade após rejeição parcial.
FR11: Epic 3 — conclusão autenticada pelo Coordenador.
FR12: Epic 3 — ativação e redução consistente de estados.
FR13: Epic 4 — acompanhamento de ficha e participação.
FR14: Epic 4 — solicitação posterior de equipe.
FR15: Epic 4 — cancelamento rastreável.
FR16: Epic 4 — solicitação e aprovação de reativação.
FR17: Epic 5 — vigência anual e alerta de vencimento.
FR18: Epic 5 — manifestação seletiva por equipe.
FR19: Epic 5 — ciclo anual novo e independente.
FR20: Epic 1 — administração de cadastros, papéis e termos.
FR21: Epic 1 — gestão temporal de vínculos.
FR22: Epic 1 — unicidade de Pastor Local e responsabilidade de equipe.
FR23: Epic 1 — versionamento e publicação de termos.
FR24: Epic 6 — evidência e auditoria correlacionadas.
FR25: Epic 6 — PDF privado derivado de evidências.
FR26: Epic 6 — dashboards e relatórios autorizados.
FR27: Epic 1 — seed administrável de igrejas e equipes.
FR28: Epic 3 — comunicação de decisão negativa por público.
FR29: Epic 2 — dados obrigatórios do voluntário para o termo.
FR30: Epic 6 — PDF individual por equipe com estrutura de assinaturas do termo.

## Epic List

### Epic 1: Operação segura e configuração inicial do Maanaim

O administrador consegue preparar uma operação real: acessar o sistema, carregar seed inicial idempotente, publicar o primeiro termo e administrar igrejas, equipes, papéis e vínculos vigentes/históricos.

**FRs covered:** FR1, FR20, FR21, FR22, FR23, FR27

**Notas:** seed não sobrescreve dados administrados; cada equipe possui um responsável canônico vigente; aplicar AD-1, AD-2, AD-3, AD-8, AD-9 e AD-12 desde a primeira story.

### Epic 2: Inscrição digital do voluntário

O voluntário consegue criar sua ficha permanente, escolher equipes, aceitar o termo publicado e enviar uma solicitação rastreável, acompanhando as participações criadas.

**FRs covered:** FR2, FR3, FR4, FR5

**Notas:** aplicar UX-DR2 a UX-DR8 e AD-4, AD-6 e AD-7; a interface deve mostrar próxima ação e estado por equipe desde o envio.

### Epic 3: Aprovação e ativação por equipe

Pastor Local, responsável de equipe e Coordenador conseguem conduzir uma solicitação até a ativação, com decisões independentes, vínculo vigente, reunião confirmada e aceite autenticado.

**FRs covered:** FR6, FR7, FR8, FR9, FR10, FR11, FR12

**Notas:** aplicar AD-2, AD-3, AD-5, AD-6, AD-8, AD-10 e AD-11; uma rejeição parcial preserva o avanço das participações aprovadas.

### Epic 4: Acompanhamento e gestão da participação

Voluntário e responsáveis conseguem acompanhar ciclos, adicionar equipe, cancelar participação ou voluntariado e tratar reativação sem perder decisões anteriores.

**FRs covered:** FR13, FR14, FR15, FR16

**Notas:** aplicar UX-DR3 a UX-DR12 e a matriz de transição do AD-11; operações críticas mostram consequência, justificativa e evento resultante.

### Epic 5: Renovação anual seletiva

Voluntário decide, por equipe, se deseja continuar e acompanha um novo ciclo anual de aprovação com vigência de um ano contada da aprovação final do Coordenador.

**FRs covered:** FR17, FR18, FR19

**Notas:** aplicar AD-4, AD-5, AD-7 e AD-11; há no máximo um ciclo não terminal por participação/ano e a não renovação encerra apenas a participação correspondente.

### Epic 6: Evidência, documentos e visão operacional

Usuários autorizados conseguem consultar auditoria, dashboards, relatórios e PDFs privados, todos derivados de evidências correlacionadas e respeitando escopo e retenção.

**FRs covered:** FR24, FR25, FR26

**Notas:** aplicar AD-6, AD-8, AD-9, AD-10 e AD-12; PDF e exportações são autorizados, auditados e não expõem PII indevidamente.

## Epic 1: Operação segura e configuração inicial do Maanaim

Administrador prepara uma operação real, com acesso seguro, seed idempotente, primeiro termo publicado e responsáveis vigentes.

### Story 1.1: Acesso administrativo seguro

Como administrador,
quero autenticar-me e acessar somente as funções administrativas autorizadas,
para preparar a operação sem que usuários comuns obtenham privilégios indevidos.

**Acceptance Criteria:**

**Given** uma pessoa sem sessão autenticada
**When** ela tenta abrir uma superfície ou comando administrativo
**Then** o acesso é negado e nenhum dado administrativo é exposto.

**Given** um administrador autenticado com papel emitido pelo backend
**When** abre a administração
**Then** visualiza as superfícies administrativas permitidas
**And** o cliente não consegue criar, alterar ou conceder a si próprio um papel administrativo.

**Given** uma operação administrativa crítica
**When** é solicitada pelo cliente
**Then** Cloud Function valida autenticação e App Check antes de executar
**And** Firestore/Storage permanecem `deny by default` para escrita direta de domínio.

**Given** o papel administrativo é concedido ou revogado
**When** a operação é concluída
**Then** a mudança é auditável
**And** novas requisições usam a autorização atualizada.

### Story 1.2: Seed idempotente de igrejas e equipes

Como administrador,
quero carregar e consultar as igrejas e equipes iniciais como dados administráveis,
para iniciar a operação com a estrutura real do Maanaim sem dependência de listas hardcoded.

**Acceptance Criteria:**

**Given** uma base vazia ou parcialmente configurada
**When** o seed inicial é executado
**Then** cria as igrejas, códigos, equipes e dados iniciais previstos
**And** usa registros Firestore administráveis, não enums ou constantes no Flutter.

**Given** o seed já foi executado e existem alterações administrativas posteriores
**When** o seed é reexecutado
**Then** não duplica registros nem sobrescreve nomes, estados, vínculos ou configurações já administradas
**And** registra resultado idempotente e auditável.

**Given** uma igreja cadastrada
**When** administrador ou fluxo autorizado a pesquisa
**Then** pode localizá-la por nome ou código String
**And** a apresentação segue “Nome - Código”, ordenada alfabeticamente.

**Given** uma igreja ou equipe com histórico
**When** deixa de estar disponível operacionalmente
**Then** pode ser inativada sem exclusão física
**And** seus registros históricos permanecem consultáveis conforme autorização.

### Story 1.3: Gestão administrativa de pessoas e papéis

Como administrador,
quero gerir usuários, pastores, coordenadores e seus papéis de sistema,
para atribuir responsabilidades sem permitir que alguém amplie o próprio acesso.

**Acceptance Criteria:**

**Given** um administrador autorizado
**When** cadastra ou atualiza uma pessoa administrativa ou pastoral
**Then** o sistema mantém identidade, perfil e vínculo como informações separadas
**And** dados pessoais são armazenados apenas nos recursos permitidos.

**Given** uma pessoa designada como Coordenador do Maanaim
**When** administrador mantém seu cadastro autorizado
**Then** registra Nome Completo e CPF para preenchimento automático dos termos aprovados
**And** esses dados só são disponibilizados à função de PDF e a leitores com escopo permitido.

**Given** uma concessão ou revogação de papel
**When** é confirmada
**Then** somente uma Cloud Function com privilégio IAM apropriado pode atualizar o papel efetivo
**And** a operação registra ator, alvo, antes/depois permitido, data/hora e `correlationId` na auditoria.

**Given** um usuário sem papel administrativo
**When** tenta invocar uma concessão, revogação ou alteração de papel por cliente ou endpoint
**Then** a solicitação é recusada
**And** não altera claims, documentos de papel ou projeções administrativas.

**Given** um usuário com múltiplos papéis válidos
**When** acessa o sistema
**Then** pode visualizar o contexto ativo sem obter autoridade fora dos vínculos exigidos por cada ação.

### Story 1.4: Gestão temporal de vínculos de responsabilidade

Como administrador,
quero atribuir, encerrar e substituir responsáveis por igrejas e equipes com vigência definida,
para que pendências sejam direcionadas ao responsável atual sem reescrever decisões passadas.

**Acceptance Criteria:**

**Given** uma igreja sem Pastor Local vigente
**When** administrador atribui um pastor com início de vigência válido
**Then** o sistema cria o vínculo temporal auditável
**And** a igreja passa a ter exatamente um Pastor Local vigente.

**Given** uma igreja com Pastor Local vigente
**When** administrador confirma uma substituição com data efetiva
**Then** uma transação encerra o vínculo anterior e cria o novo sem sobreposição temporal
**And** pendências não decididas passam a ser encontradas pelo novo vínculo vigente.

**Given** uma equipe
**When** administrador atribui ou substitui seu responsável
**Then** o sistema mantém exatamente um responsável canônico vigente por vez
**And** decisões já tomadas preservam o responsável e vínculo em snapshot.

**Given** uma tentativa de criar vínculo sobreposto, retroativo inválido ou para entidade inativa
**When** a operação é submetida
**Then** a Cloud Function a rejeita integralmente
**And** não altera vínculos, filas ou auditoria de domínio.

### Story 1.5: Publicação e versionamento do primeiro termo

Como administrador,
quero publicar o primeiro termo e versões futuras como conteúdos imutáveis,
para que cada aceite de voluntário possa comprovar exatamente o documento aceito.

**Acceptance Criteria:**

**Given** um administrador autorizado e um termo ainda não publicado
**When** publica a primeira versão
**Then** o sistema cria uma versão imutável com identificador, conteúdo canônico, hash e data/hora
**And** a versão passa a ser o termo vigente para novas solicitações.

**Given** já existe um termo vigente
**When** administrador publica uma nova versão
**Then** a versão anterior permanece preservada e consultável
**And** o sistema identifica os voluntários ativos impactados sem alterar aceites anteriores.

**Given** uma tentativa de editar ou excluir versão já publicada
**When** é submetida por cliente ou fluxo administrativo comum
**Then** é recusada
**And** a alteração exige a publicação de uma nova versão.

**Given** a publicação de uma versão
**When** é concluída
**Then** gera evidência/auditoria correlacionada
**And** não expõe conteúdo ou dados pessoais fora do escopo autorizado.

## Epic 2: Inscrição digital do voluntário

Voluntário cria e mantém uma ficha permanente, escolhe equipes, aceita o termo vigente e envia uma solicitação rastreável.

### Story 2.1: Criar e manter ficha permanente

Como voluntário autenticado,
quero criar e atualizar minha ficha vinculada à minha igreja,
para manter meus dados disponíveis durante todos os ciclos de voluntariado.

**Acceptance Criteria:**

**Given** um voluntário autenticado sem ficha
**When** inicia o cadastro
**Then** o sistema cria um rascunho privado de ficha permanente com identificador estável
**And** somente o próprio voluntário pode ler ou alterar os campos de rascunho permitidos.

**Given** o primeiro preenchimento da ficha após criação do login
**When** o voluntário tenta avançar para seleção de equipes ou aceite do termo
**Then** deve informar Nome Completo, Profissão e CPF
**And** esses campos ficam disponíveis para preenchimento automático do termo após aprovação.

**Given** uma ficha em rascunho
**When** o voluntário salva dados válidos ou parciais
**Then** o sistema preserva o rascunho sem criar participação, aprovação ou ciclo
**And** apresenta campos obrigatórios pendentes antes do envio.

**Given** uma ficha já enviada ou com histórico
**When** o voluntário atualiza dado cadastral permitido
**Then** a alteração preserva decisões anteriores
**And** registra evento com ator, campos permitidos antes/depois e data/hora.

**Given** um usuário comum autenticado
**When** consulta fichas no sistema
**Then** visualiza exclusivamente a própria ficha
**And** acesso de responsáveis ocorre apenas por projeções autorizadas e vínculo contextual, nunca por listagem ampla de fichas.

**Given** um usuário tenta ler ou atualizar ficha de outro voluntário
**When** a requisição é processada
**Then** ela é recusada pelo controle de escopo
**And** nenhum dado pessoal é retornado.

### Story 2.2: Selecionar equipes e visualizar participações de rascunho

Como voluntário com ficha em rascunho,
quero pesquisar e selecionar uma ou mais equipes,
para indicar onde desejo servir e acompanhar cada solicitação separadamente.

**Acceptance Criteria:**

**Given** uma ficha em rascunho e equipes ativas cadastradas
**When** o voluntário pesquisa ou navega pelas equipes
**Then** visualiza somente equipes administráveis ativas
**And** pode selecionar múltiplas equipes sem hardcoding no cliente.

**Given** o voluntário seleciona uma equipe
**When** confirma a seleção no rascunho
**Then** o sistema cria ou atualiza uma participação de rascunho vinculada à ficha e à equipe
**And** exibe equipe, estado, ciclo e próxima ação de forma independente.

**Given** o voluntário remove uma equipe antes do envio
**When** salva o rascunho
**Then** a participação de rascunho é removida ou marcada conforme a política de rascunho
**And** nenhuma aprovação, auditoria de decisão ou ciclo ativo é afetado.

**Given** uma equipe inativa, inexistente ou já selecionada
**When** o voluntário tenta adicioná-la
**Then** a operação é recusada ou bloqueada com mensagem clara
**And** o estado das demais participações não é alterado.

### Story 2.3: Ler e aceitar o termo vigente

Como voluntário com ficha e equipes selecionadas,
quero ler e aceitar explicitamente o termo vigente,
para registrar meu consentimento antes de enviar a solicitação.

**Acceptance Criteria:**

**Given** uma ficha em rascunho com ao menos uma equipe
**When** o voluntário abre o termo
**Then** o sistema apresenta o conteúdo canônico, versão e identificação do termo vigente
**And** não permite aceite sem a declaração explícita de leitura e concordância.

**Given** o voluntário confirma o aceite
**When** a operação é processada
**Then** o backend cria evidência imutável com UID, ficha, versão, hash, data/hora do servidor e `commandId`
**And** o comprovante aparece no histórico da ficha.

**Given** uma versão nova do termo foi publicada antes do envio
**When** o voluntário tenta enviar usando um aceite anterior
**Then** o sistema exige leitura e aceite da versão vigente
**And** preserva o aceite anterior sem sobrescrevê-lo.

**Given** um usuário tenta fabricar ou alterar um aceite pelo cliente
**When** a requisição é processada
**Then** ela é recusada
**And** somente a Cloud Function autorizada cria a evidência de aceite.

### Story 2.4: Enviar ficha e iniciar aprovações

Como voluntário com ficha completa, equipes selecionadas e termo aceito,
quero enviar minha solicitação,
para iniciar a avaliação pelo Pastor Local vigente.

**Acceptance Criteria:**

**Given** ficha em rascunho com dados obrigatórios válidos, ao menos uma participação e aceite da versão vigente
**When** o voluntário envia a ficha
**Then** Cloud Function valida identidade, App Check, estado, versão esperada e pré-condições em transação
**And** altera a ficha para `AGUARDANDO_PASTOR_LOCAL`.

**Given** o envio é concluído
**When** a transação persiste o resultado
**Then** cada participação entra no estado inicial de aprovação
**And** são gravados recibo idempotente, evento da ficha e entrada de auditoria/outbox correlacionados.

**Given** a igreja da ficha possui Pastor Local vigente
**When** a solicitação é enviada
**Then** a projeção de fila aponta a pendência para o escopo dessa igreja
**And** a tela do voluntário mostra o próximo responsável e o estado por participação.

**Given** dados inválidos, termo não vigente, equipe inativa ou reenvio com `commandId` já concluído
**When** o comando é processado
**Then** o backend retorna erro de pré-condição ou o resultado idempotente original
**And** não cria aprovações ou eventos duplicados.

## Epic 3: Aprovação e ativação por equipe

Pastor Local, responsável de equipe e Coordenador conduzem uma solicitação até a ativação, com decisões independentes, vínculos vigentes, evidência e comunicação adequada a cada público.

### Story 3.1: Fila e decisão do Pastor Local

Como Pastor Local,
quero visualizar e decidir somente as fichas pendentes das igrejas sob minha responsabilidade vigente,
para aprovar ou encaminhar corretamente cada solicitação inicial.

**Acceptance Criteria:**

**Given** uma ficha enviada para uma igreja com Pastor Local vigente
**When** o pastor abre sua fila
**Then** visualiza somente pendências cujo `igrejaId` pertence a vínculo vigente dele
**And** a fila usa paginação, filtro de escopo e próxima ação explícita.

**Given** uma ficha em `AGUARDANDO_PASTOR_LOCAL`
**When** o Pastor Local autorizado aprova
**Then** Cloud Function valida Auth, App Check, vínculo vigente, estado e versão esperada em transação
**And** grava decisão/assinatura autenticada com ator, papel, vínculo em snapshot, data/hora e `commandId`.

**Given** o Pastor Local autorizado toma decisão negativa
**When** confirma a ação com justificativa aplicável
**Then** o backend encerra o fluxo da ficha conforme máquina de estados, preserva evidências e auditoria
**And** a visualização interna de administradores e pastores exibe estado e justificativa completos.

**Given** um voluntário cuja ficha recebeu decisão negativa
**When** abre a própria ficha ou recebe notificação
**Then** vê exatamente “Procure o Pastor da igreja local para mais informações”
**And** não vê a palavra “rejeitado”, o estado interno de recusa ou a justificativa.

**Given** o vínculo do pastor expirou, foi substituído ou outra decisão venceu a ação
**When** ele tenta decidir
**Then** o comando é recusado e o detalhe é recarregado com o estado atual
**And** nenhuma evidência duplicada é criada.

### Story 3.2: Aprovações paralelas por responsável de equipe

Como responsável de equipe,
quero analisar apenas as participações pendentes das equipes sob minha responsabilidade vigente,
para decidir independentemente sobre cada voluntário.

**Acceptance Criteria:**

**Given** uma ficha aprovada pelo Pastor Local com múltiplas participações
**When** o sistema libera a etapa de equipes
**Then** cria uma pendência independente por participação
**And** disponibiliza todas simultaneamente aos respectivos responsáveis canônicos vigentes.

**Given** um responsável de equipe abre sua fila
**When** consulta as pendências
**Then** visualiza somente participações da(s) equipe(s) sob vínculo vigente
**And** não pode inferir ou acessar filas de outras equipes.

**Given** uma participação em `AGUARDANDO_APROVACAO`
**When** o responsável autorizado aprova ou toma decisão negativa
**Then** a Cloud Function valida vínculo, escopo, estado e versão em transação
**And** grava evidência/assinatura e auditoria idempotentes para aquela participação.

**Given** uma ou mais equipes aprovadas e outra com decisão negativa
**When** todas as pendências elegíveis forem resolvidas
**Then** somente as participações aprovadas seguem para a fila do Coordenador
**And** a decisão negativa não altera estado, ciclo ou elegibilidade das demais.

**Given** uma tentativa repetida, vínculo substituído ou participação já decidida
**When** o comando é submetido
**Then** retorna o resultado original idempotente ou erro de pré-condição
**And** não gera decisões ou assinaturas duplicadas.

### Story 3.3: Conclusão pelo Coordenador e ativação

Como Coordenador do Maanaim,
quero concluir solicitações com participações elegíveis após confirmar a reunião de pastores,
para ativar apenas os vínculos aprovados com evidência verificável.

**Acceptance Criteria:**

**Given** uma ficha com aprovação local e ao menos uma participação aprovada pela equipe
**When** o Coordenador abre a fila final
**Then** visualiza voluntário, igreja, decisão local, participações, responsáveis, decisões e datas
**And** não pode concluir item fora do estado `AGUARDANDO_COORDENADOR`.

**Given** uma solicitação elegível
**When** o Coordenador confirma a consulta na reunião, registra observação aplicável e aprova
**Then** a Cloud Function grava confirmação e aceite autenticado do Coordenador
**And** ativa somente as participações elegíveis e recalcula a ficha conforme AD-11.

**Given** a ativação é concluída
**When** o ciclo inicial é persistido
**Then** sua vigência é de um ano contado da aprovação final do Coordenador
**And** a ficha e cada participação mostram estado, início, vencimento e próxima ação.

**Given** o Coordenador toma decisão negativa ou o estado mudou antes da confirmação
**When** submete o comando
**Then** o backend aplica a transição permitida ou recusa por pré-condição
**And** preserva evidência, auditoria e resultado idempotente sem ativação parcial.

### Story 3.4: Comunicação de decisões e acompanhamento por público

Como voluntário, pastor ou administrador autorizado,
quero receber informações da solicitação adequadas ao meu papel,
para acompanhar o processo sem expor justificativas ou dados fora do meu escopo.

**Acceptance Criteria:**

**Given** uma ficha ou participação muda de estado
**When** o sistema atualiza projeções e envia notificação elegível
**Then** o destinatário recebe apenas estado, próxima ação e deep link autorizável
**And** a notificação não contém PII, justificativa ou decisão acionável.

**Given** uma ficha com decisão negativa
**When** o voluntário abre a própria ficha ou notificação
**Then** vê exatamente “Procure o Pastor da igreja local para mais informações”
**And** não vê “rejeitado”, justificativa, estado interno ou dados de quem decidiu.

**Given** a mesma ficha com decisão negativa
**When** Pastor Local, responsável de equipe, Coordenador ou administrador autorizado a consulta
**Then** vê o estado interno, justificativa, ator, vínculo em snapshot e linha do tempo
**And** não visualiza dados fora de seu escopo de igreja/equipe.

**Given** uma notificação antiga ou deep link aberto após troca/expiração de vínculo
**When** o destinatário acessa o detalhe
**Then** o acesso é reautorizado no momento da abertura
**And** o sistema bloqueia dados sem autorização atual.

## Epic 4: Acompanhamento e gestão da participação

Voluntário e responsáveis acompanham ciclos, incluem novas equipes, cancelam participações ou voluntariado e tratam reativação sem perder evidências anteriores.

### Story 4.1: Consultar ficha, participações e histórico autorizado

Como voluntário ou responsável autorizado,
quero consultar ficha, participações, ciclos e linha do tempo no escopo permitido,
para acompanhar situação, vigência e próximas ações sem expor dados indevidos.

**Acceptance Criteria:**

**Given** um voluntário autenticado
**When** abre sua ficha
**Then** visualiza exclusivamente a própria ficha, participações, ciclos, vigência, próxima ação e histórico permitido
**And** cada participação exibe equipe, estado e ciclo de forma independente.

**Given** um Pastor Local, responsável de equipe, Coordenador ou administrador autorizado
**When** abre uma ficha pela fila, relatório ou deep link
**Then** o backend revalida papel, vínculo vigente e escopo antes de retornar dados
**And** a visão inclui somente as informações necessárias ao papel e à entidade autorizada.

**Given** um evento na linha do tempo
**When** é exibido
**Then** mostra ator, papel/vínculo em snapshot, ação, data/hora e justificativa somente para quem pode consultá-la
**And** permanece somente leitura, sem editar ou excluir eventos.

**Given** não há participações, histórico filtrável ou o acesso foi removido
**When** a superfície carrega
**Then** apresenta estado vazio, orientação ou acesso negado apropriado
**And** não revela existência, identidade ou detalhes de registros fora do escopo.

### Story 4.2: Solicitar equipe adicional

Como voluntário com ficha ativa,
quero solicitar participação em uma nova equipe,
para ampliar meu voluntariado sem interromper as equipes em que já atuo.

**Acceptance Criteria:**

**Given** uma ficha ativa e uma equipe ativa ainda não vinculada ao voluntário
**When** ele solicita a nova equipe
**Then** o sistema cria participação e ciclo de aprovação independentes
**And** mantém inalteradas todas as participações já ativas.

**Given** a nova solicitação é criada
**When** a Cloud Function conclui a transação
**Then** valida identidade, estado da ficha, equipe ativa, inexistência de participação duplicada e `commandId`
**And** registra evento/auditoria correlacionados e direciona a solicitação ao fluxo de aprovação aplicável.

**Given** o voluntário consulta a ficha após solicitar nova equipe
**When** visualiza as participações
**Then** vê a nova equipe em aprovação e as demais no estado atual
**And** a tela indica a próxima ação por equipe.

**Given** a equipe está inativa, já possui participação não terminal ou a ficha não está apta
**When** o voluntário solicita inclusão
**Then** o backend recusa a operação com mensagem clara
**And** não modifica participações existentes.

### Story 4.3: Cancelar participação ou voluntariado

Como voluntário ou responsável autorizado,
quero cancelar uma participação específica ou todo o voluntariado com confirmação explícita,
para encerrar o vínculo necessário sem apagar o histórico.

**Acceptance Criteria:**

**Given** uma participação não terminal
**When** voluntário proprietário, Pastor Local vigente, responsável vigente da equipe ou Coordenador solicita cancelamento com motivo aplicável
**Then** Cloud Function valida ator, vínculo, escopo, estado e versão em transação
**And** altera somente a participação alvo para `CANCELADA`, criando evidência e auditoria.

**Given** uma ficha não terminal
**When** voluntário proprietário, Pastor Local vigente ou Coordenador confirma cancelamento total
**Then** o sistema cancela todas as participações não terminais e a ficha conforme AD-11
**And** mostra ao solicitante os itens afetados antes da confirmação.

**Given** o próprio voluntário solicita cancelamento
**When** a operação é concluída
**Then** ele vê confirmação normal com o alvo cancelado
**And** pode consultar o histórico permitido da ação.

**Given** Pastor Local, responsável de equipe ou Coordenador cancela participação ou voluntariado de outra pessoa
**When** o voluntário afetado abre a ficha ou recebe notificação
**Then** vê exatamente “Procure o Pastor da igreja local para mais informações”
**And** não vê estado interno, motivo, ator ou a palavra “rejeitado”.

**Given** uma ação de cancelamento concluída
**When** um responsável autorizado consulta a ficha
**Then** ciclos, decisões, assinaturas e justificativas anteriores permanecem somente leitura
**And** a linha do tempo registra ator, motivo, antes/depois e data/hora.

**Given** uma pessoa sem autoridade, uma participação terminal ou conflito de versão
**When** tenta cancelar
**Then** o comando é recusado ou retorna resultado idempotente original
**And** não altera entidades fora do alvo autorizado.

### Story 4.4: Solicitar e aprovar reativação

Como voluntário com ficha ou participação cancelada, inativa ou expirada,
quero solicitar reativação,
para voltar a servir mediante um novo ciclo de aprovação sem perder meu histórico.

**Acceptance Criteria:**

**Given** uma ficha ou participação em `CANCELADA`, `INATIVA` ou `EXPIRADA`
**When** o voluntário solicita reativação
**Then** o sistema cria solicitação rastreável sem reativar automaticamente a participação antiga
**And** preserva todos os ciclos, decisões e assinaturas anteriores como finais.

**Given** uma solicitação válida de reativação
**When** o fluxo autorizado a aprova
**Then** o sistema cria novo ciclo inicial para a participação escolhida
**And** repete a cadeia Pastor Local vigente → responsável vigente da equipe → Coordenador.

**Given** o voluntário ou responsável consulta a solicitação
**When** a reativação está em andamento
**Then** visualiza estado, próxima ação e histórico conforme seu escopo
**And** nenhuma participação antiga volta a `ATIVA` sem conclusão do novo ciclo.

**Given** a origem não permite reativação, já existe ciclo não terminal ou o comando é repetido
**When** a solicitação é submetida
**Then** o backend recusa por pré-condição ou retorna resultado idempotente
**And** não cria ciclos, evidências ou auditorias duplicados.

## Epic 5: Renovação anual seletiva

Cada participação é renovada de forma independente, com vigência de um ano a partir da aprovação final e sem sobrescrever ciclos anteriores.

### Story 5.1: Calcular vigência anual e alertas de renovação

Como voluntário ou responsável autorizado,
quero visualizar a vigência anual e os alertas de vencimento das participações no meu escopo,
para agir antes que o ciclo expire.

**Acceptance Criteria:**

**Given** uma participação ativada ou renovada pelo Coordenador
**When** o ciclo é concluído
**Then** o sistema define início na aprovação final e vencimento exatamente um ano depois
**And** persiste esses valores no ciclo sem recalcular ciclos históricos.

**Given** uma participação com vigência ativa
**When** a data de vencimento se aproxima conforme configuração operacional
**Then** projeções de voluntário, Pastor Local, responsável de equipe e Coordenador exibem alerta e próxima ação no escopo permitido
**And** o alerta não expõe PII ou detalhes fora do destinatário autorizado.

**Given** o vencimento é alcançado sem renovação concluída
**When** o job idempotente de expiração é executado
**Then** marca participação/ciclo como `EXPIRADA` e recalcula o estado da ficha conforme AD-11
**And** registra evento e auditoria correlacionados.

**Given** uma execução repetida ou uma alteração de configuração futura
**When** o sistema reprocessa alertas ou expiração
**Then** não duplica eventos, ciclos ou notificações
**And** não altera a vigência já persistida de ciclos anteriores.

### Story 5.2: Manifestar interesse de renovação por equipe

Como voluntário com participações próximas do vencimento,
quero informar individualmente se desejo continuar em cada equipe,
para renovar somente os vínculos em que pretendo permanecer.

**Acceptance Criteria:**

**Given** uma participação ativa dentro da janela de renovação configurada
**When** o voluntário abre a renovação
**Then** visualiza cada equipe, vigência, situação atual e escolha explícita “continuar” ou “não continuar”
**And** não pode decidir em nome de outro voluntário.

**Given** o voluntário escolhe continuar em uma equipe
**When** confirma a manifestação
**Then** Cloud Function cria ou retorna o único ciclo não terminal para `participacaoId + anoVigencia`
**And** registra manifestação, configuração aplicável e `commandId` sem sobrescrever o ciclo anterior.

**Given** o voluntário escolhe não continuar em uma equipe
**When** confirma a manifestação
**Then** o sistema registra a decisão e programa o encerramento da participação ao fim da vigência
**And** não altera as demais equipes ou ciclos.

**Given** a janela está fechada, a participação é terminal ou a manifestação é repetida em conflito
**When** o comando é processado
**Then** retorna erro de pré-condição ou resultado idempotente
**And** não cria ciclo anual duplicado.

### Story 5.3: Processar aprovação e conclusão do ciclo anual

Como Pastor Local, responsável de equipe ou Coordenador autorizado,
quero processar a renovação de uma participação pelo fluxo anual,
para concluir um novo ciclo sem modificar os anteriores.

**Acceptance Criteria:**

**Given** uma manifestação “continuar” com ciclo anual não terminal
**When** o Pastor Local vigente decide
**Then** o backend valida vínculo, escopo, estado e ano do ciclo
**And** registra evidência nova, mantendo a decisão inicial e renovações anteriores imutáveis.

**Given** aprovação local no ciclo anual
**When** o sistema libera a etapa de equipe
**Then** direciona a pendência ao responsável canônico vigente da equipe
**And** aplica aprovação/rejeição independente apenas à participação daquele ciclo.

**Given** participação anual aprovada pela equipe
**When** o Coordenador confirma reunião e aprova
**Then** conclui o ciclo anual, inicia nova vigência de um ano e mantém a participação ativa
**And** registra evidência, auditoria e atualização de projeção idempotentes.

**Given** decisão negativa, expiração ou conflito durante o ciclo anual
**When** o comando é processado
**Then** aplica somente transição permitida ao ciclo/participação correspondente
**And** não reabre, altera ou exclui ciclos anteriores.

### Story 5.4: Exibir dashboards de renovação por papel

Como voluntário ou responsável autorizado,
quero visualizar renovação, vencimentos e pendências no meu contexto,
para priorizar as ações necessárias antes da expiração.

**Acceptance Criteria:**

**Given** um voluntário autenticado
**When** abre o dashboard de renovação
**Then** visualiza somente suas participações, validade, manifestação pendente e situação da renovação por equipe
**And** pode navegar para o detalhe autorizado de cada participação.

**Given** um Pastor Local ou responsável de equipe com vínculos vigentes
**When** abre o dashboard
**Then** visualiza somente igrejas ou equipes sob seu escopo, com renovações pendentes, sem manifestação, próximas do vencimento e expiradas
**And** pode filtrar sem receber registros de outros escopos.

**Given** o Coordenador ou administrador autorizado
**When** abre a visão consolidada
**Then** visualiza métricas e filas globais permitidas com filtros por igreja, equipe, estado e ano
**And** consultas/exportações sensíveis registram auditoria e usam paginação.

**Given** dados desatualizados, filtros sem resultado ou acesso revogado
**When** o dashboard é carregado
**Then** exibe estado de carregamento, vazio ou acesso negado apropriado
**And** não infere existência de dados não autorizados.

## Epic 6: Evidência, documentos e visão operacional

Usuários autorizados consultam auditoria, dashboards, relatórios e PDFs privados, todos derivados de eventos correlacionados e respeitando escopo, privacidade e retenção.

### Story 6.1: Registrar e reconciliar evidência/auditoria imutável

Como operador autorizado,
quero que toda mutação crítica produza evidências e auditoria correlacionadas,
para comprovar o que ocorreu mesmo diante de retries ou falhas parciais.

**Acceptance Criteria:**

**Given** qualquer comando crítico de domínio
**When** sua transação é executada
**Then** cria recibo `commandId`, evento/evidência do agregado e entrada `auditOutbox` correlacionados
**And** a operação falha integralmente se esses registros obrigatórios não couberem no orçamento transacional.

**Given** uma entrada de outbox persistida
**When** o consumidor idempotente a processa
**Then** materializa uma única entrada de auditoria global e as projeções derivadas
**And** não altera o estado do domínio.

**Given** o processamento de auditoria falha ou fica incompleto
**When** a reconciliação é executada
**Then** identifica o recibo pendente, reprocessa de forma idempotente e gera alerta operacional
**And** a ação não é apresentada como totalmente concluída enquanto a correlação obrigatória não existir.

**Given** cliente, administrador comum ou processo sem privilégio tenta alterar ou excluir evidência/auditoria
**When** a solicitação é processada
**Then** Firestore Rules e IAM a recusam
**And** o acesso de leitura permanece filtrado por escopo e necessidade.

### Story 6.2: Consultar auditoria e relatórios autorizados

Como responsável ou administrador autorizado,
quero consultar auditoria e relatórios filtrados pelo meu escopo,
para acompanhar operação e tomar decisões sem acessar dados indevidos.

**Acceptance Criteria:**

**Given** um usuário autorizado abre auditoria ou relatório
**When** informa filtros por igreja, equipe, estado, período, pastor, voluntário ou ano
**Then** a função aplica filtros obrigatórios de escopo, ordenação estável e paginação limitada
**And** retorna somente campos permitidos ao papel.

**Given** um Pastor Local ou responsável de equipe
**When** consulta auditoria ou relatório
**Then** vê somente eventos e agregados das igrejas/equipes sob vínculo vigente ou histórico expressamente permitido
**And** não pode ampliar resultado por alteração de filtro, cursor ou collection-group query.

**Given** Coordenador ou administrador autorizado consulta visão global
**When** visualiza ou exporta informação sensível
**Then** a consulta/exportação é auditada com ator, filtro, data/hora e `correlationId`
**And** aplica mascaramento de PII conforme o papel.

**Given** filtros não retornam dados ou acesso não é autorizado
**When** a consulta é processada
**Then** retorna estado vazio ou acesso negado apropriado
**And** não revela a existência de entidades fora do escopo.

### Story 6.3: Gerar e entregar PDF privado da ficha

Como usuário autorizado,
quero gerar um PDF da ficha a partir das evidências persistidas,
para consultar ou compartilhar o documento sem depender de conteúdo apresentado pelo cliente.

**Acceptance Criteria:**

**Given** voluntário proprietário ou responsável autorizado solicita um PDF
**When** a Cloud Function revalida identidade, papel, vínculo, escopo e estado
**Then** projeta um PDF individual para cada equipe aprovada, exclusivamente de ficha, participação, termo, decisões e assinaturas persistidas
**And** não aceita texto de assinatura ou estado fornecido pelo cliente.

**Given** uma participação aprovada no ciclo concluído
**When** seu PDF é projetado
**Then** segue a estrutura do DOCX “Termo de Adesão de Voluntário”: identificação do voluntário, profissão, CPF, equipe, data, assinatura do voluntário, assinatura do Coordenador e testemunhas do Pastor Local e do Pastor responsável pela equipe
**And** preenche automaticamente Nome Completo, Profissão e CPF do voluntário, bem como nome e CPF do Coordenador do Maanaim, a partir dos registros autorizados.

**Given** o PDF é gerado
**When** é armazenado
**Then** fica no bucket privado sob caminho autorizado, com metadados mínimos e versão de evidências usada
**And** geração é registrada em auditoria correlacionada.

**Given** o usuário autorizado solicita download
**When** o acesso é concedido
**Then** recebe URL curta revogável ou fluxo equivalente após nova autorização
**And** o acesso ao documento é auditado.

**Given** usuário sem escopo, URL expirada/revogada ou tentativa de acessar objeto diretamente
**When** tenta abrir ou baixar o PDF
**Then** o acesso é negado
**And** o sistema não expõe metadados, conteúdo ou existência do documento.

### Story 6.4: Aplicar retenção, minimização e controles operacionais de dados

Como responsável pela operação,
quero aplicar retenção, minimização e controles de acesso aos dados do sistema,
para cumprir a política de cinco anos sem expor dados pessoais além do necessário.

**Acceptance Criteria:**

**Given** ficha, auditoria, PDF ou backup criado pelo sistema
**When** sua política de ciclo de vida é aplicada
**Then** recebe retenção de 5 anos, salvo obrigação legal superior
**And** a configuração não permite exclusão antecipada por fluxo comum de produto.

**Given** evento de domínio, auditoria, erro, notificação ou relatório
**When** é persistido ou enviado
**Then** contém somente IDs, ação, estado, timestamps, papel/vínculo em snapshot e metadados permitidos
**And** não copia ficha completa, endereço, documento, token ou conteúdo sensível desnecessário.

**Given** termina o prazo de retenção ou há solicitação de anonimização autorizada
**When** o processo operacional é executado
**Then** aplica regra aprovada de mascaramento/anonimização preservando correlação e evidência mínima exigida
**And** registra auditoria do procedimento.

**Given** alterações de IAM, Rules, conta de serviço, deleção ou falha de backup
**When** ocorrem em produção
**Then** Cloud Audit Logs e monitoramento registram e alertam o evento
**And** o acesso de serviços segue menor privilégio e ambientes permanecem isolados.

### Story 6.5: Acesso inclusivo e responsivo às superfícies do voluntariado

Como usuário do sistema,
quero usar todas as superfícies principais em celular, tablet ou desktop com recursos de acessibilidade,
para concluir meu fluxo independentemente do dispositivo ou da forma de interação.

**Acceptance Criteria:**

**Given** as superfícies de ficha, participações, fila, detalhe, renovação, administração e relatórios
**When** são exibidas em celular, tablet ou desktop
**Then** aplicam tokens Material 3, escala de espaçamento e estados textual+ícone definidos no DESIGN.md
**And** navegação lateral/tabelas adaptam-se para menu compacto/cartões conforme o viewport.

**Given** uma pessoa navega somente com teclado ou leitor de tela
**When** interage com ações, estados, filtros, formulários e confirmações críticas
**Then** encontra foco visível, ordem de foco lógica, nomes/estados anunciados e ações operáveis sem ponteiro
**And** controles de toque têm ao menos 44 px.

**Given** uma informação de aprovação, cancelamento, vigência ou erro
**When** é apresentada na interface
**Then** atende WCAG 2.2 AA e não depende apenas de cor
**And** mantém texto, ícone e orientação para a próxima ação.

### Story 6.6: Verificar segurança, índices e ambientes Firebase

Como equipe de operação,
quero validar Rules, Functions, transições, índices e ambientes antes de implantar,
para impedir vazamento de escopo, regressões de estado e consultas ineficientes.

**Acceptance Criteria:**

**Given** regras Firestore/Storage e Cloud Functions críticas
**When** a suíte do Firebase Emulator é executada
**Then** cobre caminhos positivos e negativos de proprietário, papel, vínculo expirado/trocado, escopo alheio, coleção-grupo e escrita direta
**And** falha se qualquer operação crítica puder ser executada fora da Function autorizada.

**Given** comandos de decisão, vínculo, renovação, expiração, cancelamento e reativação
**When** são testados com retry, `commandId` repetido e concorrência
**Then** comprovam idempotência, transição permitida e correlação de evidência/auditoria
**And** não produzem estado parcial ou duplicado.

**Given** consultas de filas, dashboards e relatórios
**When** são versionadas para implantação
**Then** possuem índices compostos, ordenação, cursor e limites compatíveis com seus filtros obrigatórios
**And** os testes recusam consultas que removam escopo para contornar índice.

**Given** desenvolvimento, homologação e produção
**When** a configuração é validada
**Then** usa projetos Firebase isolados, contas de serviço de menor privilégio e configuração sem segredos no cliente
**And** o pipeline não permite promoção sem os testes de Emulator aprovados.


## Adoção corretiva — Épicos 7 e 8 (08/10/2026)

O épico 7 já está implementado e registrado no [sprint-status](../implementation-artifacts/sprint-status.yaml), com histórias 7.1–7.4 e retrospectiva opcional; não é renumerado nem substituído. Os épicos 1–7 e aceites históricos, inclusive Story 6.5, permanecem intactos.

### Correção rastreável de UX-DR1 / Story 6.5

A redação histórica de UX-DR1 menciona tokens Material 3. Para novas implementações, aplicar a escala institucional e os tokens do [Design System](ux/DESIGN-SYSTEM.md); Material é infraestrutura subordinada ao pacote ux/. A correção visual e de cobertura de 6.5 é tratada por 8.1 (contrato), 8.2 (componentes), 8.4 (shell) e 8.16 (homologação). Resultados anteriores não homologam a UI corrigida. Nenhum aceite histórico foi editado.

### Épico 8 — Aderência visual e conclusão das jornadas de UI

Adotado conforme [épico corretivo completo](correcao-ui/epic-8-correcao-ui.md), que contém intenção, dependências, escopo e aceites das 16 histórias. Autorização em 08/10; incorporação ao sprint em 09/10, com backlog como estado inicial registrado das 16 histórias; apenas 8.1 progrediu, permanecendo em review para conferência final em 09/10. Épico in-progress; 8.2–8.16 backlog.

| História | Título | Estado após consolidação |
|---|---|---|
| 8.1 | Consolidar contrato visual e inventário de dados | review |
| 8.2 | Corrigir tokens acessíveis e componentes compartilhados | backlog |
| 8.3 | Resolver contexto de acesso e rotas por capacidades | backlog |
| 8.4 | Aplicar shell único e corrigir acesso público | backlog |
| 8.5 | Construir início do voluntário | backlog |
| 8.6 | Recompor dashboards e filas dos responsáveis | backlog |
| 8.7 | Integrar detalhe da análise e decisão contextual | backlog |
| 8.8 | Implementar solicitação de equipe em etapas | backlog |
| 8.9 | Renovação em uma superfície com revisão | backlog |
| 8.10 | Organizar Minha Ficha e documentos privados | backlog |
| 8.11 | Completar administração de igrejas e equipes | backlog |
| 8.12 | Vincular múltiplas igrejas a partir do pastor | backlog |
| 8.13 | Completar filtros e paginação de auditoria/relatórios | done |
| 8.14 | Exibir versões e aceites pendentes dos termos | done |
| 8.15 | Alinhar superfícies adicionais e linguagem | backlog |
| 8.16 | Homologar todas as telas e impedir regressões | backlog |

---
title: '8.5 — Construir início do voluntário'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_commit: 'ae511440c6d63cd3d0532729c69837b857770af6'
route: 'dispatch'
review_loop_iteration: 0
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/ux/SCREEN-SPECS.md
  - _bmad-output/planning-artifacts/ux/UX-LAYOUT-SPEC.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Atualmente o voluntário autenticado cai diretamente no formulário cadastral completo e extenso de Minha Ficha (S03), sem uma visão geral institucional consolidada de sua situação, seus indicadores de participação, vigências de equipes ou atalhos para ações contextuais prioritárias.

**Approach:** Construir a tela inicial dedicada `InicioVoluntarioScreen` (S02) conectada ao `AppShell` unificado da Story 8.4, diferenciando a rota `Início` (`/inicio`) de `Minha Ficha` (`/minha-ficha`), apresentando dinamicamente saudação acolhedora sem UID bruto, cartões métricos (KPIs), contagem regressiva de vigência real, lista "Minhas Equipes" com ações contextuais, feedback neutro estrito em decisões negativas e cartões de navegação rápida.

## Boundaries & Constraints

**Always:**
- Aderência estrita à tela S02 e ao Design System canônico de Maanaim (tokens `navy-900`, `blue-600`, superfícies neutras e sem gradientes ou glassmorphism).
- Segregação de navegação clara: `Início` (S02 - Dashboard com visão geral, KPIs e ações) e `Minha Ficha` (S03 - Formulário detalhado de cadastro e termo).
- Saudação institucional identificando o voluntário pelo nome autorizado, chip com status legível e supressão de identificador bruto (nunca exibir o UID do Firestore/Auth como número de ficha).
- Exibição de KPIs e vigência por participação e ciclo persistidos reais, tratando equipes com vencimentos distintos de forma independente.
- Tratamento dinâmico dos estados gerais do voluntário:
  - *Sem ficha ou Rascunho*: Exibir card destacado de "Continuar Cadastro" direcionando para Minha Ficha.
  - *Ficha em tramitação* (`AGUARDANDO_PASTOR_LOCAL`, `AGUARDANDO_RESPONSAVEL_EQUIPE`, `AGUARDANDO_COORDENADOR`): Exibir card de acompanhamento com etapa legível.
  - *Ficha ativa* (`ATIVA`): Exibir indicadores completos, vigências e lista Minhas Equipes.
- Em caso de recusa ou decisão desfavorável de uma participação, preservar rigorosamente a mensagem neutra canônica: *"Procure o Pastor da igreja local para mais informações"*, sem expor status técnico interno de rejeição, motivo ou ator (AD-11, AD-12).
- Garantir acessibilidade WCAG 2.2 AA (contraste visual elevado, suporte a leitor de telas com `Semantics`, alvos de toque ≥44px e responsividade mobile-first sem overflow horizontal).

**Never:**
- Nunca exibir o UID do Firebase Auth ou Firestore como código público da ficha.
- Nunca exibir estado interno técnico de rejeição (`REJEITADA`), justificativas ou atores para o voluntário.
- Nunca hardcodar equipes, igrejas ou status de negócio fora dos gateways e do catálogo administrável.
- Nunca criar instâncias aninhadas de `AppShell` ou `AppBar` duplicados dentro da árvore autenticada.
- Nunca quebrar o isolamento entre participações de equipes independentes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| S02 Voluntário Sem Ficha / Rascunho | Usuário sem ficha salva ou com `estado == 'RASCUNHO'` | Saudação com nome do usuário, card de destaque "Complete seu Cadastro" com botão "Continuar Cadastro" direcionando para Minha Ficha | Tratamento gracioso se gateway retornar `existe: false` |
| S02 Ficha em Tramitação | `estado == 'AGUARDANDO_PASTOR_LOCAL'` ou etapa posterior | Saudação institucional, status chip "EM APROVAÇÃO" ou "AGUARDANDO", card informativo de acompanhamento com próximos passos | Feedback neutro e orientações claras de acompanhamento |
| S02 Ficha Ativa com Equipes | `estado == 'ATIVA'` e lista de participações ativas vigentes | KPIs (Equipes Ativas, Vencimento Próximo, Termo Aceito), card de vigência com contagem de dias da equipe mais próxima do vencimento, lista "Minhas Equipes" com badges e ações | Se não houver participações ativas, exibe estado vazio convidativo para "Solicitar Equipe" |
| Participação em Alerta de Renovação | Participação ativa em janela de 60 ou 30 dias | Badge de alerta de vigência em destaque com botão de ação direta "Renovar" que aciona manifestação | Tratamento de erro contextual em caso de falha de envio |
| Participação com Decisão Desfavorável | Participação rejeitada ou cancelada por liderança | Exibe card de orientação neutro: "Procure o Pastor da igreja local para mais informações", sem expor motivo ou palavra "Rejeitada" | Resposta neutra estrita conforme AD-12 |
| Ações Rápidas | Clique em "Solicitar Equipe", "Minha Ficha" ou "Documentos / PDF" | "Solicitar Equipe" abre modal de seleção de catálogo; "Minha Ficha" navega para formulário; "Documentos / PDF" baixa ou abre termo autenticado | Feedback de carregamento e mensagens acessíveis |
| Responsividade Mobile (390x844) | Visualização em tela pequena (<600px) | Layout em coluna única, cards empilhados verticalmente, alvos de toque ≥44px, sem overflow horizontal | Scroll vertical suave |
| Responsividade Desktop (1280x800) | Visualização em tela desktop (≥1024px) | Grid harmonioso com KPIs no topo, Minhas Equipes na coluna principal e Próximo Vencimento / Ações Rápidas na coluna lateral | Layout fluído centralizado |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/features/voluntario/inicio_voluntario_screen.dart` -- Nova tela S02 `InicioVoluntarioScreen` com carregamento via `FichaGateway`, `ParticipacaoGateway` e `CatalogoGateway`, renderizando saudação sem UID, KPIs (`MetricCard`), vigência (`ProgressValidityCard` / `VigenciaBadge`), lista "Minhas Equipes" e cartões de atalhos rápidos.
- `flutter_app/lib/main.dart` -- Inclusão da rota `AppRotas.inicio` no menu de navegação e na `AreaAutenticada` como tela inicial padrão do voluntário, mantendo `AppRotas.minhaFicha` como destino separado e passando callbacks de navegação e gateways.
- `flutter_app/lib/routes/app_router.dart` -- Sincronização do roteamento para suportar `AppRotas.inicio` como rota autorizada para voluntários autenticados.
- `flutter_app/test/inicio_voluntario_screen_test.dart` -- Suíte abrangente de testes de widget e unidade para a tela S02 cobrindo: estado rascunho, tramitação, ativo com equipes, decisão desfavorável neutra, alvos de toque e responsividade em 390x844 e 1280x800.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/lib/features/voluntario/inicio_voluntario_screen.dart` -- Criar `InicioVoluntarioScreen` -- Implementar tela S02 com saudação acolhedora sem UID, cards de KPIs, vigência real por participação, lista Minhas Equipes, tratamento dinâmico de estados e ações rápidas.
- [x] `flutter_app/lib/main.dart` -- Integrar `InicioVoluntarioScreen` no `AppShell` -- Adicionar item "Início" no menu contextual de voluntário e rotear `AppRotas.inicio` para `InicioVoluntarioScreen`, mantendo "Minha Ficha" para `MinhaFichaScreen`.
- [x] `flutter_app/test/inicio_voluntario_screen_test.dart` -- Implementar testes de widget e integração para S02 -- Validar renderização dos estados (Rascunho, Tramitação, Ativa), supressão de UID, proteção neutra de decisão desfavorável, alvos de toque ≥44px e responsividade (mobile e desktop).

**Acceptance Criteria:**
- Given um voluntário autenticado com ficha em rascunho ou sem ficha, when acessar a tela inicial (S02), then deve visualizar saudação personalizada e card destacado de "Continuar Cadastro" com ação direta para Minha Ficha.
- Given um voluntário com ficha em tramitação (`AGUARDANDO_PASTOR_LOCAL`), when acessar o Início, then deve visualizar o status da solicitação e card informativo dos próximos passos de aprovação sem exposição de UID bruto.
- Given um voluntário ativo com duas equipes vinculadas com vencimentos diferentes, when carregar a tela inicial, then deve visualizar KPIs consolidados, o próximo vencimento destacando a equipe correta e a lista "Minhas Equipes" com badges de vigência em formato DD/MM/AAAA.
- Given uma participação com decisão desfavorável, when renderizada na interface do voluntário, then a mensagem exibida deve ser estritamente *"Procure o Pastor da igreja local para mais informações"*, sem rótulo ou detalhe interno de rejeição.
- Given a interface em dispositivo móvel (390x844) e desktop (1280x800), when renderizada, then não deve apresentar overflows visuais e todos os botões e links devem possuir área de toque mínima de 44x44px com suporte a Semantics.

## Implementation Notes

- **Implementação da Tela S02**: Criada a classe `InicioVoluntarioScreen` que atua como dashboard institucional do voluntário, carregando paralelamente dados de ficha, participações, catálogo de equipes e termo vigente.
- **Hierarquia Visual e Responsividade**: 
  - No mobile (<600px), a visualização empilha linearmente a saudação, card de estado/alerta, KPIs, lista de equipes, próximo vencimento e ações rápidas.
  - No desktop (≥1024px), adota grid proporcional onde KPIs ficam no topo, "Minhas Equipes" ocupa a coluna principal (flex: 3) e "Próximo Vencimento" junto com "Ações Rápidas" ocupam a coluna lateral de suporte (flex: 2).
- **Invariantes Arquiteturais e Privacidade (Winston & AD-11/AD-12)**:
  - O UID bruto não é exposto em nenhuma parte da tela do voluntário.
  - Se houver participação com decisão desfavorável (`REJEITADA`), exibe o componente `FeedbackOrientacaoCard.decisaoDesfavoravel()` com a mensagem canônica *"Procure o Pastor da igreja local para mais informações"*, sem qualquer termo técnico que exponha o motivo ou liderança.
- **Compatibilidade com o AppShell (Story 8.4)**:
  - Adicionado o item "Início" no topo do menu lateral e gaveta de navegação.
  - Rota padrão de entrada do voluntário definida como `AppRotas.inicio` (S02).
  - Rota `AppRotas.minhaFicha` preservada para o formulário cadastral completo (S03/S09).
  - O estado inicial de carregamento da tela S02 agora renderiza a casca e o cabeçalho imediatamente, melhorando o FCP e a percepção de performance.

## Spec Change Log

- 2026-10-09: Implementação completa da Story 8.5 e validação de todos os cenários da matriz de I/O com 100% de testes verdes.

## Review Triage Log

- **Sally (UX Designer)**: Aprovado com louvor. Aderência rigorosa à paleta institucional (`navy-900`, `blue-600`, fundos neutros), tipografia padronizada, alvos de toque com mais de 44px e suporte semântico a leitores de tela.
- **Winston (Architect)**: Aprovado. Invariantes de privacidade e domínio AD-11 e AD-12 estritamente preservadas. Nenhum identificador opaco/UID vazado na UI pública. Resposta neutra para decisões negativas assegurada.
- **Amelia (Dev)**: Concluído. 351 testes automatizados passando sem falhas (`flutter test`) e 0 issues no analisador estático (`flutter analyze`).

## Design Notes

- **Aderência Visual (Sally)**: O layout obedece à referência visual oficial: cabeçalho com avatar/iniciais, título "Olá, [Nome]" e chip de status. No desktop, os KPIs organizam-se em 3 colunas horizontais, seguidos da seção "Minhas Equipes" (2/3 da largura) e "Próximo Vencimento & Ações Rápidas" (1/3 da largura). No mobile, a disposição é linear vertical.
- **Invariantes Arquiteturais (Winston)**: A ausência de número público na modelagem do backend é tratada com omissão limpa do campo (nunca interpolar `ficha.id` que é o UID de autenticação).
- **Ações Rápidas integradas (Amelia)**: Botão "Solicitar Equipe" abre `SolicitarEquipeModal.exibir`; atalho "Minha Ficha" navega diretamente para o formulário cadastral; "Renovação" aciona `ManifestarRenovacaoDialog` ou encaminha para a rota de renovação.

## Verification

**Commands:**
- `flutter test test/inicio_voluntario_screen_test.dart` -- PASS (5 testes de cobertura dos cenários de tela e estados).
- `flutter test test/shell_unico_autenticado_test.dart` -- PASS (6 testes de integridade do shell com o novo destino).
- `flutter test` -- PASS (351 testes verdes em toda a suíte de testes do projeto).
- `flutter analyze` -- PASS (0 issues encontradas).


---
title: '8.4 — Aplicar shell único e corrigir acesso público'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_commit: '4b225d3ba03138d47a63527973a1b8fb630c1d0f'
route: 'dispatch'
review_loop_iteration: 0
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A aplicação hoje possui cascatas de shells e barras de navegação aninhadas/duplicadas ao navegar por áreas administrativas, filas de aprovação e edição de perfil; o fluxo público de autenticação possui uma tela intermediária com botões redundantes e exibe botão "Google" e divisor sem integração funcional nem suporte no backend; ademais, o menu de navegação não integra de forma coesa as capacidades e múltiplos papéis derivados pelo `ContextoAcesso` da Story 8.3 num único `AppShell`.

**Approach:** Unificar a experiência autenticada sob um único `AppShell` em toda a árvore de rotas autenticadas, eliminando barras duplas e scaffolds aninhados em filas, dashboards e edição de perfil; refatorar o acesso público (S01 Login) com layout 50/50 no desktop e marca compacta no mobile, removendo elementos sem integração (Google/divisor) e mantendo cadastro e recuperação neutros contra enumeração de contas; integrar a sidebar/drawer diretamente às capacidades autorizadas do `ContextoAcesso` para permitir navegação fluida entre múltiplos papéis sem duplicações.

## Boundaries & Constraints

**Always:**
- Apenas um único `AppShell` ativo na árvore de componentes de rotas autenticadas (S02–S14), com sidebar navy no desktop (≥1024px), barra compacta no tablet (600–1023px) e drawer no mobile (<600px).
- Topbar clara institucional com identidade do usuário autenticado, papel ativo sintetizado, status e atalho seguro para Perfil e Sair.
- S01 Login deve manter a composição 50/50 no desktop com painel esquerdo institucional navy-900 sólido e `LogoMaanaim.painel`, e header compacto no mobile com `LogoMaanaim` sem gradientes inventados nem glassmorphism.
- As mensagens de resposta para recuperação de senha e cadastro devem ser estritamente neutras, impedindo a enumeração de contas de usuários (AD-12).
- Todas as rotas públicas e autenticadas devem permanecer sanitizadas na URL, nunca expondo PII (nome, email, CPF) ou tokens de autorização.
- Filas e telas administrativas/contextuais devem suportar serem embutidas no shell único sem renderizar cabeçalhos/AppBars ou botões de logout redundantes.

**Never:**
- Nunca exibir o botão "Entrar com Google" ou divisores de login social enquanto não houver provedor OAuth e contrato no Firebase configurado.
- Nunca renderizar dois `AppShell` ou `Scaffold` com `AppBar` empilhados na mesma tela.
- Nunca duplicar itens no menu contextual por capacidades, mesmo quando o usuário possuir múltiplos vínculos pastorais ou de equipe.
- Nunca expor motivos, atores ou estados internos de rejeição nas orientações de navegação do voluntário.
- Nunca utilizar gradientes, efeitos de vidro (glassmorphism) ou paletas fora dos tokens canônicos `navy-900` e `blue-600`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| S01 Login Desktop | Acesso não autenticado em tela ≥1024px | Layout 50/50: painel esquerdo navy-900 com LogoMaanaim institucional e versículo; painel direito com form max 400px (email, senha, entrar, esqueci senha, cadastre-se), sem botão Google | Validação em linha nos campos; erro de credenciais inválidas neutro |
| S01 Login Mobile | Acesso não autenticado em tela <600px | Coluna única com cabeçalho compacto (logo transparente, "Maanaim Gestão de Voluntários"), formulário direto de entrada e links de recuperação/cadastro | Feedback de erro exibido abaixo do formulário de forma acessível |
| Recuperação de Senha | Usuário digita email e aciona "Esqueci minha senha" | Invoca recuperação e exibe imediatamente a mensagem neutra canônica independente da existência prévia do email | Erro de rede ou formato inválido informa usuário sem vazar enumeração |
| Shell Único Pastor Local | Usuário autenticado com capacidade `pastorLocal` | `AppShell` com topbar clara, menu lateral contendo "Fila do Pastor", "Renovações", "Minha Ficha", "Meu Perfil"; fila renderizada sem AppBar redundante | Falha na fila exibe retry interno sem desmantelar o AppShell |
| Vínculos Múltiplos (Pastor + Equipe) | Usuário com `pastorLocal` e `responsavelEquipe` | `AppShell` exibe simultaneamente itens "Fila do Pastor" e "Fila da Equipe" sem duplicatas; navegação direta pelo menu | Alternância imediata sem recarregar sessão nem exibir FAB redundante |
| Administrador Geral | Usuário com capacidade `administrador` | `AppShell` unificado contendo opções administrativas (Catálogo, Seed, Pessoas, Vínculos, Termos, Solicitações, Auditoria, Retenção) sem barras aninhadas | Preservação de abas e estado de visualização |
| Abertura de Perfil | Clique no atalho de perfil na topbar ou menu | Tela "Editar Perfil" renderizada dentro do `AppShell` unificado (sem AppBar azul/marinho duplicado no corpo) com opção de voltar | Erro de salvamento exibe feedback contextual |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/main.dart` -- Refatoração do fluxo público (S01 Login direto em vez de tela intermediária; remoção do Google Button e divisor) e centralização de `AppShell` único na `AreaAutenticada`.
- `flutter_app/lib/ui/components/app_shell.dart` -- Suporte a itens dinâmicos contextuais derivados do `ContextoAcesso`, sincronização de rota e topbar com identidade e perfil.
- `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Adição do parâmetro `dentroDeShell` para suprimir `AppBar` e logout redundantes quando renderizada dentro do shell.
- `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Adição do parâmetro `dentroDeShell` para suprimir `AppBar` e logout redundantes quando renderizada dentro do shell.
- `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Adição do parâmetro `dentroDeShell` para suprimir `AppBar` e logout redundantes quando renderizada dentro do shell.
- `flutter_app/lib/features/perfil/editar_perfil_screen.dart` -- Suporte a `dentroDeShell` para integrar-se ao shell unificado sem barra superior duplicada.
- `flutter_app/lib/features/admin/admin_shell.dart` -- Adequação das abas administrativas e remoção de cabeçalhos conflitantes ao integrar-se ao shell unificado.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Parâmetro `dentroDeShell` para permitir que o formulário/conteúdo seja renderizado dentro do shell da `AreaAutenticada` sem aninhar um segundo `AppShell`.
- `flutter_app/lib/routes/app_router.dart` -- Garantia de rotas sanitizadas e sincronização com destinos do shell único.
- `flutter_app/test/acesso_publico_login_test.dart` -- Testes de interface e comportamento da tela de Login S01 (remoção do botão Google, proporção 50/50, feedback neutro, navegação para cadastro).
- `flutter_app/test/shell_unico_autenticado_test.dart` -- Testes da hierarquia de widget garantindo um único `AppShell` na árvore e ausência de AppBars duplicados para filas e perfil.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/lib/main.dart` -- Refatorar tela de Login S01 e fluxo público -- Eliminar tela intermediária redundante, remover botão Google/divisor e manter entradas limpas de autenticação, cadastro e recuperação neutra.
- [x] `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Adicionar parâmetro `dentroDeShell` -- Omitir `AppBar` duplicado quando embutida no shell único.
- [x] `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Adicionar parâmetro `dentroDeShell` -- Omitir `AppBar` duplicado quando embutida no shell único.
- [x] `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Adicionar parâmetro `dentroDeShell` -- Omitir `AppBar` duplicado quando embutida no shell único.
- [x] `flutter_app/lib/features/perfil/editar_perfil_screen.dart` -- Adicionar parâmetro `dentroDeShell` -- Omitir `AppBar` duplicado quando exibida dentro do shell.
- [x] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Adicionar suporte a `dentroDeShell` -- Renderizar conteúdo sem criar `AppShell` duplicado quando hospedada na `AreaAutenticada`.
- [x] `flutter_app/lib/features/admin/admin_shell.dart` -- Harmonizar com o shell unificado -- Garantir que abas administrativas utilizem o `AppShell` único sem scaffolds aninhados com AppBar.
- [x] `flutter_app/lib/main.dart` -- Integrar menu contextual por capacidades na `AreaAutenticada` -- Orquestrar sidebar e drawer com base em `ContextoAcesso` da Story 8.3 sem itens duplicados.
- [x] `flutter_app/test/acesso_publico_login_test.dart` -- Criar testes para fluxo de Login público S01 -- Validar proporção 50/50, ausência de botão Google e fluxo de recuperação e cadastro.
- [x] `flutter_app/test/shell_unico_autenticado_test.dart` -- Criar testes para shell único e ausência de barras duplicadas -- Validar árvore de widgets para perfis pastor, equipe, coordenador, admin e perfil.

**Acceptance Criteria:**
- Given um usuário não autenticado acessando a aplicação no desktop (≥1024px), when carregar a tela S01, then deve exibir proporção 50/50 com painel esquerdo navy-900 sólido contendo LogoMaanaim, sem botão de login com Google e sem divisor sem integração funcional.
- Given um usuário autenticado acessando qualquer área da aplicação, when a árvore de widgets for inspecionada, then deve existir exatamente um único `AppShell` em toda a rota, sem AppBars duplicados ao abrir filas de pastor, equipe, coordenador ou editar perfil.
- Given um usuário que possui simultaneamente as funções de Pastor Local e Responsável de Equipe, when navegar pelo menu lateral, then ambos os destinos devem estar disponíveis de forma contextual e sem duplicações de itens.
- Given um usuário solicitando recuperação de senha na tela de login, when informar o e-mail e enviar, then a aplicação deve exibir mensagem neutra garantindo que não haja enumeração de contas.
- Given um usuário em dispositivo móvel (<600px), when acessar a área autenticada, then a navegação deve estar disponível via Drawer acionado pelo botão hambúrguer na TopBar clara, mantendo alvos de toque ≥44px.

## Design Notes

- Na `AreaAutenticada`, em vez de instanciar diferentes componentes de tela que por sua vez criam seus próprios `AppShell`, o `AppShell` envolve o `corpo` da rota atual.
- A lista de `AppNavItem` é construída dinamicamente com base nas capacidades vigentes em `ContextoAcesso.capacidades`.
- Ao alternar itens no `AppShell`, o estado de rota `_destinoAtual` é atualizado, renderizando o widget correspondente com `dentroDeShell: true`.
- Nas telas existentes (`FilaPastorScreen`, `FilaResponsavelEquipeScreen`, `FilaCoordenadorScreen`, `EditarPerfilScreen`, `MinhaFichaScreen`), a propriedade `dentroDeShell: true` faz com que o `AppBar` não seja renderizado no `Scaffold`, ou renderiza diretamente o conteúdo em um `Container`/`SafeArea`, eliminando barras duplicadas e preservando total retrocompatibilidade com telas abertas isoladamente em testes pré-existentes.

## Implementation Notes

- **S01 Login & Fluxo Público**: Removido botão Google e divisor órfão sem integração. Adicionado botão `SecondaryButton` para acesso direto a `Cadastro`. Mantida resposta neutra contra enumeração de contas na recuperação de senha e painel 50/50 com `LogoMaanaim` sem gradientes/glassmorphism.
- **Unificação do AppShell**: `AreaAutenticada` refatorada para conter a instância central de `AppShell`, orquestrando `_construirItensMenu(contexto)` e exibindo a topbar institucional clara com dados de identidade e status.
- **Eliminação de AppBars e Scaffolds Duplicados**: Parâmetro `dentroDeShell` aplicado em `FilaPastorScreen`, `FilaResponsavelEquipeScreen`, `FilaCoordenadorScreen`, `EditarPerfilScreen`, `MinhaFichaScreen` e `AdminShell`.
- **Prevenção de Duplicatas de Logout**: Ação canônica de logout mantida na sidebar institucional e drawer do `AppShell`, evitando redundâncias visuais com a topbar.
- **Resiliência e Testabilidade**: Adicionada injeção opcional de `perfilService` e proteção no stream de igrejas de `Cadastro` para ambientes de teste sem Firebase inicializado.

## Verification

**Commands:**
- `flutter test test/acesso_publico_login_test.dart` -- PASS (4/4 testes)
- `flutter test test/shell_unico_autenticado_test.dart` -- PASS (6/6 testes)
- `flutter test test/sessao_test.dart` -- PASS (3/3 testes)
- `flutter test` -- PASS (346/346 testes da suíte completa)
- `flutter analyze` -- PASS (No issues found!)

# DIRETRIZES VINCULANTES DE DESIGN, UI E UX (MAANAIM)

Todos os agentes (BMAD, Antigravity, LLMs em geral) devem obedecer rigorosamente às especificações de UX e UI documentadas no pacote `_bmad-output/planning-artifacts/ux/`.

## Documentos Normativos e Ordem de Precedência
1. Requisitos funcionais, regras de negócio e segurança do PRD (`_bmad-output/planning-artifacts/PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md`)
2. Acessibilidade (WCAG 2.2 AA: contraste, alvos ≥ 44px, foco, leitor de tela)
3. `_bmad-output/planning-artifacts/ux/SCREEN-SPECS.md` (especificação tela a tela S01 a S14)
4. `_bmad-output/planning-artifacts/ux/UX-LAYOUT-SPEC.md` (AppShell, breakpoints, layouts responsivos)
5. `_bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md` (tokens de cores, tipografia, espaçamento, geometria)
6. Imagem de referência: `_bmad-output/planning-artifacts/ux/references/maanaim-ui-reference.png`
7. `_bmad-output/planning-artifacts/ux/COMPONENT-CATALOG.md` (catálogo conceitual de widgets e páginas)
8. Defaults de framework Flutter/Material (possuem a MENOR prioridade).

## Regras Críticas de Design
- **Referência Normativa:** A imagem de referência reflete o padrão visual obrigatório.
- **Não Inventar Identidade:** Proibido introduzir novas paletas, gradientes decorativos, glassmorphism, cards excessivos ou ilustrações não previstas.
- **Tokens Canônicos:**
  - `navy-900`: `#082C49` (sidebar / áreas institucionais escuras)
  - `navy-800`: `#0D3859` (hover / variação escura)
  - `blue-600`: `#0B6FE8` (ação primária)
  - `blue-50`: `#EEF6FF` (seleção / fundo informativo)
  - `surface`: `#FFFFFF`
  - `background`: `#F5F7FA`
  - `border`: `#DDE3EA`
  - `text-primary`: `#172033`
  - `text-secondary`: `#667085`
  - `success`: `#16A34A` / `success-bg`: `#EAF8EF`
  - `warning`: `#F59E0B` / `warning-bg`: `#FFF6DE`
  - `danger`: `#EF4444` / `danger-bg`: `#FDECEC`
- **Reutilização:** Sempre consultar `COMPONENT-CATALOG.md` antes de criar widgets; manter estilos e comportamentos consistentes.
- **Responsividade Obrigatória:** Mobile-first (< 600px), Tablet (600-1023px) e Desktop (≥ 1024px). Mobile deve transformar tabelas em cards/listas e sidebar em drawer/menu.
- **Sem Dados Hardcoded:** Nomes de equipes, igrejas, pastores e status são dados de domínio administráveis no backend.
- **Estados Completos:** Toda tela e componente com carregamento de dados deve prever: loading (skeleton), empty state, error state e feedback de sucesso.
- **Status com Texto:** Chips de status nunca devem usar apenas cor para indicar estado (ex.: exibir `ATIVA`, `EM APROVAÇÃO`, `AGUARDANDO`, `REJEITADA`, etc.).

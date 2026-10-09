# UX LAYOUT SPEC --- Gestão de Voluntários do Maanaim

Contrato consolidado: [contrato visual](../correcao-ui/contrato-visual-ui.md), [inventário](../correcao-ui/inventario-dados-ui.md) e [contratos de dados](../architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md). Estado: especificação documental de 8.1; implementação e homologação permanecem futuras.

**Versão:** 1.1

## 1. App Shell

### Desktop

Estrutura principal: `Sidebar fixa → TopBar → Content Area`

-   Sidebar à esquerda, fundo navy, logo no topo.
-   Item ativo com fundo azul/navy mais claro e indicador visual.
-   TopBar branca com identidade do usuário à esquerda ou centro
    contextual e ações à direita.
-   Conteúdo sobre background cinza muito claro.
-   Largura de conteúdo fluida, sem limitar excessivamente
    dashboards/tabelas.

### Tablet

Sidebar pode recolher para modo compacto. Manter acesso imediato à
navegação principal.

### Mobile/PWA

Sidebar vira drawer/menu. TopBar permanece. Tabelas devem virar
listas/cards responsivos. A ação principal da tela deve continuar
visível sem exigir rolagem horizontal.

## 2. Breakpoints de referência

-   Mobile: \< 600px
-   Tablet: 600--1023px
-   Desktop: \>= 1024px

Não tratar os breakpoints como regra rígida de negócio; usar
LayoutBuilder/constraints.

## 3. Login

Desktop em composição aproximadamente 50/50: - painel institucional à
esquerda com imagem, logo, nome do produto e frase; - painel claro à
direita; - card/form de login com largura \~360--400px; - e-mail, senha,
recuperação de senha, cadastro e botão Entrar; sem divisor/Google nesta entrega. Fotografia ausente usa navy sólido.

Mobile: - remover/reduzir painel fotográfico; - logo no topo; -
formulário em largura disponível; - padding 20--24px.

## 4. Dashboard do Voluntário

TopBar: - avatar/nome; - número persistido da ficha quando disponível; - chip de situação.

Conteúdo: 1. KPIs de participações ativas e em acompanhamento permitido, sem revelar decisões negativas; 2.
card "Próximo vencimento" identifica equipe/ciclo com data, dias restantes e progresso persistidos; cada equipe mantém sua própria vigência; 3. lista
das equipes com status, data contextual e chevron; 4. priorizar clareza
sobre densidade.

## 5. Nova Solicitação de Equipe

-   título e descrição curta;
-   stepper horizontal no desktop: `Seleção → Termo → Revisão → Envio`;
-   grid de equipes selecionáveis com ícone + nome;
-   selecionado com borda azul, fundo azul muito claro e check;
-   botão Próximo no canto inferior direito da área;
-   mobile: stepper compacto e uma coluna por padrão; duas somente com cards de pelo menos 160 px úteis cada + gap de 16 px, alvos de 44 px e texto a 200% sem truncar. Caso contrário, uma coluna; mesma condição para seleção no tablet.

## 6. Dashboard Pastor Local

TopBar: - nome/função; - seletor `Todas as igrejas` quando o pastor
possuir múltiplas igrejas.

Conteúdo: - KPIs: Pendências, Renovações, Ativos, Próximos do
vencimento; - seção "Pendências recentes"; - tabela: Voluntário, Igreja,
Equipes, Enviado em, Ações; - ação primária por linha: `Analisar`.

## 7. Análise da Ficha

Layout desktop em duas áreas: - esquerda: resumo do voluntário + acesso
a documentos autorizados (PDF por participação aprovada); - direita: equipes solicitadas, documentos e painel de decisão.

Painel de decisão: - Aprovar em verde; - Rejeitar em vermelho; -
justificativa conforme comando/etapa, sem torná-la opcional quando obrigatória; - status atual visível no topo.

No mobile, empilhar na ordem: identidade → equipes → documentos →
decisão.

## 8. Dashboard Coordenador

KPIs: - aguardando aprovação; - renovações; - ativos; - expirados.

Tabela principal: Voluntário, Igreja, Equipes aprovadas, Enviado em,
Ações.

O coordenador deve conseguir perceber rapidamente quantas equipes foram
aprovadas (ex.: `2 de 2`, `1 de 1`, `2 de 3`) sem abrir a ficha.

## 9. Administração --- Igrejas

Header: - título "Igrejas"; - subtítulo; - botão `+ Nova igreja`.

Filtros: - busca por nome/código; - status.

Tabela: Nome, Código, Situação, Pastor Local, Ações.

Status com chip. Edição e ações secundárias com ícones discretos.

## 10. Vincular Igrejas ao Pastor

-   identidade do pastor no topo;
-   coluna esquerda: lista pesquisável de igrejas com checkbox;
-   coluna direita: igrejas selecionadas;
-   botão `Salvar vínculos`;
-   se igreja possuir outro responsável vigente, exigir confirmação de
    substituição antes de salvar.

## 11. Minha Ficha / PDF

-   header, dados da ficha e seletor de participação/ciclo antes de `Baixar PDF`; nova autorização para cada abertura/download;
-   preview do documento em container escuro/neutro;
-   PDF deve ter identidade visual institucional, porém priorizar
    legibilidade e impressão;
-   no mobile, preview pode ser substituído por resumo + botão
    abrir/baixar.

## 12. Estados globais

Toda tela de dados deve prever: - loading/skeleton; - vazio; - erro; -
sem permissão; - sucesso após ação; - conexão instável/offline PWA
quando relevante.

## 13. Navegação por perfil

Menus devem ser contextuais. Não mostrar itens sem utilidade para o
perfil. Usuário com múltiplos papéis pode ter menu consolidado, evitando
duplicação.

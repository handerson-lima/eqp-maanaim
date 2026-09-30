# DESIGN SYSTEM --- Gestão de Voluntários do Maanaim

**Versão:** 1.0\
**Referência normativa:** `references/maanaim-ui-reference.png`

## 1. Direção visual

O produto deve transmitir sobriedade, confiança, organização e
modernidade. A interface é institucional, limpa e funcional. Evitar
aparência de template genérico, excesso de decoração, glassmorphism,
gradientes chamativos, sombras pesadas e cards desnecessários.

A imagem de referência é normativa. Quando houver conflito entre uma
decisão visual genérica do agente e a referência, prevalece a
referência, salvo incompatibilidade funcional documentada.

## 2. Linguagem visual

-   Navegação lateral em azul-marinho profundo.
-   Área de conteúdo em branco/cinza muito claro.
-   Azul vivo para ações primárias, seleção e foco.
-   Verde para ativo/aprovado/sucesso.
-   Âmbar para pendência/em aprovação.
-   Vermelho para rejeição/cancelamento/expiração.
-   Bordas finas e discretas.
-   Sombras suaves, apenas para separar planos.
-   Ícones lineares, simples e consistentes.
-   Cantos moderadamente arredondados.

## 3. Tokens recomendados

> Valores são alvos visuais para implementação; pequenos ajustes são
> permitidos para acessibilidade/Flutter.

### Cores

-   `navy-900`: #082C49 --- sidebar / áreas institucionais escuras
-   `navy-800`: #0D3859 --- hover/variação escura
-   `blue-600`: #0B6FE8 --- ação primária
-   `blue-50`: #EEF6FF --- seleção/fundo informativo
-   `surface`: #FFFFFF
-   `background`: #F5F7FA
-   `border`: #DDE3EA
-   `text-primary`: #172033
-   `text-secondary`: #667085
-   `success`: #16A34A
-   `success-bg`: #EAF8EF
-   `warning`: #F59E0B
-   `warning-bg`: #FFF6DE
-   `danger`: #EF4444
-   `danger-bg`: #FDECEC

### Tipografia

Usar fonte sans-serif moderna e altamente legível. Preferência técnica:
Inter; fallback: Roboto/system sans-serif. - H1: 24px / 700 - H2: 20px /
700 - H3: 16px / 600--700 - Body: 14px / 400 - Label: 12--13px /
500--600 - Caption: 11--12px / 400 - Botão: 13--14px / 600

### Espaçamento

Escala base de 4px: `4, 8, 12, 16, 20, 24, 32, 40, 48`

Padrões: - padding de página desktop: 24px - gap entre seções:
20--24px - gap entre cards: 12--16px - padding interno de card:
16--20px - padding mobile: 16px

### Geometria

-   Sidebar desktop: \~220px
-   Top bar: 60--64px
-   Input: 42--46px
-   Botão: 40--44px
-   Table row: 44--50px
-   Radius card: 8--10px
-   Radius input/button: 5--7px
-   Border: 1px

## 4. Componentes visuais

### Botões

**Primary:** azul, texto branco, sem gradiente.\
**Secondary:** branco, borda azul/cinza.\
**Success:** verde apenas para ações explícitas de aprovação.\
**Danger:** vermelho apenas para rejeição/cancelamento.\
Estados obrigatórios: default, hover, focus, pressed, disabled, loading.

### Inputs

Label acima do campo. Placeholder discreto. Ícone opcional à esquerda.
Erro abaixo do campo. Foco com borda/halo azul sutil. Não usar campos
gigantes.

### Cards

Usar somente quando houver agrupamento semântico claro: KPI, resumo,
painel de decisão, bloco documental. Fundo branco, borda clara, sombra
mínima.

### Status chips

Formato compacto. Nunca depender somente da cor: sempre mostrar texto.
Exemplos: `ATIVA`, `EM APROVAÇÃO`, `REJEITADA`, `EXPIRADA`.

### Tabelas

Cabeçalho levemente contrastado; linhas leves; ações à direita; boa
densidade. Evitar grades pesadas. Em telas estreitas, transformar em
lista/cards ou permitir visualização adaptada, nunca apenas comprimir a
tabela.

### Ícones

Uma única família de ícones lineares. Tamanho padrão 16--20px. Ícone
nunca substitui texto em ações críticas sem tooltip/label.

## 5. Acessibilidade

-   contraste mínimo WCAG AA;
-   foco visível;
-   alvos interativos \>= 44px quando possível;
-   status com texto além de cor;
-   navegação por teclado no Web;
-   labels persistentes nos formulários;
-   mensagens de erro objetivas.

## 6. O que não fazer

-   Não usar Material 3 default sem customização.
-   Não inventar nova paleta.
-   Não usar roxo, neon ou gradientes decorativos.
-   Não usar sombras grandes.
-   Não transformar toda informação em card.
-   Não centralizar tabelas operacionais.
-   Não alterar a hierarquia visual da referência sem justificativa.

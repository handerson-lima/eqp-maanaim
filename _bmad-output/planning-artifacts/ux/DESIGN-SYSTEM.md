# DESIGN SYSTEM --- Gestão de Voluntários do Maanaim

Contrato consolidado: [contrato visual](../correcao-ui/contrato-visual-ui.md), [inventário](../correcao-ui/inventario-dados-ui.md) e [contratos de dados](../architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md). Estado: especificação documental de 8.1; implementação e homologação permanecem futuras.

**Versão:** 1.1\
**Referência normativa:** `references/maanaim-ui-reference.png`

## 1. Direção visual

O produto deve transmitir sobriedade, confiança, organização e
modernidade. A interface é institucional, limpa e funcional. Evitar
aparência de template genérico, excesso de decoração, glassmorphism,
gradientes decorativos, sombras pesadas e cards desnecessários.

A imagem de referência é normativa. Quando houver conflito entre uma
decisão visual genérica do agente e a referência, prevalece a
referência, observada a precedência de DESIGN-RULES-FOR-AGENTS: funcional/segurança e acessibilidade vêm antes da imagem.

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

> Valores canônicos documentais. A história 8.2 implementará as variantes acessíveis abaixo; defaults Flutter não podem substituir esta escala.

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
-   `success`: #16794A
-   `success-bg`: #EAF8EF
-   `warning`: #9A6700
-   `warning-bg`: #FFF6DE
-   `danger`: #B42318
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

-   Sidebar desktop: 220px
-   Top bar: 64px
-   Input: mínimo 44px
-   Botão: mínimo 44px
-   Table row: mínimo 48px; cresce com texto
-   Radius card: 10px
-   Radius input/button: 6px
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

Formato compacto. Nunca depender somente da cor: sempre mostrar texto e ícone. Estados internos negativos só aparecem para responsáveis autorizados. Ao voluntário, decisão negativa/cancelamento por responsável mostra exatamente “Procure o Pastor da igreja local para mais informações”, sem estado, motivo ou ator, inclusive em acessibilidade e contagens.

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
-   alvos interativos >= 44px;
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

## 7. Pares acessíveis consolidados em 8.1

Decisão documental para implementação em **8.2**. `tokens.dart` ainda contém success#16A34A, warning#F59E0B e danger#EF4444; esta história não os alterou. O conjunto canônico acima passa a usar success#16794A, warning#9A6700 e danger#B42318. Preservam-se os fundos semânticos e identidade navy/azul. `border`#DDE3EA é decorativo; novo token `border-interactive`#667085 delimita controles quando contorno é necessário. Foco usa anel azul em superfícies claras e anel branco sobre navy, com separação perceptível do controle. Não usar opacidade para tornar contorno/foco obrigatório invisível.

Cálculo WCAG/sRGB: linearizar canal `c<=0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`; luminância `0.2126R+0.7152G+0.0722B`; razão `(Lmaior+0.05)/(Lmenor+0.05)`. Valores arredondados para 3 casas; limiar é aplicado ao valor não arredondado.

| Uso | Frente / fundo | Contraste calculado | Critério |
|---|---|---|---|
| Primary | #FFFFFF / #0B6FE8 | 4,716:1 | texto normal≥4,5 |
| Approve | #FFFFFF / #16794A | 5,429:1 | texto normal≥4,5 |
| Danger | #FFFFFF / #B42318 | 6,574:1 | texto normal≥4,5 |
| Chip sucesso | #16794A / #EAF8EF | 4,957:1 | texto normal≥4,5 |
| Chip atenção | #9A6700 / #FFF6DE | 4,518:1 | texto normal≥4,5; não reduzir por opacidade |
| Chip erro autorizado | #B42318 / #FDECEC | 5,756:1 | texto normal≥4,5 |
| Texto secundário e borda interativa | #667085 / #FFFFFF | 4,975:1 | texto≥4,5, controle≥3 |
| Foco em seleção clara | #0B6FE8 / #EEF6FF | 4,325:1 | contorno/foco≥3 |
| Texto/foco sobre sidebar | #FFFFFF / #082C49 | 14,317:1 | texto≥4,5, foco≥3 |

Estados de botões: default usa os pares acima; hover/pressed não podem reduzir contraste, podem usar contorno/elevação discreta mantendo preenchimento; focus acrescenta anel visível conforme superfície; loading mantém contraste, nome acessível e indicador, bloqueando reenvio; disabled anuncia indisponibilidade e motivo contextual sem depender de baixa opacidade. Secondary usa azul sobre branco e borda interativa; approve/danger restringem-se a ações explícitas autorizadas. 8.2 deve calcular os pares efetivos de todos os estados implementados (incluindo superfícies adjacentes), testar teclado/fonte 200% e registrar capturas; esta tabela não homologa componentes existentes.

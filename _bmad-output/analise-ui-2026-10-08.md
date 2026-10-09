# Análise de aderência da UI — Maanaim

Data: 08/10/2026. Escopo: implementação local comparada à proposta inicial.

## Parecer

**Não, as telas não estão integralmente de acordo com a proposta inicial.** Há uma base visual institucional consistente, mas a composição das páginas, a navegação por perfil e algumas jornadas divergem significativamente do desenho. Também há problemas objetivos de contraste.

Esta é uma análise documental e de código, com execução de testes de widgets existentes. A imagem normativa foi inspecionada. Não houve navegação autenticada nem comparação de screenshots das telas executando no navegador; portanto, isto não constitui homologação visual de todas as telas, estados ou tamanhos.

## Referências e precedência

- `planning-artifacts/ux/SCREEN-SPECS.md`: inventário S01–S14.
- `planning-artifacts/ux/UX-LAYOUT-SPEC.md`: composição e responsividade.
- `planning-artifacts/ux/DESIGN-SYSTEM.md`: tokens e linguagem visual.
- `planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md`: regras de aplicação e precedência.
- `planning-artifacts/ux/references/maanaim-ui-reference.png`: referência visual inspecionada.
- `planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/{DESIGN,EXPERIENCE}.md`: identidade e jornadas.
- `specs/spec-gestao-voluntarios-maanaim/SPEC.md`: limites funcionais, especialmente documentos por participação e privacidade.

As referências acima são relativas a `_bmad-output/`. Os caminhos de código abaixo são relativos à raiz do projeto. Números de linha correspondem à versão inspecionada.

Não considero defeitos a ausência de contagens fictícias, a não exposição de rejeição ao voluntário ou a geração de PDF por equipe. Os contratos funcionais e de segurança prevalecem sobre esses elementos da imagem.

## Matriz das telas previstas

| Tela | Aderência observada | Evidência / diferença principal |
|---|---|---|
| S01 Login | Parcial | Estrutura 50/50, marca e formulário compacto implementados. Painel usa gradiente, contrariando a regra visual; Google é botão habilitado sem autenticação. `lib/ui/identidade.dart:23`; `lib/main.dart:1007`. |
| S02 Início do voluntário | Composição prevista ausente | Entrada abre Minha Ficha. Navegação oferece apenas esse item; não há dashboard com KPIs e cartão de validade/progresso previsto. `lib/main.dart:458`; `lib/features/voluntario/minha_ficha_screen.dart:404`. |
| S03 Nova solicitação de equipe | Divergente | Seleção inicial usa chips na ficha; solicitação adicional usa modal de seleção única. Não foi encontrada a jornada visual Seleção → Termo → Revisão → Envio, nem grid de cartões com ícones. `lib/features/voluntario/minha_ficha_screen.dart:819`; `lib/features/voluntario/solicitar_equipe_modal.dart:95`. A seleção única adicional não equivale a defeito na seleção múltipla inicial. |
| S04 Dashboard Pastor Local | Divergente | Existe fila com filtro de igrejas e cartões, inclusive no desktop. Faltam os quatro KPIs e a tabela de pendências com ação Analisar. `lib/features/pastor/fila_pastor_screen.dart:341`. |
| S05 Análise da ficha | Jornada prevista não integrada à fila | Na fila pastoral, cartões oferecem Aprovar/Recusar diretamente, abrindo confirmações; não há ação Analisar conduzindo à composição identidade/documentos/equipes/decisão. Existe consulta separada de ficha e histórico, mas ela não substitui esse percurso. `lib/features/pastor/fila_pastor_screen.dart:453`; `lib/features/voluntario/consulta_ficha_screen.dart:205`. |
| S06 Dashboard Coordenador | Divergente | Tabela desktop e cartões mobile existem. Faltam KPIs e filtro temporal; colunas diferem do previsto, sem a apresentação solicitada “2 de 3” e data de envio. Acesso direto usa Scaffold com topbar navy, sem AppShell. `lib/features/coordenador/fila_coordenador_screen.dart:740` e `:848`. |
| S07 Administração de igrejas | Incompleta frente ao desenho | Catálogo reúne igrejas e equipes em listas. Busca e inativação/reativação existem; não há Nova igreja, edição, filtro de situação ou coluna do Pastor Local nessa superfície. `lib/features/admin/consulta_catalogo.dart:163` e `:303`. |
| S08 Vincular igrejas ao pastor | Fluxo diferente | Implementado por igreja/equipe, com atribuição/substituição individual e histórico. Não existe a composição centrada no pastor, busca com checkboxes e painel de igrejas selecionadas. `lib/features/admin/vinculos_responsaveis.dart:173` e `:331`. Isso é uma diferença em relação ao desenho; a gestão individual já aparece descrita em artefatos de implementação. |
| S09 Minha Ficha | Parcial / adaptação funcional | Existe ficha editável e consulta de dados, participações e histórico, com acesso a documento por equipe. Não há preview desktop do documento na composição S09. PDF separado por participação deve ser preservado conforme SPEC, sem copiar literalmente o PDF consolidado da imagem. `lib/features/voluntario/minha_ficha_screen.dart:513`; `lib/features/voluntario/consulta_ficha_screen.dart:205`. |
| S10 Renovação do voluntário | Parcial | Há escolha por equipe e informação de vigência; usa diálogo, sem stepper. Uma escolha de não continuar abre outro diálogo sobre o primeiro, contrariando EXPERIENCE. `lib/features/voluntario/manifestar_renovacao_dialog.dart:28` e `:65`. |
| S11 Gestão de equipes | Incompleta frente ao desenho | Lista no catálogo, com ativação/inativação. Nova equipe, edição e responsável não compõem a tela; vínculos ficam em outra área. `lib/features/admin/consulta_catalogo.dart:240` e `:327`. |
| S12 Auditoria | Parcial | Há tabela/cartões e carregamento incremental. A UI filtra somente ação; faltam os controles previstos de período, usuário e entidade. Exibe UID, Command ID e nomes técnicos. `lib/features/auditoria/auditoria_relatorios_screen.dart:49`, `:181` e `:296`. |
| S13 Termos | Parcial, próxima da intenção | Há publicação com confirmação, termo vigente, histórico e visualização. Lista histórica privilegia versão/título/hash; não apresenta a visão prevista de aceites pendentes e publicação por linha. `lib/features/admin/termos_screen.dart:253` e `:535`. |
| S14 Relatórios | Parcial | Contagens e resultados em tabela/cartões existem. Consulta utiliza FiltrosRelatorio vazio; não há controles para equipe, igreja, situação, período, pastor, voluntário e ano, nem paginação de resultados nessa UI. `lib/features/auditoria/auditoria_relatorios_screen.dart:87` e `:513`. Exportação é futura na própria especificação, portanto não foi apontada como falta. |

Os caminhos `lib/` da matriz estão dentro de `flutter_app/`.

## Achados prioritários

### 1. Alta — Entrada por perfil não conduz pastores às próprias filas

`flutter_app/lib/main.dart:353`: `_resolverPerfil` distingue administrador, coordenador e voluntário. Não há resolução para Pastor Local ou Responsável de Equipe. As respectivas filas estão acessíveis no AdminShell, mas um usuário somente pastoral cai em Minha Ficha pelo percurso principal inspecionado.

Impacto: uma tela pode existir no código e continuar indisponível na jornada de seu público. Corrigir o roteamento e a navegação respeitando os vínculos e a autorização do servidor.

### 2. Alta — Contraste insuficiente em componentes compartilhados

Valores calculados diretamente das cores sRGB do código, sem dependência de screenshot:

| Par | Contraste aproximado |
|---|---:|
| Texto verde `#16A34A` / chip `#EAF8EF` | 3,01:1 |
| Texto âmbar `#F59E0B` / chip `#FFF6DE` | 1,99:1 |
| Texto vermelho `#EF4444` / chip `#FDECEC` | 3,29:1 |
| Texto branco / botão verde `#16A34A` | 3,30:1 |
| Texto branco / botão vermelho `#EF4444` | 3,76:1 |

Os textos pequenos utilizados nesses componentes precisam de 4,5:1 para o requisito AA do projeto. O uso literal dos tokens recomendados não basta: acessibilidade tem precedência. Criar tons de texto/ação mais escuros, preservando a família de cores e os fundos suaves.

Evidência: `flutter_app/lib/ui/components/status_chips.dart:47`, `flutter_app/lib/ui/components/buttons.dart`, `flutter_app/lib/ui/tokens.dart`. A borda dos inputs também usa o mesmo token decorativo claro, sem a distinção de contraste prevista no DESIGN.md; sua combinação com branco resulta em aproximadamente 1,29:1.

### 3. Alta — Dashboards e análise perderam a hierarquia proposta

Voluntário, Pastor Local e Coordenador não recebem os dashboards S02/S04/S06. Componentes MetricCard e ProgressValidityCard existem, mas o cartão de progresso não está integrado às telas principais inspecionadas. Na fila pastoral, a decisão antecede o percurso de análise detalhada previsto.

Impacto: menos clareza sobre próxima ação, vigência e volume de pendências; análise depende de informação resumida. Recompor dashboards com dados reais e ligar Analisar ao detalhe autorizado.

### 4. Média — AppShell não é consistente entre áreas

Administração e Minha Ficha usam AppShell. Coordenador e Editar Perfil usam Scaffold próprio com cabeçalho escuro; as filas pastoral e de equipe também têm Scaffold próprio. Dentro da administração, essas filas ficam sob o shell externo; no acesso direto ao coordenador, a sidebar desaparece.

Evidência: `flutter_app/lib/features/admin/admin_shell.dart:252`; `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart:848`; `flutter_app/lib/features/perfil/editar_perfil_screen.dart:329`.

### 5. Média — Identidade visual e linguagem têm desvios concretos

- Gradiente no painel de acesso: `flutter_app/lib/ui/identidade.dart:27`.
- Roxo `#6D28D9` / `#F3E8FF` no painel de solicitações: `flutter_app/lib/features/admin/painel_solicitacoes_pendentes_screen.dart:125` e `:138`, apesar da proibição explícita no Design System.
- Menu “Seed”, cabeçalho com “AD-8, AD-9, AD-12” e filtro que pede `DECISAO_PASTOR_LOCAL`: linguagem de implementação em superfícies do produto. `flutter_app/lib/features/admin/admin_shell.dart:95`; `flutter_app/lib/features/auditoria/auditoria_relatorios_screen.dart:196` e `:607`.
- Login Google habilitado apenas mostra indisponibilidade: `flutter_app/lib/main.dart:1007`. A referência permite a opção quando habilitada; DESIGN.md explicitamente proíbe reproduzi-la sem implementação.

### 6. Média — Garantia responsiva ainda é insuficiente

Os testes executados cobrem shell, componentes e login, mas não homologam todas as páginas. Há padrões a verificar com conteúdo realista: ListTile de catálogo com ações no trailing, título e dropdown da fila pastoral na mesma Row e rodapé da renovação com dois botões lado a lado. Estes são riscos de compressão/overflow, não falhas visuais reproduzidas nesta análise.

Verificar 320/390 px, tablet e desktop, texto a 200%, nomes longos, teclado e foco nos diálogos. Também verificar se os seletores customizados anunciam seleção pelo leitor de tela.

## Superfícies adicionais

- Cadastro e recuperação: usam a moldura de acesso; recuperação permanece integrada ao login. Não há tela S própria para cada uma no pacote original.
- Editar Perfil: segue a paleta, mas perde o shell e usa cabeçalho navy.
- Fila do Responsável de Equipe: cartões e filtros, com a mesma fragmentação de shell das demais filas.
- Pessoas e Papéis: reutiliza PageHeader/componentes e fica no shell administrativo; requer validação visual própria em mobile.
- Solicitações por Equipe: organização adicional útil, mas introduz roxo fora da identidade.
- Dashboard de Renovação e Retenção/Privacidade: reutilizam métricas e tokens; são superfícies adicionais, não substituem os dashboards S02/S04/S06.
- Cancelamentos, reativação, aceite de termo e demais diálogos: não há equivalência um a um com S01–S14. Não foram homologados visualmente em todos os estados nesta análise.

## Aspectos alinhados

- Paleta institucional e geometria centralizadas em tokens.
- ThemeData customizado, em vez de Material sem identidade própria.
- AppShell com sidebar desktop, modo compacto tablet e drawer mobile.
- Componentes compartilhados de ação, cards, chips, métricas e listas responsivas.
- Status com texto e ícone; várias telas incluem loading, vazio, erro e retentativa.
- Participações e renovações apresentadas por equipe, preservando a intenção funcional.

## Verificação realizada

Comando executado em `flutter_app/`:

```sh
flutter test test/layout_referencia_test.dart test/acesso_inclusivo_responsivo_test.dart test/ui/theme_tokens_test.dart test/ui_components_test.dart
```

Resultado: **41 testes passaram**. O bloqueio inicial de escrita no cache do SDK foi resolvido pela execução autorizada fora do sandbox.

`layout_referencia_test.dart` verifica login sem overflow em 320×568 e 1440×900 com texto ampliado; não compara imagens com a referência. Não foram encontrados testes `matchesGoldenFile` na busca feita em `flutter_app/test`. Os testes de foco verificam propriedades de tema, não o percurso completo por teclado. Logo, a aprovação desses testes não prova fidelidade visual nem conformidade AA completa.

## Ordem recomendada de correção

1. Corrigir entrada e navegação dos perfis pastorais, contraste e opção Google sem implementação.
2. Uniformizar AppShell e implementar a hierarquia dos dashboards com informações reais.
3. Integrar o detalhe de análise às filas e recuperar as etapas visuais de solicitação/renovação.
4. Completar as superfícies administrativas e filtros de auditoria/relatórios.
5. Remover gradiente/roxo/jargão desnecessário e consolidar os artefatos de design.
6. Homologar todas as telas por screenshots e navegação nos três tamanhos, incluindo estados e acessibilidade.

Há divergência também entre documentos: DESIGN.md legado cita paleta/raios e escala Material diferentes do pacote normativo. A regra de precedência ajuda, mas os documentos devem convergir para evitar que novas implementações repitam a fragmentação.

Nenhum código de aplicação foi alterado nesta análise.

# WP-06 — Auditoria Final de UI/UX e Aceite

**Story:** `STORY-UX-REF-001`  
**Agentes:** Sally — UX Designer BMAD; workflow técnico `bmad-code-review` em quatro camadas  
**Data:** 12/10/2026  
**Status recomendado:** **não aprovar ainda; correções obrigatórias e nova inspeção visual focal**  
**Escopo:** validação visual e de experiência após WP-02 a WP-05, sem alteração de produto nesta etapa.

## 1. Base e método

A persona Sally foi ativada pela instalação real do projeto, usando:

```text
UV_CACHE_DIR=/private/tmp/uv-cache-wp06 uv run _bmad/scripts/resolve_customization.py \
  --skill .agents/skills/bmad-agent-ux-designer --project-root . --key agent
```

Foram lidos integralmente `DESIGN-SYSTEM.md`, `UX-LAYOUT-SPEC.md`, `SCREEN-SPECS.md` e `DESIGN-RULES-FOR-AGENTS.md`, e a composição foi comparada com `references/maanaim-ui-reference.png`. A referência estabelece sidebar navy, topbar clara ou texto claro quando navy, conteúdo sóbrio e denso, azul para ação primária, semântica de estado acompanhada por texto, cards moderados e tabelas adaptadas sem perda de ação.

As capturas foram produzidas a partir do Flutter Web real com gateways em memória, por meio do harness temporário `flutter_app/wp06_harness`. O harness monta os widgets reais e não é parte do produto. Capturas uniformemente brancas/cinzas foram consideradas inválidas, não evidência.

## 2. Evidências visuais inspecionadas

| Arquivo | Viewport | Perfil / estado | Resultado da inspeção |
|---|---:|---|---|
| `pastor_cheia_390x844.png` | 390×844 | Pastor Local / fila preenchida | Válida. Hierarquia, KPIs, seletor de igreja, status e ação primária legíveis; sem overflow horizontal visível. |
| `pastor_filtro_vazio_390x844.png` | 390×844 | Pastor Local / filtro Renovação ativo sem resultados | Válida. Filtro ativo e ação `Limpar filtro` estão evidentes; mensagem vazia é genérica e não nomeia o filtro. |
| `pastor_modal_aprovar_360x800.png` | 360×800 | Pastor Local / confirmação de aprovação | Válida. Modal contextual, rolável, ações verticais e alvos adequados; sem truncamento visível. |
| `responsavel_cheia_768x1024.png` | 768×1024 | Responsável de Equipe / fila preenchida | Válida. Cards adaptados, três ações diferenciadas e conteúdo legível; sem overflow visível. |
| `coordenador_cheia_1024x768.png` | 1024×768 | Coordenador / fila preenchida | Válida e **não conforme**: contraste do título na topbar e tabela cortada à direita. |
| `pastor_detalhe_768x1024.png` | 768×1024 | Pastor Local / análise da ficha | Válida. Contexto de pessoa, papel, estado, equipes e documentos é claro; decisão fica abaixo da dobra. |
| `voluntario_tablet_768x1024.png` | 768×1024 | Voluntário / ficha ativa e renovação | Válida e **não conforme**: KPI expõe o rótulo `Pendentes / Rejeitadas`. |
| `admin_inicio_1440x900.png` | 1440×900 | Administrador / shell inicial | Parcialmente válida: comprova identidade e agrupamento da navegação; gateway ausente impede validar a tela de Igrejas. |
| `admin_tablet_1024x768.png` | 1024×768 | Administrador / shell em altura reduzida | Parcialmente válida: comprova sidebar rolável/persistência de logout; conteúdo administrativo não foi montado. |
| `voluntario_ativa_360x800.png` | 360×800 | Voluntário / ficha ativa e renovação | Válida e **não conforme**: segundo card de equipe colapsa o título em uma coluna de caracteres e produz faixa amarela/preta de overflow. |

Os arquivos auxiliares `_raw.png` e `_t.png` e versões uniformes anteriores não integram o aceite.

## 3. Achados por severidade

### Alta — bloqueiam o aceite

| ID | Evidência | Divergência | Impacto / critério violado |
|---|---|---|---|
| UX-H01 | `voluntario_tablet_768x1024.png` | O dashboard mostra `Pendentes / Rejeitadas`, ainda que o valor seja zero. | Expõe ao voluntário uma categoria interna negativa. Viola `DESIGN-SYSTEM`, `UX-LAYOUT-SPEC` e a regra canônica de não revelar decisão negativa, estado interno ou contagem correspondente. Deve ser removida/substituída por linguagem permitida e reinspecionada. |
| UX-H02 | `coordenador_cheia_1024x768.png` | O título `Fila de Conclusão do Coordenador` é renderizado em texto escuro sobre topbar navy. | Falha visual evidente de contraste/legibilidade, incompatível com WCAG 2.2 AA e com a referência normativa. |
| UX-H03 | `coordenador_cheia_1024x768.png` | A tabela ultrapassa o viewport e é cortada à direita; conteúdo de Equipes e as ações não ficam integralmente disponíveis na captura. | Em 1024 px, breakpoint classificado como desktop, a ação operacional não pode desaparecer. Viola adaptação responsiva e o requisito de ausência de overflow/perda funcional. |
| UX-H04 | `voluntario_ativa_360x800.png` | O segundo card de equipe entra em colapso: o nome aparece em uma coluna com um caractere por linha e o Flutter exibe a faixa amarela/preta de overflow à direita. | Quebra severa em viewport obrigatório de 360 px, impede leitura/uso da participação e comprova overflow real. Viola mobile-first, legibilidade e ausência de overflow. |
| TEC-H01 | `ficha_documento_viewer_widget.dart` e `minha_ficha_screen.dart` | O novo viewer preenche identificador, telefone, e-mail, igreja/código, vigência, versão/aceite, aprovador e datas com valores sintéticos quando os registros persistidos não os fornecem. | Pode apresentar fatos pessoais e probatórios falsos como documento oficial. Viola a exigência de gerar documentos exclusivamente de registros/evidências persistidos. |
| TEC-H02 | `detalhe_solicitacao_screen.dart` | A UI injeta `FICHA_CADASTRAL` como disponível sem evidência do backend e oferece ações de abrir PDF/documento que terminam somente em `SnackBar`, sem recurso privado nem nova autorização. | Viola o contrato de documentos privados/autorizados e cria falsa disponibilidade de evidência. |
| TEC-H03 | `fila_coordenador_screen.dart` | Na ausência de métricas, a tela mostra valores fixos `623` ativos e `15` expirados. | Dados operacionais fictícios não podem ser apresentados como indicadores reais. |

### Média — requerem ajuste ou evidência complementar

| ID | Evidência | Divergência | Impacto / critério |
|---|---|---|---|
| UX-M01 | `pastor_filtro_vazio_390x844.png` | O banner identifica `Renovação Anual`, mas o estado vazio diz apenas `Nenhuma solicitação pendente`. | A proximidade do banner reduz a ambiguidade, porém a mensagem vazia deveria declarar que não há resultados **para o filtro ativo**, conforme o foco específico do WP-06. |
| UX-M02 | `admin_inicio_1440x900.png`, `admin_tablet_1024x768.png` | O harness exibe `Serviço de igrejas indisponível.` por não fornecer o gateway administrativo. | A captura comprova shell e agrupamentos, mas não valida tabela, filtros, `Nova igreja`, estados vazios ou ações administrativas. É lacuna de evidência, não defeito comprovado no produto. |
| UX-M03 | `admin_tablet_1024x768.png` | Parte das seções inferiores fica fora da dobra da sidebar e rótulos longos são elididos. | O código usa `ListView`, logo os itens são alcançáveis por rolagem, mas a descoberta é fraca e os rótulos completos/tooltip não foram comprovados visualmente. |
| UX-M04 | conjunto de evidências | Não há captura do Voluntário em 390 px, nem capturas de conteúdo nos 1440 px para os perfis operacionais. | Impede declarar cobertura integral dos cinco breakpoints e da hierarquia desktop de todos os perfis. |
| TEC-M01 | `detalhe_solicitacao_screen.dart` | O campo `Observação (opcional)` é exibido, mas seu controller não é lido nos comandos. | Entrada do usuário é descartada silenciosamente; não há teste que cubra propagação da observação. |
| TEC-M02 | `detalhe_solicitacao_screen.dart` | O breakpoint do detalhe foi reduzido de 1024 para 720 px. | Contraria o layout normativo para tablet e comprime a composição em 720–1023 px. |
| TEC-M03 | `ficha_documento_viewer_widget.dart` | `participacaoSelecionada` e `onSelecionarParticipacao` não determinam o conteúdo; todas as participações são mostradas. | Diverge do requisito de documento/PDF separado por participação aprovada. |
| TEC-M04 | `detalhe_solicitacao_screen.dart` | Cabeçalho fixo `Aguardando sua aprovação`, sem refletir estado, conflito ou elegibilidade. | Pode comunicar uma ação inexistente ou já indisponível. |
| TEC-M05 | `ficha_documento_viewer_widget.dart` | Indicador fixo `1 / 2`, impressão reutiliza callback de download e zoom não possui área rolável delimitada. | Semântica enganosa e risco de pintura fora do layout. |
| TEC-M06 | `minha_ficha_screen.dart` | Download do termo aparece apenas no caminho mobile e o estado de download não desabilita nova chamada. | Inconsistência desktop/mobile e possibilidade de submissões repetidas. |

### Baixa — polimento

| ID | Evidência | Divergência | Impacto |
|---|---|---|---|
| UX-L01 | `pastor_detalhe_768x1024.png` | Há duas affordances de retorno simultâneas: seta da appbar e `Voltar` no conteúdo. | Redundância visual leve; não impede a tarefa. |
| UX-L02 | `pastor_detalhe_768x1024.png` | O painel de decisão começa abaixo da dobra no tablet. | O contexto está correto e a ordem é compreensível, mas a decisão exige rolagem; recomenda-se apenas confirmar o fluxo completo após os bloqueadores. |
| TEC-L01 | `ficha_documento_viewer_widget.dart` | Controles de zoom medem 32×32 px. | Ficam abaixo do alvo mínimo de 44 px definido pelo projeto. |
| TEC-L02 | `inicio_voluntario_screen.dart` | Há cor vermelha literal em vez do token canônico `AppColors.danger`. | Pequena quebra de consistência do Design System. |

## 4. Conformidades observadas

- Identidade navy/azul, superfícies claras, bordas discretas e radius moderado são consistentes com a referência.
- Pastor em 390 px converte a fila para cards; Responsável em 768 px mantém ações legíveis e sem compressão impraticável.
- `Analisar` aparece como ação primária azul; aprovar e recusar preservam semântica verde/vermelha e texto/ícone.
- O modal pastoral em 360 px identifica voluntário, igreja, equipes e consequência da ação; botões são empilhados e têm altura de toque adequada.
- O filtro ativo do Pastor possui borda/estado selecionado, banner textual e `Limpar filtro`; não depende somente de cor.
- A análise pastoral mostra inequivocamente pessoa, etapa, igreja, equipes, documentos e papel decisor.
- O shell administrativo usa agrupamentos `Cadastros`, `Operação` e `Administração`, alinhado ao refinamento de WP-02.
- Não foram observados gradientes decorativos, glassmorphism, paleta estranha ou sombras pesadas.

## 5. Matriz de conformidade dos critérios de aceite

| Critério WP-06 | Estado | Evidência / ressalva |
|---|---|---|
| Aplicação Flutter Web executada e telas reais inspecionadas | Parcial | Pastor, Responsável, Coordenador, Voluntário, análise e shell Admin foram renderizados; o Admin não recebeu gateway funcional. |
| Comparação com referência e quatro documentos normativos | Conforme | Comparação executada; divergências registradas neste relatório. |
| Navegação administrativa | Parcial | Agrupamentos e sidebar comprovados; destinos/conteúdo administrativo não foram exercitados. |
| Hierarquia dos dashboards | Não conforme | Coordenador apresenta contraste incorreto; Voluntário expõe categoria proibida. |
| Ações de análise e decisão | Parcial | Pastor e Responsável comprovados; ações do Coordenador estão cortadas no viewport 1024. |
| Estados vazios com filtro ativo | Parcial | Estado existe e filtro está visível, mas a microcopy vazia não é específica ao filtro. |
| Modais | Conforme na amostra | Modal de aprovação pastoral em 360 px é contextual, legível e adaptado. Outros modais não foram capturados. |
| 360 px | Não conforme | Modal Pastor válido; Voluntário apresenta overflow severo UX-H04. |
| 390 px | Conforme na amostra | Pastor cheio e filtro-vazio válidos. |
| 768 px | Conforme com ressalva | Responsável e análise Pastor válidos; Voluntário tem violação UX-H01. |
| 1024 px | Não conforme | Coordenador falha contraste e largura; Admin apenas parcial. |
| 1440 px | Parcial | Shell Admin validado, conteúdo principal indisponível no harness. |
| Contraste e legibilidade | Não conforme | UX-H02. Demais amostras apresentam leitura adequada. |
| Foco de teclado e ordem de tabulação | Parcial / não comprovado interativamente | O navegador de automação não pôde ser inicializado (`app-server` ausente). Captura estática e testes não substituem inspeção de foco; deve haver roteiro/registro de teclado. |
| Semântica dos controles | Parcial / não comprovado interativamente | Texto e ícones são claros nas capturas, mas árvore semântica/leitor de tela não foi inspecionada nesta sessão. |
| Alvos de toque ≥44 px | Conforme visualmente na amostra | Botões, seletor, cards filtráveis e modal aparentam cumprir o mínimo; medição automatizada completa não foi anexada. |
| Ausência de overflow | Não conforme | Corte da tabela do Coordenador em 1024 px e overflow explícito no Voluntário em 360 px. |
| Capturas reais identificadas | Conforme para o lote | Arquivos válidos identificam perfil/estado/viewport; tentativas uniformes anteriores foram descartadas e recapturadas. |
| `flutter analyze` e `flutter test` | Conforme | `flutter analyze`: **PASS**, `No issues found` em 4,1 s. `flutter test`: **PASS**, 445/445 em 49 s. Esses resultados não anulam falhas visuais reais. |
| Diff sem mudanças indevidas de negócio/contratos | Não conforme | Revisão BMAD em quatro camadas: não houve alteração de backend, Firebase, regras de segurança, interfaces de gateway, `commandId` ou `expectedVersion`; porém houve violação grave do contrato de dados/evidência e inclusão de comportamento documental novo fora do escopo. |

## 6. Revisão técnica do diff acumulado

O workflow instalado `bmad-code-review` revisou o intervalo dos quatro commits de refinamento (`6167fb9..9997355`) com as camadas Blind Hunter, Edge Case Hunter, Verification Gap e Acceptance Auditor. O recorte contém somente frontend e testes; não altera backend, regras Firebase, permissões ou interfaces de gateway, e preserva os mecanismos de decisão `commandId` e `expectedVersion`.

Isso não torna o diff aceitável. Foram confirmadas violações de contrato no frontend: fabricação de dados pessoais/probatórios e KPIs, indicação de documentos inexistentes, falta de autorização/leitura real de PDF, descarte silencioso de observação e falta de escopo por participação. Assim, a restrição “sem novas funcionalidades” e o princípio de evidências exclusivamente persistidas não foram respeitados.

## 7. Lacunas explícitas de evidência

Não é possível declarar, com o lote atual:

1. conformidade do Voluntário em 390 px e correção do overflow já comprovado em 360 px;
2. funcionamento visual de Igrejas, Equipes, Pessoas/Papéis, Vínculos, Termos, Auditoria/Relatórios e Retenção no Admin;
3. foco visível e ordem completa por teclado;
4. anúncio por leitor de tela e nomes acessíveis dos controles;
5. estado de erro, loading e sem permissão em todos os perfis;
6. modais de recusa/justificativa e demais ações críticas;
7. ausência de overflow após rolagem no painel de decisão e em todas as tabelas.

## 8. Recomendação de aceite

**Recomendação: correções necessárias antes do aceite da `STORY-UX-REF-001`.**

O produto mostra uma identidade visual consistente e os refinamentos de navegação, filtros, ações e modais são perceptíveis. Porém, sete achados altos bloqueiam o aceite: os quatro defeitos visuais acima e três violações técnicas envolvendo dados/evidências sintéticas, falsa disponibilidade documental e KPIs fictícios. Eles afetam segurança de informação, confiabilidade, acessibilidade e execução da tarefa principal.

Após correção estritamente visual desses pontos, executar uma reinspeção focal com:

- Voluntário em 360 e 390 px, confirmando linguagem permitida;
- Coordenador em 1024 e 1440 px, confirmando contraste e acesso integral às ações;
- ao menos uma tela administrativa funcional em 1024 e 1440 px;
- estado vazio filtrado com mensagem específica;
- registro de teclado/foco nos fluxos principais.
- remoção de todos os fallbacks sintéticos e comprovação de documento privado autorizado por participação;
- métricas ausentes tratadas como indisponíveis, nunca como números fictícios.

Não encerrar a Story até aprovação explícita do usuário após essa evidência complementar.

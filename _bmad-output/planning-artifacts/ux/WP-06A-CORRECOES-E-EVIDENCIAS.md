# WP-06A — Correções e evidências das não conformidades bloqueantes

Data: 13/10/2026  
Story: `STORY-UX-REF-001`  
Estado: **correções implementadas; Story aberta e aguardando aprovação explícita**

## 1. Diagnóstico de origem

O intervalo da Story auditada é `6167fb9..9997355`, composto por `1493fc9`, `fa32738`, `41a529e` e `9997355`.

| Achado | Origem confirmada | Classificação | Arquivos responsáveis |
|---|---|---|---|
| UX-H01 | `1493fc9` adicionou `Pendentes / Rejeitadas`, estados negativos visíveis e tratamento visual de espera para decisão negativa. | Introduzido pela Story | `inicio_voluntario_screen.dart`; exposição repetida em `minha_ficha_screen.dart` e `ficha_documento_viewer_widget.dart` |
| UX-H02 | A topbar do Coordenador já existia desde `374a539`; o estilo global escuro veio de `a8f471f`. A Story não criou a causa. | Preexistente | `fila_coordenador_screen.dart`, `theme.dart` |
| UX-H03 | A tabela larga e as ações já existiam desde `374a539`/`b63ca2c`; `1493fc9` ampliou densidade/conteúdo e agravou o corte. | Preexistente, agravado pela Story | `fila_coordenador_screen.dart` |
| UX-H04 | `1493fc9` reestruturou o card em linhas rígidas e reuniu status, renovação e ações sem quebra segura em 360 px. | Introduzido pela Story | `inicio_voluntario_screen.dart` |
| TEC-H01 | `1493fc9` criou o viewer com fallbacks pessoais e probatórios sintéticos. | Introduzido pela Story | `ficha_documento_viewer_widget.dart`, `minha_ficha_screen.dart` |
| TEC-H02 | `1493fc9` injetou `FICHA_CADASTRAL` e disponibilidade fictícia; a ação genérica que terminava em `SnackBar` já existia desde `390c4fc`. | Misto: Story + preexistente | `detalhe_solicitacao_screen.dart` |
| TEC-H03 | `1493fc9` incluiu os valores fixos `623` e `15`. | Introduzido pela Story | `fila_coordenador_screen.dart` |

## 2. Contratos normativos confirmados

- Documentos/evidências: `SPEC.md` linhas 49–60, `ARCHITECTURE-SPINE.md` AD-6, AD-12 e AD-13, `SCREEN-SPECS.md` S05/S09 e `UI-CONTRACTS.md` linhas 71–77. PDF é privado, individual por participação aprovada, derivado apenas de registros/evidências persistidos e reautorizado a cada acesso.
- Métricas: `UI-CONTRACTS.md` linhas 15–21 e 35–39. Valor incompleto/ausente deve aparecer como `Indisponível`, nunca como zero ou número inventado; zero real continua zero.
- Mensagem ao voluntário: `UI-CONTRACTS.md` linha 73. Texto exato: “Procure o Pastor da igreja local para mais informações”, sem estado interno, motivo ou ator.
- S06: `SCREEN-SPECS.md` linhas 45–50. Colunas normativas: Voluntário, Igreja, Equipes aprovadas, Enviado em e Ações.

## 3. Correções por arquivo

| Arquivo | Correção |
|---|---|
| `lib/features/voluntario/inicio_voluntario_screen.dart` | Removeu categoria negativa dos KPIs; usa somente a mensagem canônica; remove `Em tramitação` e ícone de espera do caso negativo; reorganizou cabeçalho/status/ações com quebra responsiva abaixo de 560 px. |
| `lib/features/voluntario/minha_ficha_screen.dart` | Removeu fallbacks sintéticos e duplicações da mensagem; a orientação negativa aparece uma única vez no contexto de acompanhamento. |
| `lib/features/voluntario/ficha_documento_viewer_widget.dart` | Removeu identificador, contato, igreja, vigência, aceite, aprovador e datas inventados; campos ausentes são omitidos ou apresentados como `Não disponível`; o viewer não simula estado probatório negativo; impressão/download são omitidos quando não existe callback autorizado; `vigenciaInicio` é rotulado como início de vigência, não como data de aprovação. |
| `lib/features/coordenador/fila_coordenador_screen.dart` | Fixou título branco sobre navy; usa cards completos em 1024 px e tabela normativa em 1440 px; preserva as três ações; métricas ausentes mostram `— / Indisponível`, enquanto zero persistido continua `0 participações`; atualização limpa valores antigos e ignora respostas assíncronas obsoletas. |
| `lib/features/analise/detalhe_solicitacao_screen.dart` | Removeu `FICHA_CADASTRAL` sintética e botões sem recurso; documentos sem consulta autorizada mostram indisponibilidade contextual; lista vazia não oferece ação falsa. |
| `test/*.dart` | Adicionou regressões específicas para UX-H01–H04 e TEC-H01–H03, geometria 1024/1440 e navegação por teclado. |
| `wp06_harness/*` | Harness de evidência conectado às telas reais com gateways em memória; registros são explicitamente rotulados como dados de validação. |

Nenhum arquivo de backend, Firebase, gateway, permissão ou regra de negócio foi alterado.

## 4. Evidências visuais

As imagens são capturas do Flutter Web renderizado pelo harness local; dados operacionais não foram fabricados como reais — as fixtures visíveis são rotuladas como validação.

- [Voluntário — 360 × 800](WP-06A-evidence/voluntario_ativa_360x800.png)
- [Voluntário — 390 × 844](WP-06A-evidence/voluntario_ativa_390x844.png)
- [Coordenador — 1024 × 768](WP-06A-evidence/coordenador_cheia_1024x768.png)
- [Coordenador — 1440 × 900](WP-06A-evidence/coordenador_cheia_1440x900.png)
- [Administração funcional — 1440 × 900](WP-06A-evidence/admin_funcional_1440x900.png)
- [Estado vazio com filtro Renovações ativo — 390 × 844](WP-06A-evidence/pastor_filtro_vazio_390x844.png)
- [Evidência de foco e teclado](WP-06A-evidence/FOCUS-KEYBOARD-EVIDENCE.md)

A primeira captura de Voluntário em 360 px ficou em branco durante o primeiro carregamento; foi descartada e substituída por nova captura válida. Os logs não registram overflow/erro Flutter; mensagens GCM do Chrome headless são ambientais e não pertencem ao aplicativo.

## 5. Verificação

- `flutter analyze`: **PASS — No issues found**.
- `flutter test`: **PASS — 456/456**.
- Regressões focais finais inspecionadas pela UX Designer: **47/47**.
- `git diff --check`: **PASS**.
- Foco/teclado: eventos `Tab` alcançam Analisar, Recusar e Homologar/Ativar em 1024 px. A inspeção visual interativa não foi fabricada: o `codex app-server` não iniciou, e a limitação está registrada na evidência.
- Gate final da UX Designer (Sally): **PASS** para os sete achados altos.

## 6. BMAD Code Review

**Gate final: PASS para os sete achados altos. Nenhum bloqueante permaneceu no diff.**

O review encontrou e levou à correção de:

- impressão sem recurso autorizado no viewer (TEC-H02);
- métricas antigas após falha e respostas assíncronas fora de ordem (TEC-H03);
- estados terminais contados como `Em aprovação`;
- rótulo ambíguo da data de início da vigência;
- fixture de teste contaminada por participação de outra ficha.

Limitação registrada do workflow: Blind Hunter concluiu; Edge Case Hunter foi interrompido após espera prolongada e as lentes Verification Gap/Acceptance Auditor não foram executadas por limite de concorrência/tempo. A triagem foi complementada diretamente contra SPEC, Architecture Spine e restrições do WP-06A.

## 7. Observações fora do escopo

Sem correção automática neste WP-06A:

- Texto complementar longo no chip de equipe fica truncado na captura de 1440 px, sem ocultar equipe, proporção ou ações.
- O ícone de atualizar da topbar navy permanece escuro; UX-H02 tratava especificamente o título.
- Linha desktop do Coordenador limitada a 220 px pode exigir representação adaptativa para quantidade excepcional de equipes.
- Controles de zoom do viewer preservam alvo de 32 × 32 px; a adequação a 44 px não fazia parte dos sete altos.
- Estados terminais distintos de rejeição na tela Minha Ficha exigem delimitação própria para diferenciar cancelamento do voluntário e decisão de liderança.
- A fixture `CANCELADA_COORDENADOR` do teste do viewer não pertence ao modelo canônico e deve ser saneada em trabalho separado.

Esses pontos são não bloqueantes para os sete achados altos e exigem autorização separada caso se deseje tratá-los.

## 8. Decisão pendente

O WP-06A está preparado para avaliação. **A Story `STORY-UX-REF-001` não foi encerrada e permanece aguardando aprovação do usuário.**

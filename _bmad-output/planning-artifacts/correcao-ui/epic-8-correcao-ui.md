# Épico 8 — Aderência visual e conclusão das jornadas de UI

Status: adotado em 08/10/2026; épico in-progress. História documental 8.1 em review em 09/10/2026; 8.2–8.16 permanecem backlog. Origem: [proposta de correção](../sprint-change-proposal-2026-10-08.md). Este backlog complementa as histórias concluídas; não substitui seus contratos de domínio.

Objetivo: usuários de cada perfil alcançam e concluem as jornadas previstas, com aparência institucional consistente, acessibilidade e dados autorizados.

## Regras comuns de aceite

Cada história de tela deve declarar e verificar mobile (<600), tablet (600–1023) e desktop (≥1024), usando constraints da área disponível. Coluna única no mobile, tabelas em cartões e ação principal sem rolagem horizontal. Grids de seleção podem usar duas colunas apenas quando houver espaço suficiente.

Aplicar tokens/componentes existentes; documentar novos componentes. Cada consulta tem loading, vazio, erro com recuperação e acesso negado quando aplicável; cada mutação tem processamento, sucesso persistido e conflito. Tratar indisponibilidade de rede sem simular conclusão nem repetir silenciosamente ação crítica. Preservar conteúdo preenchido que possa ser mantido com segurança.

Capturas e testes usam dados sintéticos. WCAG 2.2 AA, texto ampliado, teclado, foco, nomes/seleções anunciados e alvos de 44 px fazem parte do aceite. Comparar hierarquia, densidade, espaçamento, cores, tipografia, sidebar/topbar, ações e estados com o pacote normativo. Cada história entrega evidência antes de done; 8.16 é a validação integrada, não o primeiro teste visual.

Todos os comandos permanecem autenticados no servidor, com vínculo/escopo/tempo/estado, versão esperada, idempotência e evidência/auditoria pertinentes. Não conceder papel por navegação ou por valores do cliente. PDF e histórico permanecem privados e autorizados.

## Ordem e dependências

| ID | História | Prioridade | Porte | Depende de |
|---|---|---|---|---|
| 8.1 | Contrato visual e inventário de dados | P0 | P | — |
| 8.2 | Tokens acessíveis e componentes | P0 | M | 8.1 |
| 8.3 | Contexto de acesso e rotas por capacidades | P0 | G | 8.1 |
| 8.4 | Shell único e acesso público | P0 | M | 8.2, 8.3 |
| 8.5 | Início do voluntário | P1 | M | 8.4 |
| 8.6 | Dashboards e filas dos responsáveis | P1 | G | 8.4 |
| 8.7 | Detalhe e decisão contextual | P1 | G | 8.6 |
| 8.8 | Solicitação em etapas | P1 | M | 8.5 |
| 8.9 | Renovação em etapas | P1 | M | 8.5 |
| 8.10 | Minha Ficha e documentos por participação | P1 | M | 8.5 |
| 8.11 | Administração completa de igrejas/equipes | P1 | G | 8.4 |
| 8.12 | Vínculos centrados no pastor | P1 | G | 8.11 |
| 8.13 | Auditoria e relatórios filtráveis/paginados | P1 | G | 8.4 |
| 8.14 | Termos e aceites pendentes | P2 | M | 8.4 |
| 8.15 | Superfícies adicionais e linguagem | P2 | P | 8.4 |
| 8.16 | Homologação integrada e prevenção de regressão | P1 | M | 8.1–8.15 |

P0 = acesso/fundação; P1 = fluxo ou capacidade prevista ausente/incompleta; P2 = consistência complementar. Porte é estimativa inicial, não estado de prontidão.

## 8.1 — Consolidar contrato visual e inventário de dados

Como equipe de produto e desenvolvimento, quero uma referência única e um mapa dos dados disponíveis para corrigir a UI sem decisões contraditórias.

**Antes → depois:** DESIGN.md legado, pacote ux/ e exemplos conflitantes → fontes convergentes, adaptações explícitas e contratos necessários identificados.

**Entregas:** atualizar documentos indicados na proposta; tabela tela → componente → gateway/callable → campos existentes/ausentes; definições de métricas e wireframes de composição mobile/desktop das telas modificadas. Registrar assets institucionais disponíveis e fonte do número de ficha.

**Aceite:**

1. Cada S01–S14 tem composição, estados e navegação definidos; fontes de dados ausentes viram tarefas da história correspondente.
2. Divergências de tokens, mensagem negativa, PDF, vigência, responsável único e Google são resolvidas por referência ao contrato, sem alterar ADs.
3. KPIs especificam entidade contada, escopo, período e atualização. Unidade aparece no rótulo/explicação, sem somar fichas e participações como iguais.
4. Experiência de vínculos múltiplos especifica resultados por item; nenhuma implementação pode prometer transação global inexistente.

**Validação:** conferência cruzada PRD/SPEC/ADs/UX e cobertura da matriz. Nenhuma alteração de código exigida.

## 8.2 — Corrigir tokens acessíveis e componentes compartilhados

Como usuário, quero ler e operar os controles em todos os estados sem depender apenas de cor.

**Antes → depois:** texto verde/âmbar/vermelho com baixo contraste → variantes semânticas acessíveis, mantendo a identidade.

**Áreas:** `flutter_app/lib/ui/{tokens,theme}.dart`, `ui/components/`, overrides locais identificados nas telas.

**Aceite:**

1. Texto normal alcança contraste ≥4,5:1; informação visual necessária de controles/foco atende ≥3:1 contra superfícies adjacentes aplicáveis. Bordas decorativas não são usadas como único contorno interativo.
2. Botões primary/secondary/approve/danger cobrem default, hover, focus, pressed, disabled e loading. Status têm texto e ícone.
3. Alvos interativos ≥44 px; textos de ações essenciais não desaparecem por ellipsis com fonte a 200%.
4. Inputs têm labels persistentes, erro associado e foco visível; seletores customizados expõem nome, papel e seleção.
5. Remover gradientes decorativos, roxo e substituições locais conflitantes; registrar pares de contraste no Design System.

**Validação:** cálculo dos pares reais, widgets com fonte ampliada/teclado e capturas de componentes. Não basta testar igualdade entre constantes.

## 8.3 — Resolver contexto de acesso e rotas por capacidades

Como pastor ou responsável com múltiplos vínculos, quero encontrar minhas áreas sem depender de acesso administrativo.

**Antes → depois:** resolução exclusiva admin/coordenador/voluntário → conjunto de capacidades e destinos autorizado pelo backend.

**Áreas:** `main.dart`, `features/auth/`, integração com fontes canônicas e consultas de vínculos em `functions/src/`.

**Aceite:**

1. Pastor Local e Responsável de Equipe sem papel administrativo alcançam suas filas e dashboards; vínculos simultâneos oferecem ambos os destinos.
2. Criar/reutilizar consulta autenticada de contexto mínimo, baseada em autoridade e vínculo vigente no servidor. Não ler dados administrativos amplos para descobrir o menu.
3. Administrador/coordenador com múltiplas capacidades não perde as áreas legítimas; o contexto da página é visível, sem seletor de autoatribuição.
4. Vínculo expirado ou revogado remove acesso após atualização; requisições já iniciadas continuam sujeitas à revalidação do backend. Negação não mostra dados antigos.
5. Rotas para detalhes suportam voltar/recarregar e deep link autorizado; estado de filtro preservado sem PII, tokens ou URL de PDF na URL da aplicação.
6. Sessão ausente, carregamento e erro de contexto têm estados explícitos, sem cair silenciosamente em uma tela de outro perfil.

**Validação:** matriz de cinco perfis, pastor local+equipe, múltiplos vínculos, revogação e chamadas diretas fora do escopo. Emulator para qualquer contrato novo de autorização.

## 8.4 — Aplicar shell único e corrigir acesso público

Como usuário, quero orientação consistente entre páginas e ações de login funcionais.

**Telas:** S01 e estrutura de todas as áreas, inclusive Editar Perfil.

**Aceite:**

1. Páginas autenticadas usam um único AppShell na árvore da rota: sidebar navy desktop, compacto tablet e drawer mobile; topbar clara, contexto e identidade reais.
2. Filas e perfil não criam barras/navegações duplicadas ao serem abertas dentro da administração.
3. Menu contextual apresenta destinos úteis sem itens duplicados; acesso a Minha Ficha, participação, renovação e documentos é encontrável conforme o público.
4. Login preserva composição 50/50 desktop e marca compacta mobile; remove Google/divisor sem integração e mantém cadastro/recuperação funcionando.
5. Substituir gradiente por imagem institucional adequada disponível ou fallback navy sólido documentado em 8.1.

**Validação:** navegação, voltar/recarregar, login/recuperação, três breakpoints e fonte ampliada; não alterar provisionamento de identidade/papéis.

## 8.5 — Construir início do voluntário

Como voluntário, quero entender minha situação e próxima ação sem percorrer o formulário completo.

**Telas:** S02; substitui a entrada automática exclusiva em Minha Ficha.

**Aceite:**

1. Saudação, número de ficha persistido quando disponível, estado permitido, KPIs, vigência e lista Minhas Equipes seguem a hierarquia da referência.
2. Se não houver número legível, documentar e implementar contrato estável no servidor ou apresentação sem número aprovada no UX; nunca usar UID como código exibido.
3. Voluntário sem ficha/rascunho encontra Continuar cadastro; enviado encontra acompanhamento; ativo encontra ações aplicáveis. Início e Minha Ficha continuam destinos distintos.
4. Validade/progresso vêm do ciclo persistido; equipes com vencimentos diferentes continuam explícitas. Próximo vencimento identifica sua equipe.
5. Nenhum indicador ou acessibilidade revela rejeição/motivo/ator interno. A mensagem neutra canônica permanece íntegra.
6. Abrir equipe leva a detalhe autorizado com ciclo e próxima ação; métricas reais não dependem da página atual da lista.

**Validação:** rascunho, aprovação parcial, duas equipes com datas diferentes, orientação pastoral e histórico preservado.

## 8.6 — Recompor dashboards e filas dos responsáveis

Como Pastor Local, Responsável de Equipe ou Coordenador, quero priorizar meu trabalho por indicadores e pendências do meu escopo.

**Telas:** S04/S06 e fila de equipe.

**Aceite:**

1. Pastor Local vê Pendências, Renovações, Ativos e Próximos do vencimento; “Todas as igrejas” agrega somente seus vínculos vigentes.
2. Equipe oferece visão equivalente por equipes autorizadas; Coordenador vê Aguardando aprovação, Renovações, Ativos e Expirados, com ano/período.
3. Tabela desktop contém identidade permitida, igreja/equipe, envio e Analisar; mobile oferece cartões com as mesmas informações e ação.
4. Coordenador vê proporção de equipes aprovadas/solicitadas para a solicitação/ciclo em análise; não mistura participações históricas nem ativa inelegíveis.
5. Reutilizar obterDashboardRenovacao onde aplicável e completar contratos para métricas gerais faltantes; escopo/filtros aplicados no servidor, limites/cursor/índices documentados.
6. Clique no KPI abre lista consistente com sua unidade e filtro. Estado vazio difere de indisponibilidade/negação; não renderizar zero em falha de consulta.

**Validação:** métricas sobre dataset maior que uma página, filtros múltiplos, ano/ciclo e vínculos revogados; snapshots desktop/mobile.

## 8.7 — Integrar detalhe da análise e decisão contextual

Como responsável, quero revisar dados e evidências antes de decidir sobre o alvo correto.

**Tela:** S05. Reutilizar `obterDetalheSolicitacao`, consulta de ficha e linha do tempo quando seus contratos atenderem ao escopo.

**Aceite:**

1. Analisar nas três filas abre detalhe com resumo autorizado à esquerda e equipes/documentos/decisão à direita; mobile empilha identidade → equipes → documentos → decisão.
2. Exibir apenas campos necessários e disponíveis; PDF de aprovação só quando existir participação elegível. Termo e comprovantes reais permanecem acessíveis conforme escopo.
3. Painel mostra ficha, participação/ciclo e etapa em decisão; confirmação resume consequência e justificativa aplicável.
4. Coordenador mantém confirmação da reunião e aceite autenticado. Ação por equipe não altera as demais.
5. Conflito/ABORTED recarrega o estado e exige nova análise; double tap/retry não duplica decisão. Conclusão só aparece após recibo/estado de conclusão conforme contrato.
6. Retorno à fila preserva filtro e atualiza o item; acesso revogado não mantém evidências sensíveis em tela.

**Validação:** cenário inicial/anual, aprovação e recusa, duas equipes independentes, decisão concorrente e vínculo substituído.

## 8.8 — Implementar solicitação de equipe em etapas

Como voluntário, quero selecionar, ler, revisar e enviar com clareza sobre o que será solicitado.

**Tela:** S03; serviços de ficha/participações/termo existentes.

**Aceite:**

1. Após validar dados obrigatórios, fluxo inicial oferece grid de equipes administráveis, seleção múltipla com check/borda/fundo e busca acessível.
2. Etapas Seleção → Termo → Revisão → Envio: conteúdo/versão real, aceite explícito, resumo de igreja/equipes/termo e retorno por participação.
3. Voltar preserva rascunho/seleção; termo atualizado exige novo aceite; envio inválido identifica o item a corrigir.
4. Inclusão adicional usa apresentação coerente, mantendo solicitação unitária e participações ativas intactas. Exibir termo/aceite aplicável sem fabricar novo aceite.
5. Stepper horizontal desktop e compacto mobile; ações não extrapolam largura, seleção anuncia estado ao leitor de tela.

**Validação:** duas equipes iniciais, termo trocado durante preenchimento, salvar/retomar, equipe inativa e duplicidade na inclusão posterior.

## 8.9 — Renovação em uma superfície com revisão

Como voluntário, quero escolher e revisar por equipe antes de confirmar o próximo ciclo.

**Tela:** S10.

**Aceite:**

1. Página no shell com etapas Escolhas → Revisão → Envio, sem diálogo abrindo sobre outro diálogo.
2. Mostrar vigência, prazo/janela e escolha explícita por equipe; decisão ainda não registrada não é silenciosamente tratada como “continuar”. Mostrar registro existente quando houver.
3. Revisão lista equipes que continuam e que encerram ao fim da vigência, com consequência clara antes de confirmar.
4. Janela fechada, conflito e acesso negado vêm do contrato do servidor; envio preserva ciclos anteriores e demais equipes.
5. Resultado apresenta cada desfecho autorizado e link ao acompanhamento, sem prometer renovação automática.

**Validação:** continuar numa equipe/não continuar em outra, nenhuma escolha, retomada, janela fechada, retry e navegação de teclado.

## 8.10 — Organizar Minha Ficha e documentos privados

Como voluntário ou responsável autorizado, quero consultar dados, histórico e documento correto da participação.

**Tela:** S09, consulta autorizada e acessos a edição.

**Aceite:**

1. Separar leitura da ficha/documentos de edição cadastral, com navegação clara e campos/histórico por escopo.
2. Seleção de participação/ciclo identifica qual termo/PDF será aberto; cada participação aprovada possui documento próprio conforme AD-13.
3. Desktop apresenta preview em painel neutro e Baixar PDF; mobile apresenta resumo e abrir/baixar. Falha do preview mantém alternativa de download autorizada.
4. Toda nova abertura/download reautoriza; URL expirada pode ser renovada por nova autorização. Documento/URL não entram em logs ou cache offline público da PWA.
5. Assinaturas refletem evidências persistidas; sem aprovação, mostrar indisponibilidade contextual, sem documento simulado.

**Validação:** duas equipes/dois PDFs, URL expirada, vínculo revogado, usuário alheio e preservação do fluxo de edição/histórico.

## 8.11 — Completar administração de igrejas e equipes

Como administrador, quero manter os catálogos e identificar os responsáveis atuais.

**Telas:** S07/S11. Origem: stories 1.2/7.2 e PRD §§44–51.

**Aceite:**

1. Destinos separados Igrejas/Equipes com título, busca, filtro de situação e Nova igreja/Nova equipe.
2. Desktop usa tabela e mobile cartões; igreja mostra nome/código/situação/Pastor Local; equipe mostra nome/situação/único responsável vigente; acesso a vínculos/histórico.
3. Cadastro/edição implementados por comandos autenticados, versão esperada, recibo/auditoria e ID opaco; código de igreja String único validado no servidor.
4. Inativar/reativar mantém o comportamento existente e histórico; sem exclusão física. Mudança de nome não reescreve snapshots de decisões anteriores.
5. Consulta administrativa retorna dados mínimos do responsável sem tornar PII pública no catálogo de seleção dos voluntários.
6. Seed permanece idempotente e não sobrescreve edições; sua ação recebe nome de produto claro em configuração administrativa.

**Validação:** CRUD permitido, código duplicado/concorrência, usuário não admin, escrita direta negada, busca/estado e reexecução de seed.

## 8.12 — Vincular múltiplas igrejas a partir do pastor

Como administrador, quero revisar igrejas e consequências antes de salvar vínculos de um pastor.

**Tela:** S08; extensão coerente para equipes, preservando acesso individual existente.

**Aceite:**

1. Identidade do pastor, lista pesquisável com checkboxes e painel das selecionadas; duas colunas desktop e seções empilhadas mobile.
2. Revisão mostra inclusões, encerramentos e substituições, responsáveis atuais, data efetiva e pendências afetadas. Remover seleção não encerra vínculo sem confirmação explícita.
3. Cada item valida vínculo vigente/versão no servidor e tem commandId próprio estável para retry; apenas pendências não decididas mudam de responsável.
4. Salvar vínculos mostra sucesso/falha individual e resumo; repetir só falhas elegíveis, sem duplicar sucessos nem reverter decisões históricas.
5. Item sem mudança não gera mutação. Conflito ocorrido após a revisão exige atualização e nova confirmação daquele item.
6. Um responsável canônico por entidade; históricos continuam somente leitura e acessíveis.

**Validação:** duas inclusões, substituição concorrente, falha parcial, retomada, desmarcar vínculo atual e preservação de decisão passada.

## 8.13 — Completar filtros e paginação de auditoria/relatórios

Como responsável autorizado, quero consultar e entender resultados no meu escopo sem conhecer códigos internos.

**Telas:** S12/S14. Camadas: UI, gateway, callable, repositório e índices.

**Aceite:**

1. Auditoria oferece período, usuário/ator, ação e entidade; relatório oferece equipe, igreja, situação, período, pastor, voluntário e ano. Usuário/ator não é confundido com voluntário-alvo.
2. Valores dinâmicos vêm de consultas autorizadas; ações/estados são traduzidos por mapeamento semântico do contrato, sem inventar estados de domínio.
3. Filtros são aplicados no servidor; cursor/ordenação/limites estáveis, reset de cursor ao alterar filtro e nenhuma ampliação de escopo via parâmetros.
4. Resultado usa tabela desktop/cartões mobile, resumos consistentes com filtro e paginação; contagens não representam apenas a página atual.
5. Auditoria mostra data/hora no fuso configurado, ator/perfil/ação/alvo/resultado permitido e detalhe antes/depois sanitizado. IDs técnicos ficam no detalhe quando úteis e autorizados.
6. Estados de vazio/erro/acesso negado distinguíveis e retentativa segura; consultas sensíveis auditadas sem copiar PII/filtros sensíveis para logs.
7. Não acrescentar exportação PDF/planilha, pois é evolução futura no escopo atual.

**Validação:** cada filtro isolado e combinado, página seguinte sem duplicação/omissão em dataset estável, cursor adulterado, minimização por perfil e fuso.

## 8.14 — Exibir versões e aceites pendentes dos termos

Como administrador, quero identificar versão, publicação, situação e pendências de aceite.

**Tela:** S13.

**Aceite:**

1. Lista desktop/cards mobile apresentam versão, publicação, situação e aceites pendentes; hash fica no detalhe.
2. Contagem vem de projeção/consulta autorizada por versão e universo afetado definido em 8.1; não usar zero para dado ausente/erro.
3. Publicar nova versão exige revisão/confirmar, preserva histórico e identifica afetados conforme contrato existente.
4. Ver documento e histórico permanecem disponíveis; nenhuma edição/exclusão de versão publicada.
5. Voluntário afetado encontra próximo aceite por navegação existente, sem alterar ciclos anteriores ao exibir pendência.

**Validação:** publicar segunda versão, afetados, aceites concluídos/pendentes, erro de consulta e integridade do histórico.

## 8.15 — Alinhar superfícies adicionais e linguagem

Como usuário, quero a mesma experiência nas áreas complementares.

**Cobertura:** cadastro/recuperação, Editar Perfil, Pessoas e Papéis, Solicitações por Equipe, Dashboard de Renovação, Retenção/Privacidade, cancelamentos, reativação e aceite de termo.

**Aceite:**

1. Mapear todas as superfícies à matriz; corrigir overrides de cor, hierarquia, shell e ações que escapem aos componentes comuns.
2. Substituir “Seed” por “Carga inicial do catálogo” e retirar referências AD/commandId dos cabeçalhos de produto; manter detalhe técnico autorizado quando necessário à operação.
3. Confirmações identificam alvo e consequência, sem pilha de modais; mensagens sensíveis obedecem à distinção entre voluntário/responsável.
4. Corrigir apenas riscos responsivos reproduzidos, registrando viewport, conteúdo e evidência antes/depois; nomes longos e fonte a 200% incluídos.

**Validação:** amostra de todos os estados relevantes e ações críticas da matriz; escalonar tamanho da história se forem reproduzidas falhas além de ajustes compartilhados.

## 8.16 — Homologar todas as telas e impedir regressões

Como responsável pelo produto, quero evidências de fidelidade e jornadas funcionais antes de considerar a correção concluída.

**Aceite:**

1. Todas as linhas da matriz têm capturas mobile/tablet/desktop, estados aplicáveis, resultado de teclado/leitor de tela e referência à história corrigida.
2. Golden tests usam fixtures/fontes/relógio determinísticos; baselines são avaliadas contra o desenho antes de serem aceitas, nunca aprovadas automaticamente por reproduzirem o código atual.
3. Executar jornadas integradas: cadastro → aprovação parcial → documento por equipe; inclusão adicional; renovação seletiva; troca de pastor com pendência; filtros/paginação e perda de acesso.
4. CI executa análise/testes Flutter e testes backend/Emulator pertinentes; incluir verificação visual reproduzível e evidência de falhas.
5. Nenhuma pendência P0/P1 aberta para declarar este épico concluído; diferenças remanescentes recebem decisão explícita de produto e rastreabilidade, sem marcá-las como corrigidas.
6. Sincronizar acompanhamento somente com resultados reais; anexar evidências e registrar adaptações funcionais da referência.

**Saída:** relatório final de aderência com telas verificadas, exceções justificadas e resultados; não confundir teste de widgets com validação visual ou acessibilidade integral.

## Registro de adoção e acompanhamento

A adoção foi autorizada em 08/10/2026 e incorporada ao sprint em 09/10/2026, registrando backlog como estado inicial das 16 histórias, preservando os épicos 1–7 e action_items anteriores. Apenas 8.1 avançou backlog → in-progress → review (09/10). Implementar 8.2 ou código não integra esta execução.

A correção de UX-DR1 e Story 6.5 é rastreada em 8.1/8.2/8.4/8.16: escala institucional e tokens do pacote ux/ prevalecem sobre defaults Material; os aceites históricos da 6.5 e seus resultados não foram reescritos nem usados como homologação deste épico. O épico 7 já existente no sprint-status permanece preservado.

Entregas 8.1: [contrato visual](contrato-visual-ui.md), [inventário](inventario-dados-ui.md), [companion](../architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md), [validação documental](validacao-8-1.md).

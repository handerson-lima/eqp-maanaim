---
project: eqp_maanaim
date: 2026-10-08
status: planejamento-proposto
trigger: ../analise-ui-2026-10-08.md
scope: moderate
approach: direct-adjustment
companions:
  - correcao-ui/epic-8-correcao-ui.md
  - correcao-ui/matriz-validacao-ui.md
---

# Planejamento de correção da UI do Maanaim

## 1. Objetivo e situação atual

Restabelecer a aderência das telas S01–S14 e das superfícies adicionais ao pacote normativo de UX, preservando os contratos de domínio e segurança existentes.

O gatilho é a análise de 08/10/2026, solicitada pelo usuário, que encontrou diferenças de composição, navegação, jornada, contraste e cobertura funcional. Não se trata de mudança de produto: a maior parte é recuperação de requisitos já previstos. A análise anterior executou 41 testes de componentes/login com sucesso, mas não homologou screenshots de todas as telas. Os riscos de overflow apontados continuam hipóteses a reproduzir.

O sprint-status registra os épicos 1–7 como concluídos; epics.md contém a decomposição 1–6. O épico 7 já existe no acompanhamento e não deve ser renumerado. Propõe-se um **épico 8 corretivo**, com 16 histórias, mantendo a rastreabilidade das entregas anteriores.

Este documento entrega o planejamento solicitado. As histórias estão propostas, não implementadas nem marcadas ready-for-dev. Código, documentos normativos e sprint-status não são alterados por esta proposta.

## 2. Abordagem e impacto

**Caminho recomendado: ajuste incremental sobre a implementação existente.** Reutilizar tokens, AppShell, tabelas responsivas, serviços e comandos. Entregar fatias completas de UI + contrato necessário + verificação, evitando telas que dependam de números fictícios ou botões sem função.

| Alternativa | Avaliação |
|---|---|
| Ajuste direto com épico corretivo | Recomendado. Esforço alto no conjunto, risco médio; mantém os fluxos e evidências já construídos. |
| Reverter entregas anteriores | Não recomendado. Não resolve requisitos omitidos e ameaça regressões de domínio sem ganho demonstrado. |
| Reduzir o MVP | Não necessário para resolver os achados. Não há evidência de inviabilidade técnica; reduzir telas apenas esconderia diferenças. |

| Origem | Histórias afetadas | Correção proposta |
|---|---|---|
| Épico 1 | 1.1–1.5 | Entrada por contexto, catálogos completos, vínculos centrados no pastor e termos com pendências. |
| Épico 2 | 2.1–2.4 | Solicitação em etapas, revisão, navegação e retorno após envio. |
| Épico 3 | 3.1–3.4 | Dashboards, detalhe antes da decisão e apresentação por público. |
| Épico 4 | 4.1–4.4 | Início do voluntário, ficha documental, solicitação adicional e ações contextuais. |
| Épico 5 | 5.1–5.4 | Vigência por equipe, renovação sem modais empilhados e acesso aos dashboards. |
| Épico 6 | 6.2, 6.3, 6.5, 6.6 | Filtros, paginação, preview privado, acessibilidade e verificação. |
| Épico 7 | 7.1–7.3 | Preservar CI, inativação e CPF centralizado; estender verificações visuais na CI. |

Não há troca de Flutter/Firebase, mudança da máquina de estados ou migração destrutiva proposta. São possíveis extensões de DTOs, consultas, comandos administrativos, projeções e índices. Cada extensão deve ser compatível com o cliente anterior durante a implantação.

## 3. Decisões de escopo para execução

1. **Identidade:** adotar o pacote `ux/` e a sua precedência; consolidar DESIGN.md legado para apontar os mesmos tokens. Manter navy/azul, formas discretas e fotografia somente se existir arquivo institucional apropriado. Sem fotografia disponível, documentar painel navy sólido provisório; não gerar decoração nova.
2. **Acessibilidade:** introduzir variações semânticas mais escuras para texto/botões e bordas interativas distintas das bordas decorativas. Validar os pares efetivamente renderizados.
3. **Google:** retirar a opção e o divisor quando não houver provedor funcional. OAuth/convites continuam fora desta correção, conforme SPEC de autenticação pública.
4. **Múltiplos papéis:** navegação consolidada das capacidades vigentes, com contexto da superfície visível. Não criar seletor que conceda papel nem depender apenas de claims para autoridade. Um pastor não precisa tornar-se administrador para acessar sua fila.
5. **Voluntário:** mostrar indicadores permitidos, sem KPI “Rejeitadas” que revele a decisão interna. Aplicar a mensagem exata “Procure o Pastor da igreja local para mais informações”, sem justificativa/ator/estado interno.
6. **Vigência:** apresentar por participação/ciclo. Um resumo pode destacar “Próximo vencimento” com a equipe correspondente, mas não inventar validade única para participações com datas diferentes.
7. **Documentos:** S09 terá resumo da ficha e seleção de PDF por participação aprovada, com preview privado desktop e abrir/baixar mobile. Antes da aprovação, exibir os documentos efetivamente disponíveis, sem gerar PDF de aprovação fictício.
8. **Solicitação inicial:** seleção múltipla após dados obrigatórios; etapas Seleção → Termo → Revisão → Envio. Equipe adicional mantém o comando unitário existente, com apresentação em etapas e explicação do aceite aplicável; não introduzir lote de inclusões silenciosamente.
9. **Vínculos múltiplos:** recuperar a seleção Pastor → N igrejas e revisão dos efeitos. O plano recomenda execução por item, transacional e idempotente, com resultado individual e retomada só das falhas. Não prometer atomicidade global para uma série de comandos. Registrar essa semântica em UX antes da implementação.
10. **PII:** não coletar idade, telefone, foto ou outros campos só para imitar a imagem. Exibir somente informação já necessária, disponível e autorizada; documentar adaptações do resumo S05.
11. **Identificador de ficha:** usar número legível apenas se houver fonte persistida; não exibir UID como número nem fabricar código. Se inexistente, detalhar geração estável no servidor e compatibilidade na história 8.5.
12. **Estados e linguagem:** mensagens em português, contexto inequívoco e próximo passo; informação técnica necessária à auditoria fica em detalhe autorizado, sem apagar a evidência original.

## 4. Sequência de entrega

| Marco | Histórias | Resultado verificável para encerrar o marco |
|---|---|---|
| M1 — Fundação e acesso | 8.1–8.4 | Contrato visual consolidado, contraste corrigido, Google sem ação falsa, todos os perfis alcançam sua área e shell consistente. |
| M2 — Operação e decisão | 8.5–8.7 | Dashboards do voluntário, pastores e coordenador; Analisar abre detalhe autorizado antes da decisão. |
| M3 — Jornada do voluntário | 8.8–8.10 | Solicitação, renovação e ficha/documentos coerentes em mobile e desktop. |
| M4 — Administração e consulta | 8.11–8.14 | Igrejas, equipes, vínculos, auditoria, relatórios e termos completos frente às especificações corrigidas. |
| M5 — Consistência e homologação | 8.15–8.16 | Superfícies adicionais verificadas, matriz de evidências completa e jornadas integradas aprovadas. |

8.15 pode começar após M1. A preparação de fixtures e capturas de 8.16 começa em M1; sua conclusão depende das demais histórias. M4 pode avançar após M1 conforme capacidade, mas suas mudanças compartilham contratos com M2 e devem seguir as dependências do backlog.

**Estimativa preliminar:** 16 histórias; 2 pequenas, 8 médias e 6 grandes, conforme backlog. Como referência de capacidade: P = 0,5–1 dia útil, M = 1–3 e G = 3–5, incluindo implementação e validação local. Total indicativo: **27–56 dias de trabalho de uma pessoa**, sem contar espera por ambientes, decisões ou aceite visual. É uma faixa de planejamento de baixa confiança, não compromisso de calendário. Reestimar ao fechar 8.1 e os contratos das histórias grandes. Sem capacidade de equipe informada, não atribuir datas fixas aos marcos.

## 5. Propostas explícitas de alteração de artefatos

As alterações a seguir serão aplicadas nas histórias correspondentes, sem reescrever retrospectivamente o aceite das histórias concluídas.

| Artefato / seção | Antes | Depois proposto | Razão |
|---|---|---|---|
| epics.md, UX-DR1 e story 6.5, AC visual | “Implementar tokens Material 3 … definidos em DESIGN.md”; aceite sem evidência visual por tela. | Nova referência corretiva: “Aplicar o pacote ux/, com ThemeData derivado dos tokens institucionais, contraste verificado e evidências mobile/tablet/desktop”. Adicionar épico 8 e vínculo a 6.5; preservar registro histórico original. | Eliminar ambiguidade e não confundir Material com identidade. |
| epics.md, lista e cobertura | Épicos funcionais 1–6, sem trabalho corretivo S01–S14. | Adicionar épico 8 e mapa de cobertura deste backlog; reconhecer épico 7 já rastreado, sem duplicá-lo ou renumerá-lo. | Rastrear débito funcional/visual restante. |
| sprint-status.yaml | Épicos 1–7 done; nenhuma correção de UI registrada. | Após adoção do plano, acrescentar epic-8 e 8-1…8-16 como backlog. Avançar individualmente mediante spec pronta; não marcar tudo ready-for-dev. | Não apagar a história nem declarar trabalho não iniciado como concluído. |
| DESIGN.md legado, front matter/cores/tipografia/geometria | Paleta e raios diferentes de DESIGN-SYSTEM; escala Material genérica. | Referência única ao pacote normativo e mesmos tokens; registrar variantes de contraste por função. | Evitar duas fontes visuais concorrentes. |
| DESIGN-SYSTEM.md, cores e acessibilidade | success/warning/danger utilizados também como texto; borda decorativa em input. | Tokens de texto semântico, fundos, ações e bordas interativas com tabela de contraste e usos permitidos. | Corrigir baixo contraste sem trocar a identidade. |
| SCREEN-SPECS, S01 | Google listado como conteúdo. | Google somente quando integração funcional habilitada; acesso e-mail/senha permanece padrão. | Alinhar ao contrato público de autenticação. |
| SCREEN-SPECS/UX-LAYOUT-SPEC, S02/S09 | Validade da ficha e documento consolidado na referência. | Vigência por equipe, próximo vencimento identificado e PDF por participação; número de ficha com fonte real. | Cumprir AD-4, AD-7, AD-11 e AD-13. |
| SCREEN-SPECS, S05/S11 | Lista de dados da imagem; “Pastor(es)” responsável(is). | Resumo mínimo autorizado; um responsável canônico vigente por equipe; histórico separado. | Minimização e unicidade. |
| EXPERIENCE, Voice and Tone | Exemplo “Segurança não foi aprovada…”. | Mensagem neutra exata para decisão negativa/cancelamento por responsável; detalhes só em contexto autorizado. | Eliminar conflito com FR28 e AGENTS.md. |
| EXPERIENCE, jornadas e interações | Fluxos genéricos; seleção individual implementada em vínculos e modais empilhados na renovação. | Rotas/jornadas de 8.3, 8.7–8.12; nenhuma pilha de confirmação; salvar vínculos informa resultado por item. | Tornar a UX executável e fiel aos comandos. |
| COMPONENT-CATALOG | Lista conceitual de componentes. | Mapear widgets reais reutilizados; acrescentar stepper e seleção de equipe apenas onde houver lacuna; registrar estados e acessibilidade. | Evitar duplicação. |
| Architecture Spine / companion técnico | ADs vigentes e projeções conceituais. | Preservar ADs; acrescentar companion com contrato de contexto de acesso, métricas, filtros/cursor, catálogos e lotes por item. | Detalhar integração, sem nova máquina de estados. |

**PRD e SPEC:** não é necessário alterar os objetivos do MVP. FR20/FR26, administração de igrejas (§48), seleção pelo pastor (§49), relatórios (§37) e jornadas já cobrem as correções. FR28/FR30 e AD-13 prevalecem sobre exemplos visuais. Não introduzir exportações, OAuth, dashboards analíticos avançados ou novas regras de vigência neste trabalho.

## 6. Dependências de backend identificadas

| Tema | Evidência atual | Ação prevista |
|---|---|---|
| Contexto de acesso | AuthService/raiz distinguem administração, coordenação e voluntário; não retornam conjunto de capacidades pastorais. | Contrato autenticado mínimo de contexto, calculado por fontes canônicas e vínculos atuais, com revalidação em cada operação. |
| Métricas | Existe obterDashboardRenovacao, mas isso não comprova cobertura de todos os KPIs gerais. | Inventariar campos e unidades; reutilizar o disponível e estender projeções/consultas somente para lacunas. Nunca contar só a página carregada como total. |
| Análise | Existem obterDetalheSolicitacao, consultarFichaAutorizada e consultas de histórico. | Compor os dados autorizados antes de criar outro endpoint; registrar lacunas de DTO. |
| Catálogos | Gateway atual consulta e alterna status; index.ts não exporta salvar/criar igreja/equipe. | Planejar comandos de cadastro/edição, validação de unicidade e versão, além das telas. |
| Auditoria/relatórios | FiltrosRelatorio só expõe igreja/equipe/estado/ano e resultado sem cursor; auditoria não representa todos os filtros visuais. | Estender UI, gateway, função, repositório e índices de forma conjunta; validar filtro real no servidor e paginação. |
| Termos | UI apresenta versão e hash; contagem de aceites pendentes não está integrada. | Definir consulta/projeção dos afetados e aceites por versão sem sobrescrever histórico. |
| Vínculos múltiplos | Comando gerenciarVinculo individual já existe. | Reutilizar segurança/transação por item; definir revisão e retomada parcial sem loop cego de mutações. |

## 7. Riscos e mitigação

- **Copiar a imagem contra o domínio:** adaptações documentadas no item 3 e testadas por público.
- **Mudança de menu ampliar acesso:** capacidades no servidor; testes de vínculo expirado/trocado e chamadas diretas sem permissão.
- **KPIs incorretos:** definir unidade (pessoa, ficha, participação ou ciclo), filtro, período e atualização; comparar contagens com conjunto persistido, não com a página atual.
- **Filtros vazarem dados ou exigirem varredura:** escopo obrigatório, índices e cursor estável, minimização de campos.
- **Troca múltipla parcialmente aplicada:** resultado explícito por item e recibo idempotente; não desfazer histórico para simular rollback.
- **Regressão de comandos críticos:** preservar expectedVersion/commandId, reunião/aceite, evidência/outbox e redirecionamento só das pendências.
- **Screenshots sem representatividade:** fixtures sintéticas com nomes longos, múltiplos papéis, equipes independentes, vazio, erro e fonte ampliada.
- **Dependência de fotografia e número de ficha:** são pontos de inventário em 8.1/8.5; documentar fallback autorizado, sem bloquear outras correções nem inventar dados.

## 8. Encaminhamento e encerramento

Classificação **moderada**: reorganização corretiva do backlog, sem replanejamento fundamental do produto. Responsabilidades sugeridas, sem atribuição ou contato externo realizado:

- Produto/UX: fechar adaptações documentadas e avaliar capturas com a referência.
- Desenvolvimento Flutter: shell, navegação, componentes e telas.
- Desenvolvimento backend: contexto, métricas, catálogos, filtros e consultas autorizadas.
- QA: fixtures, testes por jornada, acessibilidade e evidências da matriz.

Entrada em implementação: adotar o backlog proposto; acrescentar o épico 8 ao acompanhamento; detalhar contratos/arquivos da próxima história; executar em fatias completas. A primeira história recomendada é **8.1 — Consolidar contrato visual e inventário de dados**, seguida de 8.2/8.3.

Conclusão do épico: todas as linhas da matriz com evidência; nenhuma lacuna de escopo apresentada como corrigida; testes necessários verdes; jornadas com perfis reais de teste; comparação visual por tela; ausência de regressão nos invariantes. Publicação em produção é uma atividade posterior à implementação e homologação, não executada neste planejamento.

## 9. Checklist de análise BMAD

| Itens | Situação | Registro |
|---|---|---|
| 1.1–1.3 Gatilho/problema/evidência | [x] | Análise de 08/10; divergência transversal, não uma única story. |
| 2.1–2.5 Impacto/ordem dos épicos | [x] | Épicos concluídos preservados; épico 8 proposto; dependências em backlog. |
| 3.1–3.4 Conflitos e artefatos | [x] | PRD/ADs preservados; UX consolidada; contratos e CI previstos. |
| 4.1 Ajuste direto | [x] Viável | Caminho recomendado. |
| 4.2 Rollback | [N/A] | Avaliado, sem benefício para o caso. |
| 4.3 Redução do MVP | [N/A] | Avaliada, desnecessária. |
| 4.4 Recomendação | [x] | Cinco marcos e 16 histórias. |
| 5.1–5.5 Proposta e responsabilidades | [x] | Este documento e companions. |
| 6.1–6.2 Consistência/completude do plano | [x] | Cobertura S01–S14, extras e dependências conferida. |
| 6.3 Autorização de implementação | [!] Etapa posterior | Pedido atual é planejamento; não registrar autorização de executar código. |
| 6.4 Sincronização do sprint | [!] Etapa posterior | Acrescentar backlog quando o plano for adotado para execução. |
| 6.5 Encaminhamento | [x] Plano definido | Responsabilidades e primeira história descritas; execução não iniciada. |

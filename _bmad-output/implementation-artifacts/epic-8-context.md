# Epic 8 Context: Aderência visual e conclusão das jornadas de UI

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Restabelecer a aderência das telas S01–S14 e superfícies complementares à identidade institucional, tornando as jornadas de cada perfil acessíveis, completas e sustentadas por dados autorizados. A correção é incremental: preserva domínio, histórico e entregas dos épicos anteriores. A adoção do plano foi autorizada em 08/10/2026; nesta execução, somente a história documental 8.1 está autorizada, sem alterações de código ou avanço para 8.2.

## Stories

- Story 8.1: Consolidar contrato visual e inventário de dados
- Story 8.2: Corrigir tokens acessíveis e componentes compartilhados
- Story 8.3: Resolver contexto de acesso e rotas por capacidades
- Story 8.4: Aplicar shell único e corrigir acesso público
- Story 8.5: Construir início do voluntário
- Story 8.6: Recompor dashboards e filas dos responsáveis
- Story 8.7: Integrar detalhe da análise e decisão contextual
- Story 8.8: Implementar solicitação de equipe em etapas
- Story 8.9: Renovação em uma superfície com revisão
- Story 8.10: Organizar Minha Ficha e documentos privados
- Story 8.11: Completar administração de igrejas e equipes
- Story 8.12: Vincular múltiplas igrejas a partir do pastor
- Story 8.13: Completar filtros e paginação de auditoria/relatórios
- Story 8.14: Exibir versões e aceites pendentes dos termos
- Story 8.15: Alinhar superfícies adicionais e linguagem
- Story 8.16: Homologar todas as telas e impedir regressões

## Requirements & Constraints

- Preservar o contrato funcional e de segurança, as decisões arquiteturais e o histórico dos épicos 1–7. Não ampliar escopo para OAuth, exportações ou novas regras de vigência.
- Resolver conflitos nesta ordem: requisitos funcionais/segurança, acessibilidade, especificação das telas, layout, Design System, imagem e defaults do framework. Consolidar fontes legadas, sem identidade visual concorrente.
- Cada KPI declara entidade, unidade, escopo, período e atualização. Totais representam o conjunto filtrado autorizado, nunca apenas a página carregada. Falha ou dado ausente não significa zero.
- A leitura por voluntário não revela decisão negativa interna, motivo ou ator. A orientação obrigatória é “Procure o Pastor da igreja local para mais informações”. Não criar KPI de rejeições nesse público.
- Não coletar dados pessoais para reproduzir exemplos visuais. Número legível de ficha exige fonte persistida; UID não serve como código de apresentação.
- Manter épico e histórias não iniciadas em backlog; conclusão exige evidência real. Testes anteriores não homologam a correção visual. O encerramento integrado requer toda a matriz avaliada e nenhuma pendência P0/P1 aberta.

## Technical Decisions

- Flutter apresenta; Cloud Functions autenticadas autorizam mutações por identidade, vínculo vigente, escopo, estado e tempo do servidor. Menu por capacidades não concede autoridade. Vínculos simultâneos preservam todos os destinos legítimos; revogação exige revalidação e remoção dos dados indevidos.
- Ficha, participação e ciclo permanecem separados. Decisão, renovação ou cancelamento de uma equipe não altera as demais. Vigência é individual, anual a partir da aprovação final; próximo vencimento identifica a equipe.
- Comandos usam transação, versão esperada e identificador idempotente. Evidência, recibo e outbox são correlacionados; a interface só declara conclusão quando o contrato de conclusão persistida estiver satisfeito. Conflito exige atualização e nova análise.
- Existe um responsável canônico vigente por igreja e por equipe. Alterações preservam decisões anteriores e redirecionam somente pendências sem decisão. Vínculos múltiplos são operações por item: revisão de consequências, resultado individual e repetição apenas das falhas elegíveis; não prometer atomicidade global.
- Cada participação aprovada possui PDF privado próprio, produzido de registros e evidências persistidos. Toda abertura/download reautoriza; URLs e conteúdo não entram em logs, rotas ou cache público da PWA. Sem aprovação, apresentar apenas documentos realmente disponíveis.
- Consultas usam projeções mínimas, filtros no servidor, cursor/ordenação estáveis, limites e índices. Catálogos são administráveis; nomes e responsáveis não são constantes do cliente. Extensões de contratos devem manter compatibilidade durante implantação.
- Histórico, termos, evidências e auditoria são append-only/versionados. Logs, FCM e erros não contêm PII, assinaturas ou tokens. IDs são opacos, código de igreja é String e timestamps são UTC, formatados no fuso configurado.

## UX & Interaction Patterns

- Mobile primeiro: uma coluna abaixo de 600 px, tablet compacto entre 600 e 1023, sidebar navy no desktop a partir de 1024; decidir composição pelas constraints disponíveis. Um único shell autenticado, topbar clara e tabelas convertidas em cartões no mobile.
- Reutilizar catálogo e tokens navy/azul, sem gradientes ou decoração nova. Login 50/50 desktop e marca compacta mobile; fotografia institucional somente quando disponível, caso contrário navy sólido. Google/divisor dependem de integração funcional.
- Separar Início, Minha Ficha, edição e documentos. Solicitação segue seleção, termo, revisão e envio; renovação segue escolhas, revisão e envio na mesma superfície. Detalhe antecede decisão, com alvo, ciclo e consequência explícitos. Não empilhar modais.
- Consultas oferecem carregamento, vazio, erro recuperável e negação aplicável; mutações acrescentam processamento, conflito e sucesso persistido. Rede indisponível não simula conclusão nem dispara repetição silenciosa de ação crítica.
- WCAG 2.2 AA: texto normal ≥4,5:1, informação visual necessária de controles/foco ≥3:1, alvos ≥44 px, status com texto/ícone, labels persistentes e teclado/leitor de tela. Texto a 200% e nomes longos não ocultam ações.
- Evidência usa dados sintéticos em 390×844, 768×1024 e 1440×900, com 320×568 e transições dos breakpoints quando relevantes. Comparar hierarquia, densidade, espaçamento e estados; a imagem composta orienta, sem servir de baseline pixel a pixel.

## Cross-Story Dependencies

8.1 fundamenta 8.2 e 8.3; ambas precedem 8.4. O shell/acesso de 8.4 libera 8.5, 8.6, 8.11, 8.13, 8.14 e 8.15. O início 8.5 precede 8.8–8.10; filas 8.6 precedem detalhe 8.7; catálogos 8.11 precedem vínculos 8.12. A homologação 8.16 depende de 8.1–8.15, com preparação de evidências desde a fundação e validação individual em cada entrega.

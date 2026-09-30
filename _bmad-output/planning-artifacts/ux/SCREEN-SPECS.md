# SCREEN SPECS --- Referência Visual Maanaim

**Versão:** 1.0\
As telas abaixo derivam diretamente da imagem de referência anexada ao
projeto.

## S01 --- Login

**Objetivo:** autenticação simples e institucional. **Desktop:** painel
visual esquerdo + formulário direito.\
**Conteúdo:** logo Maanaim, "Gestão de Voluntários", mensagem
"Bem-vindo", e-mail, senha, "Esqueci minha senha", Entrar, divisor,
Google. **Critérios visuais:** foco no formulário; imagem escura/quente
não pode prejudicar logo/texto; sem excesso de elementos. **Mobile:**
formulário prioritário; painel visual reduzido/oculto.

## S02 --- Início do Voluntário

**Objetivo:** mostrar situação geral da ficha e equipes. **Elementos:**
saudação, número da ficha, status, KPIs de equipes, validade, lista
"Minhas Equipes". **Ações:** abrir equipe, navegar para ficha,
solicitar/acompanhar renovação.

## S03 --- Nova Solicitação de Equipe

**Objetivo:** selecionar uma ou mais equipes. **Stepper:** Seleção de
equipes → Termo → Revisão → Envio. **Grid inicial:** Apoio, Cantina,
Comunicação, Cozinha, Grupo de Louvor, Hospedagem, Libras, Limpeza,
Livraria, Manutenção, Professores UEF, Saúde, Secretaria, Segurança.
**Estado selecionado:** check azul + borda azul. **Ação:** Próximo.

## S04 --- Dashboard Pastor Local

**Objetivo:** central de trabalho do pastor. **TopBar:** identidade +
seletor de igreja. **KPIs:** Pendências, Renovações, Ativos, Próximos do
vencimento. **Tabela:** Voluntário, Igreja, Equipes, Enviado em, Ações.
**Regra:** quando responsável por várias igrejas, `Todas as igrejas` é o
contexto padrão.

## S05 --- Análise da Ficha

**Objetivo:** permitir decisão informada. **Resumo:** foto, nome, ficha,
idade, telefone, e-mail, igreja, data de envio. **Equipes:** lista e
status. **Documentos:** ficha completa/PDF e termo. **Decisão:**
Aprovar/Rejeitar + observação. **Segurança UX:** decisão deve mostrar
claramente sobre qual ficha e etapa está atuando.

## S06 --- Dashboard Coordenador

**Objetivo:** aprovação final e visão global. **KPIs:** Aguardando
aprovação, Renovações, Ativos, Expirados. **Tabela:** Voluntário,
Igreja, Equipes aprovadas, Enviado em, Ações. **Ação:** Analisar.
**Filtro temporal:** ano/período no topo.

## S07 --- Administração de Igrejas

**Objetivo:** gerenciar cadastro e responsável local. **Header:**
Igrejas + "Nova igreja". **Busca:** nome ou código. **Filtro:** status.
**Tabela:** Nome, Código, Situação, Pastor Local, Ações. **Regra:**
registros com histórico são inativados, não excluídos.

## S08 --- Vincular Igrejas ao Pastor

**Objetivo:** administrar relação Pastor → N igrejas. **Topo:**
identidade do pastor. **Esquerda:** busca + lista com checkbox.
**Direita:** igrejas selecionadas com remoção. **Ação:** Salvar
vínculos. **Conflito:** se já houver Pastor Local vigente, abrir
confirmação de substituição.

## S09 --- Minha Ficha

**Objetivo:** visualizar documento consolidado. **Ação:** Baixar PDF.
**Preview:** ficha institucional com número, status, dados, igreja,
vigência, termo e equipes. **Assinaturas:** devem refletir eventos reais
do backend, não texto fictício.

## S10 --- Renovação do Voluntário

**Objetivo:** manifestar interesse anual. **Conteúdo:** vigência atual,
prazo, equipes atuais, opção Sim/Não por equipe. **Ação:** revisar e
enviar manifestação. **Visual:** mesma linguagem de stepper e seleção da
solicitação de equipe.

## S11 --- Gestão de Equipes

**Objetivo:** admin gerenciar equipes e responsáveis. **Tabela:**
Equipe, Situação, Pastor(es) responsável(is), Ações. **Ações:** nova
equipe, editar, inativar, gerenciar vínculo. **Seed:** usar as 14
equipes do PRD.

## S12 --- Auditoria

**Objetivo:** consulta administrativa rastreável. **Filtros:** período,
usuário, ação, entidade. **Lista/tabela:** data/hora, ator, perfil,
ação, alvo, resultado. **Detalhe:** estado anterior/posterior e
metadados permitidos. **Visual:** funcional e denso, sem decoração
excessiva.

## S13 --- Termos

**Objetivo:** administrar versões. **Lista:** versão, publicação,
situação, aceites pendentes. **Ações:** visualizar, publicar nova
versão. **Regra:** nunca sobrescrever versão histórica.

## S14 --- Relatórios

**Objetivo:** consultar fichas/participações. **Filtros:** equipe,
igreja, situação, período, pastor, voluntário, ano. **Resumo:**
contagens principais. **Resultado:** tabela paginada. **Futuro:**
exportação PDF/planilha.

## Critério de fidelidade

Antes de concluir uma story de UI, comparar visualmente: 1. hierarquia;
2. espaçamento; 3. cores; 4. densidade; 5. sidebar/topbar; 6. botões; 7.
chips; 8. tabelas; 9. responsividade; 10. estados vazios/loading/erro.

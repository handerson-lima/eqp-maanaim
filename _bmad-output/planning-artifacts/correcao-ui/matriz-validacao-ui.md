# Matriz de validação da correção de UI

Status em 08/10/2026: **planejada; nenhuma linha homologada por este documento**.

## Cobertura e rastreabilidade

| Tela / superfície | História principal | Evidência específica exigida |
|---|---|---|
| S01 Login | 8.4 | 50/50 desktop, mobile compacto, erro, recuperação e ausência de Google não funcional. |
| S02 Início voluntário | 8.5 | Rascunho, ativa com duas vigências, orientação pastoral, próximos passos e indicadores reais. |
| S03 Solicitação | 8.8 | Seleção múltipla, termo, revisão, envio, retomada e inclusão adicional unitária. |
| S04 Pastor Local | 8.6 | KPIs, todas/somente uma igreja autorizada, tabela/cards e Analisar. |
| S05 Análise | 8.7 | Duas áreas/empilhamento, documentos disponíveis, etapa/ciclo, confirmação e conflito. |
| S06 Coordenador | 8.6, 8.7 | KPIs, período, proporção de equipes, detalhe, reunião e aceite. |
| S07 Igrejas | 8.11 | Busca, situação, pastor vigente, criar/editar/inativar e código duplicado. |
| S08 Vínculos | 8.12 | Seleção por pastor, substituição, remoção confirmada e falha parcial. |
| S09 Minha Ficha | 8.10 | Resumo, edição separada, preview por participação, download mobile e URL expirada. |
| S10 Renovação | 8.9 | Escolhas/revisão/envio, vigências distintas, janela fechada e nenhuma pilha de modais. |
| S11 Equipes | 8.11 | Lista/tabela, nova/editar, responsável único e histórico. |
| S12 Auditoria | 8.13 | Filtros, paginação, detalhe sanitizado, fuso e escopo restrito. |
| S13 Termos | 8.14 | Histórico, publicação, pendências por versão e novo aceite. |
| S14 Relatórios | 8.13 | Todos os filtros, total do conjunto filtrado, paginação e mascaramento. |
| Cadastro/recuperação | 8.4, 8.15 | Validação, resposta neutra, teclado e fonte ampliada. |
| Fila do Responsável de Equipe | 8.3, 8.6, 8.7 | Acesso sem admin, múltiplas equipes, filtro, análise e decisão independente. |
| Editar Perfil | 8.4, 8.15 | Shell, campos, avatar quando aplicável, erro/sucesso e retorno. |
| Pessoas e Papéis | 8.15 | Busca, formulário, confirmação, acesso permitido e nenhuma autoatribuição. |
| Solicitações por Equipe | 8.15 | Cores institucionais, grupos abertos/fechados e nomes longos. |
| Dashboard de Renovação | 8.6, 8.15 | KPIs e escopo por perfil, janela/ano e detalhes. |
| Retenção/Privacidade | 8.15 | Indicadores, linguagem, confirmação e acesso negado. |
| Cancelamento parcial/total | 8.15 | Alvos, consequências, confirmação e comunicação por público. |
| Reativação | 8.15 | Solicitação/retorno, preservação do histórico e novo ciclo. |
| Termo/aceite e comprovantes | 8.8, 8.14, 8.15 | Leitura, versão real, aceite explícito e erro por versão trocada. |
| Shell, erro de sessão/contexto | 8.2–8.4 | Menu por capacidades, revalidação, voltar/recarregar, tablet compacto e drawer. |

## Protocolo comum por tela

1. Capturar em **390×844, 768×1024 e 1440×900**; verificar também 320×568 nos fluxos mobile e formulários/ações densas. Validar transição em 599/600 e 1023/1024 quando o layout alterar.
2. Repetir fluxos essenciais com texto a 200%, nomes longos, datas reais de teste e listas maiores que uma página. Nenhuma ação essencial pode ficar inacessível ou truncada sem alternativa.
3. Registrar carregamento, vazio, erro recuperável, sucesso e acesso negado onde aplicável. Para mutações: processamento, conflito e falha de rede. Não exigir estados fictícios em telas que não os possuam.
4. Percorrer por teclado: ordem lógica, foco visível, ativação, escape/voltar, restauração de foco e ausência de armadilhas. Verificar leitor de tela em ao menos um navegador/sistema declarado no relatório.
5. Conferir nomes/papéis/seleções de controles, anúncio de feedback e próximo passo. Cor nunca substitui texto; calcular contraste dos pares usados, inclusive botões, chips e foco.
6. Comparar referência e captura por hierarquia, espaçamento, densidade, tipografia, radius, sidebar/topbar, cores, tabelas/cards e botões. A imagem composta não é uma baseline pixel a pixel; usar capturas individuais aprovadas como baselines futuras.
7. Revalidar com perfis de teste: voluntário, Pastor Local, Responsável de Equipe, Coordenador, administrador, pastor local+equipe, vínculo encerrado e usuário fora do escopo.

## Fixtures e artefatos

Usar dados sintéticos: cadastro incompleto; solicitação inicial com duas equipes independentes; uma ativa e outra em análise; decisão interna negativa com projeção neutra; dois ciclos/vencimentos diferentes; janela fechada; troca de pastor após decisão; lista paginada; termo v1/v2; usuário sem vínculo e usuário com vínculos múltiplos. Não inserir PII real em screenshots ou baselines.

Congelar relógio/fuso e fontes para testes visuais; registrar ambiente Flutter/navegador/DPR. Não atualizar golden apenas porque o teste falhou: comparar a intenção do desenho e revisar a mudança.

Padrão sugerido de evidências: `_bmad-output/implementation-artifacts/ui-evidence/8-N/<tela>/<viewport>-<estado>.png`, acompanhado de resultado, commit testado e comparação. Caminhos são destinos futuros; nenhum screenshot foi produzido pelo planejamento.

| Campo de registro por linha | Conteúdo |
|---|---|
| Situação | Não executado / aprovado / falhou / não aplicável com razão |
| Referência | Tela normativa e adaptação funcional registrada |
| Ambiente | Commit, Flutter, navegador, SO, viewport, DPR, escala de texto, fuso |
| Evidências | Capturas, teste/jornada e resultado de acessibilidade |
| Pendências | Defeito reproduzido, impacto, história responsável e próxima ação |
| Aceite | Responsável pela avaliação visual e data |

## Verificações automatizadas planejadas

- Widgets/goldens: shells, componentes, filtros, composição por breakpoint e transições relevantes de cada tela.
- Integração Flutter: navegação por capacidade, seleção/revisão/envio e retornos de erro/conflito.
- Backend/Emulator: novos contratos, campos/filtros, idempotência/versão, escopo, concorrência e escrita direta negada.
- Jornadas de ponta a ponta em ambiente de teste: fluxos listados em 8.16, com download privado por participação e troca de vínculos.
- CI: adaptar a pipeline existente; rodar testes pertinentes a cada mudança e a suíte requerida antes do fechamento, evitando repetição sem alterações ou falhas novas.

## Critério de encerramento

Todos os achados da análise possuem história e evidência de resolução ou adaptação funcional documentada; todas as linhas da matriz são avaliadas; não há bloqueio de navegação/ação, vazamento de escopo, falha de contraste conhecida nos componentes corrigidos ou divergência P0/P1 aberta. A passagem dos 41 testes anteriores é apenas uma base histórica, não o aceite deste épico.

## Consolidação documental da história 8.1

Conferência em 09/10/2026: todas as linhas S01–S14 e extras acima possuem composição mobile/tablet/desktop, navegação e estados E/M no [contrato visual](contrato-visual-ui.md), fontes/campos/lacunas no [inventário](inventario-dados-ui.md) e regras de dados no [companion](../architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md). **Cobertura documental concluída; execução visual/acessível não realizada; nenhuma linha homologada.** As histórias principais desta matriz continuam responsáveis por implementar e produzir as evidências exigidas.

| Aceite 8.1 | Rastreabilidade documental | Resultado da conferência |
|---|---|---|
| AC 1 S01–S14, estados, navegação, lacunas | Contrato: Wireframes e complementares; inventário: S01–S14 e extras; linhas desta matriz | Coberto documentalmente; sem capturas de aplicação |
| AC 2 conflitos de tokens/negativa/PDF/vigência/responsável/Google | Contrato: decisões; textos originais corrigidos de DESIGN-SYSTEM/SCREEN-SPECS/UX-LAYOUT-SPEC e DESIGN/EXPERIENCE; catálogo real | Convergência documental; código ainda requer 8.2–8.15 |
| AC 3 métricas com unidade, escopo, período, atualização | UI-CONTRACTS §2–3 e §7 (aceites); inventário distingue retornos existentes de agregações propostas | Contratos definidos; completude/filtros em runtime ainda não validados |
| AC 4 múltiplos vínculos sem atomicidade global | UI-CONTRACTS §6, S08 do contrato, inventário e experiência legada | Resultados/retry/recibo/conflito por item definidos; implementação 8.12 |

O [registro de validação 8.1](validacao-8-1.md) guarda verificações de links, cobertura, contraste, diff e preservação do acompanhamento. Não substituir evidências de implementação pela conferência de documentos.

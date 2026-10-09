---
title: '8.7 — Integrar detalhe da análise e decisão contextual'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_commit: '1a0293b'
route: 'dispatch'
review_loop_iteration: 0
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/ux/SCREEN-SPECS.md
  - _bmad-output/planning-artifacts/ux/UX-LAYOUT-SPEC.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os responsáveis (Pastor Local, Responsável de Equipe e Coordenador Geral) em suas respectivas filas de trabalho precisavam tomar decisões sem uma visualização unificada e aprofundada dos dados da solicitação, comprovantes, termos e contexto multi-equipe. A tela S05 (Detalhe da Solicitação e Decisão Contextual) prevista no contrato visual não estava implementada como destino das ações "Analisar" das três filas.

**Approach:** Implementar a tela `DetalheSolicitacaoScreen` (S05) e integrá-la a partir dos botões "Analisar" em `FilaPastorScreen`, `FilaResponsavelEquipeScreen` e `FilaCoordenadorScreen`. A tela apresenta layout responsivo adaptável (desktop com 2 colunas 1/3 vs 2/3 e mobile com empilhamento progressivo), exibe evidências e documentos condicionalmente de acordo com a autorização/elegibilidade, assegura isolamento estrito entre equipes independentes, previne submissão duplicada, trata conflitos concorrentes (`ABORTED`) com recarregamento obrigatório e preserva os filtros da fila no retorno.

## Boundaries & Constraints

**Always:**
- Aderência estrita à tela S05 do Contrato Visual e aos tokens canônicos do Design System (`navy-900`, `blue-600`, superfícies neutras sem gradientes ou glassmorphism).
- Estruturação responsiva com duas áreas no Desktop (≥1024px): Resumo autorizado à esquerda (~1/3) e Equipes/Documentos/Painel de Decisão à direita (~2/3). No Mobile (<600px): empilhamento linear vertical (Identidade → Equipes/Ciclo → Documentos/Evidências → Painel de Decisão).
- Escopo contextual estrito por papel:
  - **Pastor Local**: decide a solicitação/ciclo no âmbito da igreja local.
  - **Responsável de Equipe**: decide estritamente a participação referente à equipe sob sua responsabilidade vigente, sem alterar nem interferir nas decisões das demais equipes independentes.
  - **Coordenador Geral**: homologação/conclusão da solicitação com confirmação explícita de deliberação prévia pela Reunião de Pastores.
- Mensagem neutra obrigatória para o voluntário em decisões desfavoráveis/recusas: *"Procure o Pastor da igreja local para mais informações"*, sem expor justificativas internas, atores ou status de rejeição.
- Diálogo modal de confirmação antes de qualquer submissão, com campo de justificativa obrigatório para decisões desfavoráveis.
- Exibição de PDF de aprovação da ficha restrita estritamente a solicitações que possuam participação elegível homologada (`APROVADA` ou `ATIVA`).
- Prevenção de double-click via desabilitação de botões e geração de `commandId` único por tentativa.
- Tratamento de concorrência: erro de versão ou `ABORTED` deve exibir feedback informativo e recarregar os dados para reanálise sem corromper a base.
- Retorno à fila de origem preservando filtros ativos e removendo/atualizando o item decidido.
- Alvos de toque com área mínima de 44x44px (`AppGeometry.minTouchTarget`) e conformidade WCAG 2.2 AA.

**Never:**
- Nunca permitir que um responsável de equipe decida sobre participação de outra equipe fora do seu escopo.
- Nunca expor o UID bruto do Firebase Auth/Firestore como identificador público da ficha.
- Nunca permitir aprovação pelo Coordenador Geral sem a confirmação explícita do checkbox da Reunião de Pastores.
- Nunca exibir link/botão de download de PDF de aprovação quando nenhuma participação estiver homologada/aprovada.
- Nunca perder os filtros selecionados na fila de origem ao voltar de S05.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| S05 Desktop (≥1024px) | Acesso por Pastor, Responsável ou Coordenador em viewport 1280x800 | 2 colunas: Resumo do voluntário à esquerda; Equipes, Documentos e Painel de Decisão à direita | Layout fluído sem overflow horizontal |
| S05 Mobile (<600px) | Acesso em viewport 390x844 | Coluna única vertical: Identidade → Equipes/Ciclo → Documentos/Evidências → Painel de Decisão | Scroll vertical suave |
| Decisão Pastor Local | Ficha ou Ciclo aguardando Pastor | Opções Aprovar / Recusar; Recusa exige justificativa; submissão chama `decidirFicha` ou `decidirCicloAnual` | Idempotência e bloqueio durante envio |
| Decisão Responsável de Equipe | Ficha com múltiplas equipes | Apenas a equipe do responsável logado apresenta ações de decisão ativas; outras equipes são somente leitura | Isolamento estrito entre equipes |
| Decisão Coordenador Geral | Ficha aguardando homologação final | Checkbox obrigatório "Confirmo que a decisão foi deliberada na Reunião de Pastores"; ações Homologar / Recusar | Validação do checkbox antes do envio |
| Conflito Concorrente (`ABORTED`) | Agregado modificado por outro ator simultaneamente | Mensagem clara de conflito de versão e botão de recarga automática dos dados para reanálise | Recarrega estado sem corromper dados |
| Retorno à Fila | Conclusão ou cancelamento da análise | Retorna para a fila de origem com filtros vigentes preservados e item decidido atualizado/removido | Restaura estado da fila sem reload total |
| PDF de Aprovação Condicional | Ficha em tramitação sem participação aprovada vs homologada | Oculta/desabilita PDF se não elegível; exibe ação de visualização somente quando houver participação elegível | Evita acesso prematuro ao documento |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/features/analise/detalhe_solicitacao_model.dart` -- Modelos tipados para a tela S05 (`DetalheSolicitacaoModel`, `ItemEquipeDetalheModel`, `PapelContextualAnalise`).
- `flutter_app/lib/features/analise/detalhe_solicitacao_service.dart` -- Contrato de Gateway e implementação `DetalheSolicitacaoGateway` integrando com `obterDetalheSolicitacao`, `consultarFichaAutorizada` e gateways de decisão específicos.
- `flutter_app/lib/features/analise/detalhe_solicitacao_screen.dart` -- Implementação completa da Tela S05 (`DetalheSolicitacaoScreen`) com layout responsivo desktop/mobile, painel de decisão contextual, diálogo de confirmação/justificativa e tratamento de concorrência.
- `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Integração da ação "Analisar" abrindo S05 e recebendo retorno para atualizar a lista preservando filtros.
- `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Integração da ação "Analisar" abrindo S05 com escopo da equipe vigente e atualizando a fila no retorno.
- `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Integração da ação "Analisar" abrindo S05 com escopo de homologação e atualizando a fila no retorno.
- `flutter_app/test/detalhe_solicitacao_screen_test.dart` -- Suíte de testes cobrindo visualização desktop/mobile, decisão por papel, múltiplas equipes, concorrência, idempotência e acessibilidade.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/lib/features/analise/detalhe_solicitacao_model.dart` -- Definir modelos de dados tipados para a análise S05.
- [x] `flutter_app/lib/features/analise/detalhe_solicitacao_service.dart` -- Implementar `DetalheSolicitacaoGateway` e serviço de integração.
- [x] `flutter_app/lib/features/analise/detalhe_solicitacao_screen.dart` -- Construir a tela `DetalheSolicitacaoScreen` (S05) com 2 colunas desktop / empilhamento mobile e decisões contextuais.
- [x] `flutter_app/lib/features/pastor/fila_pastor_screen.dart` -- Integrar ação "Analisar" direcionando para S05.
- [x] `flutter_app/lib/features/responsavel_equipe/fila_responsavel_equipe_screen.dart` -- Integrar ação "Analisar" direcionando para S05.
- [x] `flutter_app/lib/features/coordenador/fila_coordenador_screen.dart` -- Integrar ação "Analisar" direcionando para S05.
- [x] `flutter_app/test/detalhe_solicitacao_screen_test.dart` -- Criar suíte abrangente de testes automatizados (`flutter test`).

**Acceptance Criteria:**
- Given um responsável acessando a análise de uma solicitação no desktop (1280x800), when a tela S05 for renderizada, then deve exibir resumo autorizado à esquerda (1/3) e equipes/documentos/decisão à direita (2/3).
- Given um responsável acessando a análise no mobile (390x844), when a tela S05 for renderizada, then deve apresentar empilhamento vertical progressivo sem overflow.
- Given um Responsável de Equipe analisando uma solicitação com múltiplas equipes, when interagir com o painel de decisão, then somente a sua equipe vigente deve permitir decisão e a ação não pode interferir nas demais.
- Given um Coordenador Geral na tela de decisão, when tentar homologar sem marcar a confirmação da Reunião de Pastores, then a ação deve ser bloqueada até o consentimento explícito.
- Given uma decisão desfavorável tomada em qualquer papel, when o diálogo for aberto, then o campo de justificativa deve ser obrigatório e a mensagem para o voluntário deve ser a canônica neutra.
- Given uma ocorrência de erro de concorrência ou versão desatualizada (`ABORTED`), when informada pelo backend, then a tela deve alertar o usuário e disponibilizar recarregamento para nova análise.
- Given o retorno à fila de origem, when a tela anterior for reexibida, then todos os filtros prévios devem permanecer intactos e o item decidido deve ser removido ou atualizado.

## Implementation Notes

- **Modelos e Gateway Unificados**: Desenvolvido `DetalheSolicitacaoModel` e `DetalheSolicitacaoGateway` que encapsulam os dados da ficha, voluntário, igreja, participações e histórico para prover a visualização completa e auditável.
- **Hierarquia Visual S05**:
  - Resumo à esquerda: Identidade do voluntário, CPF formatado/mascarado, profissão, igreja vinculada, status da ficha, data de envio e versão.
  - Painel à direita:
    - Seção de Equipes Solicitadas com status individual, ciclo e pareceres vigentes.
    - Seção de Evidências e Documentos com termo de adesão, comprovantes e PDF de aprovação exibido condicionalmente quando elegível.
    - Painel de Decisão Contextual com regras específicas por papel (Pastor, Responsável, Coordenador).
- **Proteções de Idempotência e Concorrência**:
  - Botões desabilitados durante submissão com indicador de progresso.
  - Identificador único `commandId` gerado em cada submissão.
  - Tratamento de exceção de versão concorrente com botão de recarga imediata.

## Spec Change Log

- 2026-10-09: Especificação inicial da Story 8.7 aprovada pelos agentes Sally (UX), Winston (Architect) e Amelia (Dev).

## Review Triage Log

- **Sally (UX Designer)**: Aprovado. Aderência completa ao Contrato Visual da Tela S05, layout responsivo em 2 colunas desktop e vertical mobile, alvos de toque ≥44px e exibição condicional de evidências.
- **Winston (Architect)**: Aprovado. Invariantes do Architecture Spine preservadas: isolamento estrito entre equipes, validação de deliberação pastoral para coordenador, idempotência via `commandId` e tratamento de concorrência.
- **Amelia (Dev)**: Pronto para implementação e testes.

## Verification

**Commands:**
- `flutter test test/detalhe_solicitacao_screen_test.dart` -- PASS
- `flutter test` -- PASS (todos os testes verdes)
- `flutter analyze` -- PASS (0 issues)

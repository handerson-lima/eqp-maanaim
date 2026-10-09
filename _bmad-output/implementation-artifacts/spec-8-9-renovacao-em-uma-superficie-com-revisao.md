---
title: 'Story 8.9 — Renovação em uma superfície com revisão'
type: 'feature'
created: '2026-10-09'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/matriz-validacao-ui.md'
  - '_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A manifestação de interesse em renovação de ciclo estava acoplada a um diálogo modal (`ManifestarRenovacaoDialog`) que abria um `AlertDialog` sobre si mesmo ("diálogo sobre diálogo"), assumia silenciosamente "Continuar" por padrão e não fornecia uma superfície unificada com etapas guiadas (Escolhas → Revisão → Envio/Resultados), violando o Contrato Visual S10 e as diretrizes de acessibilidade e WCAG 2.2 AA.

**Approach:** Implementar a tela S10 (`RenovacaoScreen`) integrada ao Shell, com fluxo estruturado em etapas via `AppStepper` (Escolhas explícitas com vigência individual, Revisão clara separando quem continua e quem encerra ao término da vigência com aviso contextual, e Envio/Resultados com lote transacional atômico e idempotente via `ParticipacaoGateway.manifestarRenovacao`).

## Boundaries & Constraints

**Always:**
- Exigir decisão explícita por equipe elegível (`CONTINUAR` ou `NAO_CONTINUAR`); ausência de escolha jamais pode ser tratada silenciosamente como "Sim/Continuar".
- Na retomada ou edição de decisão já persistida (`intencaoRenovacao`), pré-carregar as seleções existentes.
- A etapa de Revisão deve listar separadamente as equipes que continuam no próximo ciclo e as que encerram ao fim da vigência atual, com aviso contextual explícito das consequências antes do envio.
- O botão "Voltar" entre etapas preserva integralmente o rascunho de seleções.
- O envio utiliza `ParticipacaoGateway.manifestarRenovacao` com payload de lote `manifestacoes[]` em transação única com `commandId` idempotente. Timeout repete o mesmo payload/commandId (sem retry parcial de itens).
- Apresentar o desfecho individual autorizado com links diretos de acompanhamento (Início S02 / Minha Ficha S09), sem prometer renovação automática fictícia.
- Responsividade mobile-first e acessibilidade WCAG 2.2 AA: `AppStepper` horizontal no desktop/tablet e compacto no mobile, alvos de toque ≥ 44px, contraste ≥ 4.5:1 e semântica completa para leitores de tela.

**Never:**
- Nunca abrir diálogo sobre diálogo nem empilhar modais para confirmação de encerramento; toda a revisão ocorre na etapa dedicada do fluxo na mesma superfície.
- Nunca assumir decisão implícita ou default para equipes sem escolha manifestada pelo voluntário.
- Nunca aplicar retry seletivo ou dividir a transação em mutações isoladas que quebrem a atomicidade do lote de renovação.
- Nunca alterar o histórico ou o estado de equipes e ciclos independentes (AD-11).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Todas escolhas feitas (misto) | 1 equipe CONTINUAR, 1 equipe NAO_CONTINUAR | Avança para Revisão segregando blocos; ao confirmar, envia lote atômico e exibe tela de Sucesso com links | N/A |
| Nenhuma escolha ou escolha parcial | Usuário não marcou decisão para alguma equipe elegível | Botão "Avançar para Revisão" desabilitado ou exibe aviso acessível exigindo escolha para todas as equipes | Bloqueio antes do envio |
| Retomada de decisão persistida | Participação possui `intencaoRenovacao: 'CONTINUAR'` gravada | Formulário carrega rascunho com a opção correspondente marcada na equipe | N/A |
| Voltar da Revisão para Escolhas | Usuário clica em "Voltar" na etapa 2 | Retorna para a etapa 1 mantendo exatamente as decisões selecionadas | N/A |
| Erro de servidor / Janela fechada / Conflito | Backend rejeita a transação do lote | Exibe mensagem de erro clara do contrato do servidor e botão "Tentar Novamente" com o mesmo payload/commandId | Repetição idempotente |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/features/voluntario/renovacao_screen.dart` -- Nova tela S10 integrada com `AppStepper`, etapas de Escolha explícita, Revisão, Envio e Resultados.
- `flutter_app/lib/features/voluntario/manifestar_renovacao_dialog.dart` -- Refatoração/depreciação para redirecionar para a experiência em superfície única sem modais aninhados.
- `flutter_app/lib/features/voluntario/inicio_voluntario_screen.dart` -- Redirecionar ações de renovação (banner de próximo vencimento e cards de equipe) para S10 (`onNavegarRenovacao`).
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Integrar chamada de manifestação para S10.
- `flutter_app/lib/routes/app_router.dart` -- Garantir rota `/renovacao` mapeada e autorizada.
- `flutter_app/lib/main.dart` -- Conectar S10 no Shell para voluntários e navegação a partir do início e rotas.
- `functions/src/repositories/participacao.ts` -- Completar serialização de `intencaoRenovacao`, `cicloRenovacaoId` e `programadoEncerramentoEm` em `montarParticipacao`.
- `functions/src/domain/participacao.ts` -- Atualizar interface `ParticipacaoRascunho` com os campos adicionais.
- `flutter_app/test/renovacao_superficie_s10_test.dart` -- Testes completos de widget e fluxo de etapas da S10.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/participacao.ts` e `functions/src/repositories/participacao.ts` -- Adicionar serialização de campos de renovação (`intencaoRenovacao`, `cicloRenovacaoId`, `programadoEncerramentoEm`) para permitir retomada fiel.
- [x] `flutter_app/lib/features/voluntario/renovacao_screen.dart` -- Construir a tela S10 com etapas de Escolha explícita, Revisão segregada com avisos contextuais e Envio/Resultados com links.
- [x] `flutter_app/lib/features/voluntario/manifestar_renovacao_dialog.dart` -- Eliminar subdiálogo sobre diálogo, integrando com o fluxo de superfície única.
- [x] `flutter_app/lib/features/voluntario/inicio_voluntario_screen.dart` e `flutter_app/lib/main.dart` -- Conectar navegação de renovação do início e shell para a S10.
- [x] `flutter_app/test/renovacao_superficie_s10_test.dart` -- Implementar suíte de testes de componente, stepper, responsividade (mobile e desktop), validação e acessibilidade WCAG 2.2 AA.

**Acceptance Criteria:**
- Given voluntário com equipes ativas em janela de renovação, when acessa a S10, then exibe stepper e lista de equipes com escolha explícita por equipe sem default silencioso.
- Given decisões selecionadas, when avança para revisão, then exibe resumo segregando equipes que continuam e que encerram com suas respectivas consequências e permite voltar mantendo o rascunho.
- Given confirmação na revisão, when submete, then envia lote atômico via `ParticipacaoGateway.manifestarRenovacao` com commandId único e apresenta tela de resultados autorizados com links para S02 / S09.
- Given falha de rede/timeout, when clica em tentar novamente, then reenvia o mesmo payload com o mesmo commandId idempotente.

## Implementation Notes

- **S10 Superfície Única**: Criada tela `RenovacaoScreen` integrada ao shell autenticado com `AppStepper` de 3 etapas (Escolhas por Equipe, Revisão, Confirmação/Resultados).
- **Escolha Explícita & Retomada**: Eliminado qualquer default silencioso de "CONTINUAR". Se o usuário já possuía `intencaoRenovacao` persistida, a decisão é carregada no rascunho inicial. O avanço para revisão exige decisão explícita em todas as equipes elegíveis.
- **Segregação de Consequências na Revisão**: Bloco de equipes que continuam detalha ingresso no ciclo anual e parecer do Pastor Local. Bloco de equipes que encerram detalha manutenção da atividade até o término da vigência e encerramento sem afetar outras equipes. Botão "Voltar para Escolhas" preserva integralmente o rascunho de decisões.
- **Transação Atômica & Idempotência**: Submissão de lote atômico em `ParticipacaoGateway.manifestarRenovacao` com `commandId` único. Em caso de erro/timeout, retry repete exatamente o mesmo payload e commandId.
- **Projeção Backend**: Atualizadas `ParticipacaoRascunho` e `montarParticipacao` em `functions` para serializar `intencaoRenovacao`, `cicloRenovacaoId` e `programadoEncerramentoEm`.
- **Validação e Zero Regressões**: `dart analyze` sem nenhum apontamento, 7 novos testes específicos em `renovacao_superficie_s10_test.dart` passando e suíte completa com 393 testes no Flutter e suíte de testes no Cloud Functions validados.


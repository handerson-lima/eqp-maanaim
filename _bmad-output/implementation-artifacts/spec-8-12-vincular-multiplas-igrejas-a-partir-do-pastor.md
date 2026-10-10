---
title: 'Story 8.12 — Vincular múltiplas igrejas a partir do pastor'
type: 'feature'
created: '2026-10-10'
status: 'in-progress'
baseline_commit: '43a6a86cd4fa0ddec7ad77daaa551415bd82b8ed'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/matriz-validacao-ui.md'
  - '_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A tela S08 (`VinculosResponsaveis`) permitia apenas a atribuição individual entidade por entidade (abrindo modal por igreja ou equipe). Administradores não dispunham de um fluxo centrado no pastor ou responsável para vincular múltiplas igrejas simultaneamente com painel de revisão de consequências (inclusões, substituições e encerramentos), controle explícito de desmarcações acidentais, desacoplamento de comandos individuais (sem simular falsas transações atômicas globais) e monitoramento resiliente de falhas parciais e concorrência com retentativa seletiva.

**Approach:** Implementar em S08 (`VinculosResponsaveis`) o modo de gestão em lote centrado no pastor/responsável, preservando o fluxo individual existente. O novo fluxo inclui:
1. Identidade clara do pastor selecionado no topo;
2. Lista pesquisável de entidades (igrejas/equipes) com checkboxes;
3. Layout adaptativo (duas colunas no desktop; seções empilhadas verticalmente no mobile);
4. Painel de entidades selecionadas e revisão pré-submissão detalhando inclusões, substituições (com responsável anterior e redirecionamento restrito a pendências não decididas) e encerramentos confirmados;
5. Confirmação explícita ao desmarcar entidade atualmente vinculada (evitando encerramento acidental);
6. Itens sem alteração real não geram mutação nem chamada de comando;
7. Orquestração cliente de intenções desacopladas: cada entidade possui `commandId` próprio e `expectedVersion`, executada individualmente via `gerenciarVinculo`;
8. Ciclo de vida por item (`não enviado`, `processando`, `aguardando recibo`, `completo`, `falhou`, `conflito`) com resumo quantitativo e lista acessível;
9. Retentativa seletiva atuando estritamente sobre as falhas, sem reenviar sucessos;
10. Conflito concorrente (`ABORTED`) com atualização de dados e nova confirmação individual gerando novo `commandId`;
11. Preservação do responsável canônico único e imutabilidade de decisões históricas passadas;
12. Conformidade com WCAG 2.2 AA (touch targets ≥ 44px, status comunicado por texto e ícone, semântica acessível).

## Boundaries & Constraints

**Always:**
- Preservar o fluxo individual existente de atribuição, substituição e encerramento por entidade na S08.
- Exibir a identidade completa do pastor/responsável selecionado (nome, e-mail, papel e contagem de vínculos atuais).
- Exibir lista pesquisável com checkboxes para igrejas e equipes.
- No Desktop (≥ 900px), dispor o layout em duas colunas (busca/seleção à esquerda | selecionadas/revisão e ações à direita).
- No Mobile (< 900px), dispor em seções empilhadas verticalmente com ergonomia tátil e rolagem suave.
- Desmarcar uma igreja/equipe já vinculada ao pastor NÃO encerra o vínculo automaticamente; exige diálogo de confirmação explícita com justificativa.
- Itens inalterados (já vinculados ao pastor e mantidos selecionados) não geram comando nem mutação.
- Cada entidade no lote recebe um `commandId` estável independente (`comandoOpaco()`) e o `expectedVersion` correspondente.
- A orquestração cliente processa cada item individualmente via `gerenciarVinculo`, sem transação monolítica ou simulação de rollback destrutivo.
- Exibir resumo quantitativo claro ("X concluídos com sucesso, Y falhas") e detalhamento por item.
- Botão de retentativa reenvia apenas os itens falhos elegíveis, mantendo o mesmo `commandId`.
- Em caso de conflito concorrente (`aborted` / versão desatualizada), o item é marcado como conflito e oferece reabertura de revisão individual com dados atualizados e novo `commandId`.
- Redirecionar apenas pendências não decididas, mantendo decisões históricas imutáveis associadas ao responsável original.
- Garantir acessibilidade WCAG 2.2 AA: touch targets ≥ 44px, contraste ≥ 4.5:1, foco visível gerenciável por teclado e status com texto + ícone.

**Never:**
- Nunca executar mutações em lote através de transação única ou simular atomicidade global ("tudo ou nada").
- Nunca reverter ou sobrescrever decisões históricas tomadas por responsáveis anteriores.
- Nunca reenviar itens que já obtiveram sucesso ao solicitar retentativa de falhas.
- Nunca encerrar um vínculo vigente silenciosamente pela simples desmarcação de um checkbox.
- Nunca usar cores isoladas para comunicar status de execução ou erro.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Seleção de Pastor | Usuário seleciona pastor na lista de pessoas | Exibe cabeçalho com identidade do pastor e ativa modo centrado no pastor | Mensagem se busca de pessoas falhar |
| Seleção de Igrejas (Inclusão) | Seleciona 2 igrejas sem responsável | Painel lista 2 inclusões com data efetiva; botão salvar ativo | Validação de data não retroativa além do limite |
| Substituição de Responsável | Seleciona igreja com outro responsável vigente | Painel destaca substituição, exibe responsável anterior e aviso de pendências não decididas | Confirmação detalhada na revisão |
| Desmarcação de vínculo vigente | Desmarca igreja já vinculada ao pastor | Abre diálogo modal de confirmação de encerramento; se cancelado, mantém marcada; se confirmado, marca para encerramento | Justificativa opcional |
| Item inalterado | Igreja já pertencia ao pastor e continua marcada | Marcada como "Inalterada"; não entra na contagem de comandos nem gera mutação | N/A |
| Falha parcial no lote | 2 sucessos e 1 falha de rede/timeout | Exibe resumo "2 concluídos com sucesso, 1 falha"; botão "Tentar novamente falhas" ativo | Reenvio usa mesmo `commandId` apenas para a falha |
| Conflito Concorrente (`ABORTED`) | Servidor retorna conflito de versão em 1 item | Item marcado como "Conflito de versão"; ação "Atualizar e reavaliar" permite atualizar versão e confirmar novamente com novo `commandId` | Não afeta os itens que já tiveram sucesso |
| Retorno ao fluxo individual | Clique em "Voltar ao modo individual" ou "Limpar seleção" | Restaura visualização padrão de igrejas/equipes com cartões individuais | Alerta se houver alterações não salvas |

</frozen-after-approval>

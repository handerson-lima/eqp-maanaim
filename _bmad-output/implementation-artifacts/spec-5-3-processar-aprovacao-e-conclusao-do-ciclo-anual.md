---
title: 'Story 5.3: Processar aprovação e conclusão do ciclo anual'
type: 'feature'
created: '2026-10-07'
status: 'in-progress'
baseline_commit: HEAD
route: 'dispatch'
review_loop_iteration: 1
context:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
Com a manifestação de renovação anual "CONTINUAR" registrada pelo voluntário (Story 5.2), foi criado um ciclo anual determinístico em `ciclos/{cicloId}` no estado inicial `AGUARDANDO_PASTOR_LOCAL`, associado a uma participação `ATIVA`.
Para que o voluntário renove formalmente seu período por mais 1 ano, o ciclo anual deve percorrer a cadeia canônica de deliberação:
1. **Pastor Local vigente:** Delibera sobre a renovação espiritual e eclesiástica da participação do voluntário de sua igreja. Se favorável, avança o ciclo para `AGUARDANDO_RESPONSAVEL_EQUIPE`. Se desfavorável, transiciona o ciclo para `REJEITADO`, programa o encerramento da participação ao término de sua vigência atual e exibe a mensagem canônica neutra *"Procure o Pastor da igreja local para mais informações"*.
2. **Responsável de Equipe vigente:** Delibera sobre a continuidade do voluntário na equipe específica sob sua responsabilidade. Se favorável, avança o ciclo para `AGUARDANDO_COORDENADOR`. Se desfavorável, transiciona o ciclo para `REJEITADO` com mensagem neutra ao voluntário, preservando as demais equipes.
3. **Coordenador Geral:** Homologa a renovação anual após confirmação da Reunião de Pastores (`confirmouReuniaoPastores == true`). Se aprovado, conclui o ciclo anual (`CONCLUIDO`), calcula uma nova vigência de exatamente 1 ano (`calcularVigenciaAnual`), atualiza `vigenciaInicio` e `vigenciaFim` na participação, aponta `cicloAtualId` para o ciclo concluído e zera os estados transitórios de renovação. Se desfavorável, rejeita o ciclo com mensagem neutra.

**Approach:**
1. **Backend (Cloud Functions TypeScript):**
   - Comandos transacionais dedicados com validação de autoridade e concorrência:
     * `decidirCicloAnualPastor`: valida vínculo vigente do pastor da igreja da ficha.
     * `decidirCicloAnualResponsavel`: valida vínculo de responsabilidade vigente na equipe do ciclo.
     * `concluirCicloAnualCoordenador`: valida autoridade de coordenador em `autoridadesAdministrativas`, exige reunião de pastores, conclui o ciclo e calcula a nova vigência anual (AD-7/AD-11).
   - Atualização das filas:
     * `obterFilaPastorLocal`, `obterFilaResponsavelEquipe` e `obterFilaCoordenador` incluem itens de renovação com distinção clara (`tipo: 'RENOVACAO_ANUAL'`).
   - Idempotência (`commands/{commandId}`), evidência imutável (`evidenciasDecisao/{commandId}`) e auditoria sem PII (`auditOutbox/{commandId}`).
2. **Frontend (Flutter Web/PWA):**
   - Gateways e serviços atualizados com os novos métodos.
   - Filas do Pastor, Responsável de Equipe e Coordenador exibem badge semântico visual *"Ciclo Anual {ano}"*.
   - Diálogos de confirmação e recusa com justificativa interna e mensagem neutra ao voluntário.
   - Total conformidade com WCAG 2.2 AA e alvos de toque $\ge 44\text{px}$.

## Boundaries & Constraints
- Ciclos anteriores e histórico permanecem 100% append-only e imutáveis (AD-7).
- Independência estrita entre equipes: decisões em uma equipe nunca revertem nem alteram outras participações (AD-11).
- Mensagem ao voluntário em decisão desfavorável estritamente neutra: *"Procure o Pastor da igreja local para mais informações"*, sem expor justificativa interna nem o termo "rejeitado".

</frozen-after-approval>

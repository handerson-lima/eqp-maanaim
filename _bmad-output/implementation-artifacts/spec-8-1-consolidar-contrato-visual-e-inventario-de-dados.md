---
title: '8.1 — Consolidar contrato visual e inventário de dados'
type: chore
created: '2026-10-08'
status: in-progress
route: dispatch
baseline_commit: 28955146786a328768535d8ef5473c3271f39e59
review_loop_iteration: 0
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md
---

<frozen-after-approval reason="intenção autorizada explicitamente pelo usuário nesta conversa">

## Intent

**Problema:** as referências UX divergem e a referência visual pressupõe dados e jornadas ainda ausentes. A história 8.1 estabelece o contrato documental para corrigir as telas sem infringir privacidade ou invariantes.

**Abordagem:** adotar o épico 8, preservar o acompanhamento anterior, consolidar documentos UX e produzir inventário verificável de componentes/fontes/campos, composições e métricas. O usuário autorizou execução integral da história documental; não há decisão de intenção pendente nem ação irreversível.

## Boundaries & Constraints

**Sempre:** seguir SPEC, PRD, ADs, acessibilidade e precedência do pacote ux/. Distinguir existente, planejado e homologado. Cada lacuna possui história responsável. Preservar históricos, resultados por equipe, evidências e autorização temporal no servidor.

**Nunca:** alterar código da aplicação, implementar 8.2, executar deploy, ampliar coleta de PII, fabricar números ou afirmar homologação de telas. Não alterar os ADs nem reescrever aceites históricos dos épicos 1–7.

</frozen-after-approval>

## Code Map

- `_bmad-output/planning-artifacts/ux/` — pacote normativo; imagem inspecionada pelo agente principal. Sidebar navy/topbar clara; dashboards e análise em duas áreas; imagem não autoriza rejeição pública, validade única ou PDF consolidado.
- `_bmad-output/planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/{DESIGN,EXPERIENCE}.md` — corrigir paleta/raios/escala Material legados e exemplo negativo.
- `flutter_app/lib/ui/{tokens,theme}.dart`, `ui/components/` — inspecionar/reutilizar nomes reais; nenhuma edição. Geometria atual: sidebar220/topbar64/card10/input6/alvo44.
- `functions/src/{domain,repositories}/dashboardRenovacao.ts` — dados existentes por participação; próximos pastoral usa classificação exclusiva 30d, não contagem geral de vencimento. Não assumir equivalência aos KPIs gerais.
- `functions/src/repositories/termos.ts` — publicação conta fichas ATIVA; não persiste universo nominal por versão; aceitarTermoVigente recusa ficha fora de RASCUNHO. 8.14 deve cobrir novo aceite ativo e projeção, não só UI.
- `_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md` — investigação dedicada dos contratos; conferir quando disponível e complementar sem alterar código.
- `functions/src/domain/consultaAuditoria.ts` — auditoria possui cursor, relatório não; filtros de ator e voluntário distintos.

## Tasks & Acceptance

**Execução:**
- [ ] `_bmad-output/planning-artifacts/epics.md`, `correcao-ui/epic-8-correcao-ui.md`, `sprint-change-proposal-2026-10-08.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml` — adotar épico8, registrar inclusão inicial das 16 histórias backlog; somente8.1 progride, épico8 in-progress. Acrescentar referência explícita corretiva de UX-DR1/6.5 sem editar história original; reconhecer épico7 existente.
- [ ] `_bmad-output/planning-artifacts/ux/{DESIGN-SYSTEM,SCREEN-SPECS,UX-LAYOUT-SPEC,COMPONENT-CATALOG}.md` e DESIGN/EXPERIENCE legados — eliminar divergências em seus textos originais e vincular contrato consolidado. Tokens acessíveis documentais com pares calculados, sem implementar8.2.
- [ ] `_bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md` — decisões, assets disponíveis, apresentação sem número se não persistido, composições mobile/tablet/desktop e navegação/estados S01–S14. Wireframes textuais espaciais suficientes; extras também mapeados.
- [ ] `_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md` — validar tabela de telas, componentes, gateways/callables, campos existentes/ausentes, tarefas atribuídas às histórias futuras.
- [ ] `_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md` — companion sem alterar ADs: contexto mínimo, KPIs com entidade/escopo/período/atualização e filtros, privacidade, PDF, vigência, catálogo, cursor e lotes por item. Definir universo dos aceites por versão e limitações históricas.
- [ ] `_bmad-output/planning-artifacts/correcao-ui/matriz-validacao-ui.md` e `validacao-8-1.md` — rastrear cobertura documental e ACs, sem marcar homologação visual. Conferir links, estados, preservação de histórico e ausência de mudanças de código.

**Critérios de aceite:**
1. Dadas S01–S14, quando consultado o pacote, então cada tela possui composição, estados, navegação e lacunas atribuídas à história correspondente.
2. Dados conflitos de tokens, mensagem negativa, PDF, vigência, responsável único e Google, quando aplicada a precedência, então os textos convergem sem alteração dos ADs.
3. Dados KPIs, quando implementados conforme companion, então unidade, entidade, escopo, período e atualização são explícitos, sem misturar fichas e participações ou contar só página.
4. Dadas múltiplas alterações de vínculo, quando salvas, então a experiência define resultado e retry por item sem atomicidade global.

## Implementation Notes

2026-10-08: baseline limpa na branch main. Execução documental já autorizada; não solicitar reaprovação do mesmo escopo. Compilação de contexto e investigação delegadas conforme bmad-build. Inventário pode chegar durante a execução; aguardar sua presença antes de validar.

## Spec Change Log

## Review Triage Log

## Verification

Conferir diff completo contra baseline, links locais, cobertura S01–S14, pares de contraste calculados e igualdade de development_status/action_items anteriores. Não executar testes Flutter/Emulator sem código alterado; não declarar telas homologadas. Registrar resultados em validacao-8-1.md. Agente implementador deve deixar spec e8.1 em review para conferência final pelo agente principal;8.2–8.16 backlog.

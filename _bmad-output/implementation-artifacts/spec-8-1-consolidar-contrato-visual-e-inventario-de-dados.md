---
title: '8.1 — Consolidar contrato visual e inventário de dados'
type: chore
created: '2026-10-08'
status: done
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
- `flutter_app/lib/ui/{tokens,theme}.dart`, `ui/components/` — inspecionar/reutilizar nomes reais; nenhuma edição. Geometria atual: sidebar 220/topbar 64/card10/input6/alvo44.
- `functions/src/{domain,repositories}/dashboardRenovacao.ts` — dados existentes por participação; próximos pastoral usa classificação exclusiva 30d, não contagem geral de vencimento. Não assumir equivalência aos KPIs gerais.
- `functions/src/repositories/termos.ts` — publicação conta fichas ATIVA; não persiste universo nominal por versão; aceitarTermoVigente recusa ficha fora de RASCUNHO. 8.14 deve cobrir novo aceite ativo e projeção, não só UI.
- `_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md` — investigação dedicada dos contratos; conferir quando disponível e complementar sem alterar código.
- `functions/src/domain/consultaAuditoria.ts` — auditoria possui cursor, relatório não; filtros de ator e voluntário distintos.

## Tasks & Acceptance

**Execução:**
- [x] `_bmad-output/planning-artifacts/epics.md`, `correcao-ui/epic-8-correcao-ui.md`, `sprint-change-proposal-2026-10-08.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml` — adotar épico 8, registrar inclusão inicial das 16 histórias backlog; somente 8.1 progride, épico 8 in-progress. Acrescentar referência explícita corretiva de UX-DR1/6.5 sem editar história original; reconhecer épico 7 existente.
- [x] `_bmad-output/planning-artifacts/ux/{DESIGN-SYSTEM,SCREEN-SPECS,UX-LAYOUT-SPEC,COMPONENT-CATALOG}.md` e DESIGN/EXPERIENCE legados — eliminar divergências em seus textos originais e vincular contrato consolidado. Tokens acessíveis documentais com pares calculados, sem implementar 8.2.
- [x] `_bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md` — decisões, assets disponíveis, apresentação sem número se não persistido, composições mobile/tablet/desktop e navegação/estados S01–S14. Wireframes textuais espaciais suficientes; extras também mapeados.
- [x] `_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md` — validar tabela de telas, componentes, gateways/callables, campos existentes/ausentes, tarefas atribuídas às histórias futuras.
- [x] `_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md` — companion sem alterar ADs: contexto mínimo, KPIs com entidade/escopo/período/atualização e filtros, privacidade, PDF, vigência, catálogo, cursor e lotes por item. Definir universo dos aceites por versão e limitações históricas.
- [x] `_bmad-output/planning-artifacts/correcao-ui/matriz-validacao-ui.md` e `validacao-8-1.md` — rastrear cobertura documental e ACs, sem marcar homologação visual. Conferir links, estados, preservação de histórico e ausência de mudanças de código.

**Critérios de aceite:**
1. Dadas S01–S14, quando consultado o pacote, então cada tela possui composição, estados, navegação e lacunas atribuídas à história correspondente.
2. Dados conflitos de tokens, mensagem negativa, PDF, vigência, responsável único e Google, quando aplicada a precedência, então os textos convergem sem alteração dos ADs.
3. Dados KPIs, quando implementados conforme companion, então unidade, entidade, escopo, período e atualização são explícitos, sem misturar fichas e participações ou contar só página.
4. Dadas múltiplas alterações de vínculo, quando salvas, então a experiência define resultado e retry por item sem atomicidade global.

## Implementation Notes

2026-10-08: baseline limpa na branch main. Execução documental já autorizada; não solicitar reaprovação do mesmo escopo. Compilação de contexto e investigação delegadas conforme bmad-build. Inventário pode chegar durante a execução; aguardar sua presença antes de validar.

## Spec Change Log

## Review Triage Log

| Achado | Veredito | Evidência e encaminhamento |
|---|---|---|
| Blind-1 vínculo sem término | medium | repositories/vinculos.ts cria fimVigencia nulo; corrigir fórmula documental para limite superior aberto. patch. |
| Blind-2 estados M em autenticação/PDF | medium | Firebase Auth e leitura de URL não usam o mesmo recibo de mutação; corrigir classificação e sucesso por operação. patch. |
| Blind-3 shell público | medium | Cadastro/recuperação precedem sessão; explicitar exceções públicas no contrato. patch. |
| Blind-4 renovação unitária/falha parcial | false | ParticipacaoGateway recebe manifestacoes[], e executarManifestarRenovacaoRepo valida todos os itens e grava em uma runTransaction com recibo único. Não existe o loop de comandos individuais alegado. Clarificar inventário para evitar leitura ambígua; não introduzir lote parcial inexistente. |
| Blind-5 novo ativo após publicação | medium | U(V) não inclui ficha em aprovação na publicação e a frase “no seu fluxo” omite o próximo aceite após ativação. Esclarecer pendência operacional de ativo fora do universo histórico, sem invalidar evidências anteriores. patch. |
| Blind-6 ciclo expirado relevante | medium | A definição não resolve renovação aberta versus ciclo anterior final; explicitar estado atual da participação e ciclo que fundamenta expiração, com exemplos. patch. |
| Blind-7 denominador de equipes | medium | Ciclos pertencem a participações; explicitar grupo inicial por envio persistido e linhas anuais por participação/ciclo, documentando lacuna de agrupamento. patch. |
| Blind-8 grid mobile | low | UX-LAYOUT permite 1/2 colunas e contrato fixa uma; alinhar exceção por largura útil, alvos e texto ampliado. patch. |
| Blind-9 relatório para Minha Ficha | medium | Gateways próprios não consultam ficha alheia; nomear variante de consulta autorizada S09 com retorno aos filtros e sem edição própria. patch. |
| Blind-10 verificador temporário | low | Script reside em /tmp; guardar cópia reproduzível no pacote documental e referenciá-la. patch. |
| Edge-1 vínculo sem término | medium | Mesmo defeito de Blind-1, verificado no registro de vínculo; patch conjunto, preservando esta linha individual. |

Revisão verification-gap: nenhum gap de verificação encontrado. Revisões independentes concluídas em 09/10/2026; nenhum achado pede alteração de código da aplicação. Todas as correções são esclarecimentos locais dos artefatos documentais previstos, sem alteração do objetivo, ADs ou endpoints.

## Verification

Conferir diff completo contra baseline, links locais, cobertura S01–S14, pares de contraste calculados e igualdade de development_status/action_items anteriores. Não executar testes Flutter/Emulator sem código alterado; não declarar telas homologadas. Registrar resultados em validacao-8-1.md. Agente implementador deve deixar spec e8.1 em review para conferência final pelo agente principal; 8.2–8.16 backlog.


## Registro da implementação documental

09/10/2026: tarefas documentais concluídas e encaminhadas à revisão do agente principal; 8.1 e spec em review. A adoção preserva épicos 1–7/action_items; 8.2–8.16 backlog. Nenhum código/AD/deploy alterado. Evidências e limitações em `_bmad-output/planning-artifacts/correcao-ui/validacao-8-1.md`.

## Encerramento da conferência — 09/10/2026

Três revisões independentes realizadas: blind-hunter (10 achados), edge-case (1, mesma causa do vínculo sem término), verification-gap (nenhum gap). Os esclarecimentos classificados patch foram aplicados e conferidos. Blind-4 foi refutado contra gateway/repositório; o inventário agora explicita a transação única da renovação. Conferência final também fixou as unidades de todas as métricas de relatório, separou pendência operacional de aceite e universo histórico e esclareceu a cobertura textual S10–S14. AC1–AC4 atendidos documentalmente; nenhum código alterado e nenhuma tela homologada. Spec done; sprint mantém review conforme etapa final do bmad-build, para aceite no acompanhamento. Histórias 8.2–8.16 não iniciadas.

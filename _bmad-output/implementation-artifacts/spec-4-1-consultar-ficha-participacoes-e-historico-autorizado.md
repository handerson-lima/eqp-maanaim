---
title: 'Story 4.1: Consultar ficha, participações e histórico autorizado'
type: 'feature'
created: '2026-10-06'
status: 'done'
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
Voluntários e líderes com papéis institucionais (Pastor Local, Responsável de Equipe, Coordenador Geral e Administradores) precisam consultar fichas, participações ativas/históricas, ciclos de vigência e a linha do tempo auditável de eventos e decisões.
Entretanto, o sistema precisa garantir:
1. **Isolamento Estrito de Escopo em Runtime (AD-9, AD-12):**
   - O Voluntário só acessa seus próprios dados e linha do tempo pessoal.
   - O Pastor Local acessa somente voluntários e participações vinculados à sua igreja vigente.
   - O Responsável de Equipe acessa exclusivamente voluntários e participações sob sua equipe vigente (se um voluntário atua na Equipe A e Equipe B, o líder da Equipe A não pode visualizar dados da Equipe B).
   - Coordenadores e Administradores possuem escopo global mediante validação de vínculo/autoridade vigente.
   - NUNCA autorizar apenas por Custom Claim estático: validar identidade, vínculo institucional vigente e temporalidade a cada consulta.
2. **Sanitização Canônica e Sigilo Pastoral (AD-12, FR28):**
   - Na linha do tempo do voluntário, qualquer decisão desfavorável oculta rigorosamente justificativas internas, atores avaliadores desfavoráveis e o termo "rejeitado", exibindo unicamente a mensagem neutra canônica: *"Procure o Pastor da igreja local para mais informações"*.
   - Apenas líderes autorizados no escopo da decisão visualizam as justificativas internas e detalhes dos avaliadores.
3. **Linha do Tempo Append-Only Imutável:**
   - Projeção consolidada a partir de `auditOutbox` e `evidenciasDecisao`.
   - Visualização estritamente somente-leitura, sem rotas de edição ou exclusão de eventos passados.

**Approach:**
1. **Backend (Cloud Functions - Winston & Amelia):**
   - Endpoint autenticado `consultarFichaAutorizada`:
     * Recebe `fichaId` (se omitido ou se o ator for voluntário sem papel privilegiado, assume o UID autenticado).
     * Revalida o escopo dinamicamente:
       - Se for o próprio voluntário (`auth.uid === fichaId`): acesso liberado com projeção sanitizada.
       - Se for Pastor Local: valida se a ficha pertence a uma igreja onde `pastorLocalVigentePessoaId === auth.uid` e vínculo vigente ativo.
       - Se for Responsável de Equipe: valida se a ficha possui participação em equipe onde `responsavelVigentePessoaId === auth.uid` com vínculo vigente, filtrando para retornar APENAS as participações daquela equipe.
       - Se for Coordenador/Admin: valida autoridade administrativa vigente.
       - Se não cumprir os critérios: lança `permission-denied` neutro sem vazar a existência do registro.
   - Endpoint autenticado `consultarLinhaDoTempoAutorizada`:
     * Busca os eventos de auditoria e evidências da ficha e participações permitidas no escopo.
     * Sanitiza os eventos conforme o papel do requisitante:
       - Voluntário: eventos formatados com linguagem acolhedora, mascarando UIDs de avaliadores desfavoráveis e substituindo justificativas pelo texto canônico neutro.
       - Avaliadores autorizados: eventos completos com snapshot do ator, papel, data/hora UTC e justificativa interna.
2. **Frontend Flutter Web/PWA Mobile-First (Sally + Amelia):**
   - Criação do componente e tela `LinhaDoTempoAuditavelWidget` e `ConsultaFichaAutorizadaScreen` (e integração na `MinhaFichaScreen`):
     * Design system canônico (`navy-900`, `blue-600`, `gray-100`, etc.), sem gradientes e sem glassmorphism.
     * Nós conectores verticais no mobile (layout compacto em coluna única, cards verticais com alvos de toque >= 44px).
     * Painel responsivo no desktop com detalhes e chips semânticos com texto descritivo (não apenas cor).
     * Tratamento de estados: loading suave, empty ("Nenhum evento registrado"), error e feedback de permissão.

## Boundaries & Constraints

**Always:**
- Revalidar autoridade, papel e vínculo vigente no banco de dados a cada requisição de consulta.
- Garantir isolamento territorial (igreja) e funcional (equipe).
- Exibir a mensagem canônica *"Procure o Pastor da igreja local para mais informações"* em qualquer indeferimento visto pelo voluntário.
- Preservar acessibilidade WCAG 2.2 AA (touch target >= 44px, contraste elevado, estados com texto e ícone).
- Respeitar estritamente o Design System corporativo e os tokens normativos.

**Never:**
- Nunca autorizar consulta unicamente por custom claims sem validar vínculos vigentes.
- Nunca expor participações de outras equipes para um responsável de equipe concorrente.
- Nunca expor justificativas internas, dados confidenciais ou a palavra "rejeitado" para o voluntário.
- Nunca expor PII desnecessária em logs ou eventos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Voluntário consulta sua própria ficha e timeline | `auth.uid === fichaId` | Retorna ficha completa do voluntário, participações e timeline sanitizada | `200 OK` |
| Pastor Local consulta ficha de sua igreja vigente | Pastor com vínculo vigente na igreja da ficha | Retorna dados da ficha, todas as participações da igreja e timeline com justificativas pastorais | `200 OK` |
| Pastor Local tenta consultar ficha de outra igreja | Pastor sem vínculo vigente na igreja da ficha | Acesso negado | `permission-denied` (sem revelar existência) |
| Responsável de Equipe consulta ficha com múltiplas equipes | Responsável pela Equipe A; voluntário tem Equipe A e Equipe B | Retorna dados básicos e APENAS a participação da Equipe A e eventos da Equipe A | `200 OK` (Equipe B estritamente oculta) |
| Responsável consulta ficha sem participação na sua equipe | Voluntário não tem solicitação na equipe do líder | Acesso negado | `permission-denied` |
| Voluntário visualiza evento desfavorável na timeline | Decisão pastoral ou de equipe desfavorável | Evento exibe mensagem canônica neutra, sem justificativa interna e sem nome do avaliador | `200 OK` sanitizado |
| Ex-responsável (vínculo revogado) tenta consultar via deep link | `auth.uid` com vínculo expirado/substituído | Acesso imediatamente bloqueado pela revalidação dinâmica | `permission-denied` |

</frozen-after-approval>

## Code Map

- `functions/src/domain/consultaHistorico.ts` -- Modelagem, contratos de projeção autorizada, tipos de evento da linha do tempo e regras de sanitização por papel.
- `functions/src/repositories/consultaHistorico.ts` -- Repositório com validação de escopo dinâmico em runtime (Pastor, Responsável, Coordenador, Voluntário) e montagem de timeline segura.
- `functions/src/commands/consultarFichaAutorizada.ts` -- Callable autenticada para consulta de ficha e participações autorizadas no escopo.
- `functions/src/commands/consultarLinhaDoTempoAutorizada.ts` -- Callable autenticada para consulta da linha do tempo com sanitização contextual.
- `functions/test/consultaHistoricoAutorizado.test.ts` -- Suíte abrangente no Vitest cobrindo isolamento de escopo (igreja e equipe), sanitização de indeferimento e segurança contra acessos expirados.
- `flutter_app/lib/features/voluntario/historico_service.dart` -- Gateway e modelos de dados para consulta autorizada de ficha e linha do tempo.
- `flutter_app/lib/features/voluntario/linha_tempo_widget.dart` -- Componente mobile-first de linha do tempo com tokens canônicos, nós conectores, suporte a leitor de tela e WCAG 2.2 AA.
- `flutter_app/test/consulta_historico_autorizado_test.dart` -- Testes de widget garantindo renderização responsiva, texto neutro para o voluntário, ocultação de dados de outras equipes e acessibilidade.

## Review Findings (code review 2026-10-07)

### Patch
- [x] [Review][Patch] Voluntário vê o termo proibido "REJEITADA" — o servidor projeta `estado` cru (`repositories/consultaHistorico.ts:237`, `:264`, `:275`) e a UI o renderiza via `StatusChip` (`consulta_ficha_screen.dart:194`, `:297`), cujo mapeamento exibe `REJEITADA` (`ui/components/status_chips.dart:87`). Fixar padronização neutra do `estado` para o voluntário (o mesmo tratamento dado a `proximaAcao`/`mensagemVoluntario`). [consulta_ficha_screen.dart:194,297]
- [x] [Review][Patch] Responsável de Equipe recebe eventos fora do escopo com justificativas internas — o filtro de equipe só descarta evidência quando `equipeId` existe (`repositories/consultaHistorico.ts:373`); eventos pastorais/coordenação sem `equipeId` sobrevivem e são projetados com `ator` + `justificativaInterna` (`:394`, `:424`, `:438`), pois `ehProprioVoluntario` é falso. Aplicar isolamento estrito por equipe também a eventos sem `equipeId`, ou ocultar justificativas pastorais de responsáveis de equipe. [repositories/consultaHistorico.ts:373]
- [x] [Review][Patch] Região do callable divergente quebra a feature — o cliente usa `FirebaseFunctions.instanceFor(region: 'southamerica-east1')` (`historico_service.dart:200`) enquanto nenhum callable declara região (sem `setGlobalOptions`/`region`) e os demais serviços usam `FirebaseFunctions.instance` (default `us-central1`). Alinhar à região default do projeto. [historico_service.dart:200]
- [x] [Review][Patch] Pastor Local autoriza sem vínculo vigente válido/temporal — quando `pastorLocalVigenteVinculoId` está ausente ou o documento não existe (`vDoc.exists` falso), `vinculoAtivo` permanece `true` (`repositories/consultaHistorico.ts:76-89`); o fallback em `vinculosPastorIgreja` aceita `estado === 'VIGENTE'` sem janela `inicioVigencia/fimVigencia` e sem exigir igreja ativa (`:101-116`). Revalidar identidade + vigência temporal (AD-2/AD-3). [repositories/consultaHistorico.ts:77]
- [x] [Review][Patch] Coleção de vínculo de equipe incorreta — `consultaHistorico.ts` consulta `vinculosResponsavelEquipe` (`:136`), coleção inexistente; a canônica é `vinculosPastorEquipe` (`decisaoResponsavelEquipe.ts:64`, `vinculos.ts`, `firestore.rules`). O caminho de autoridade por vínculo nunca casa em produção. [repositories/consultaHistorico.ts:136]
- [x] [Review][Patch] Timestamps da linha do tempo fabricados/derivados de campos mutáveis — fallback `new Date().toISOString()` injeta hora atual em eventos de auditoria (`:332`, `:347`, `:363`), `ENVIO_APROVACAO` usa `fichaData.atualizadoEm` (mutável a cada edição, `:347`) e os marcos são sintetizados de `fichas` em vez das evidências append-only (`:324-351`). Usar timestamps persistidos e imutáveis. [repositories/consultaHistorico.ts:332,347,363]
- [x] [Review][Patch] Evidência negativa do Coordenador sempre exibida como sucesso — o ramo `COORDENADOR_GERAL` não lê `decisao` e emite sempre `HOMOLOGACAO_COORDENACAO` + `estadoVisual: 'CONCLUIDO'` (`:426-439`), mascarando indeferimento/cancelamento. [repositories/consultaHistorico.ts:426]
- [x] [Review][Patch] Filtro `participacaoId` vaza evidências sem `participacaoId` — `if (participacaoIdFiltro && partId && partId !== participacaoIdFiltro)` deixa passar eventos sem `partId` (`:368`); além disso a UI nunca envia `participacaoId`, tornando a timeline por participação inalcançável. [repositories/consultaHistorico.ts:368]
- [x] [Review][Patch] Mascaramento de CPF com caminho vazio — `cpfCompleto` recebia `rawCpf` (podendo ser `''`) para voluntário/coordenador (`repositories/consultaHistorico.ts:215-217`) e `cpfExibicao` devolvia string vazia. Corrigido exigindo CPF não vazio; a divergência de formato entre `domain/consultaHistorico.ts:109` (`***.456.789-**`) e `repositories/decisaoCoordenador.ts:63` (`123.***.***-01`) foi movida para Deferred (ambos os formatos são canônicos e testados em seus contextos). [repositories/consultaHistorico.ts:215]
- [x] [Review][Patch] Mensagem interna de erro repassada ao cliente — comandos retornam `error.message` dentro de `HttpsError('internal', …)` (`commands/consultarFichaAutorizada.ts:41`, `commands/consultarLinhaDoTempoAutorizada.ts:43`), divergindo do padrão genérico adotado em outros comandos. [consultarFichaAutorizada.ts:41]
- [x] [Review][Patch] Payload não validado — `payload.fichaId`/`participacaoId` são usados sem verificação de tipo; um valor não-string chega a `.trim()` (`repositories/consultaHistorico.ts:182`, `:306`) e vira `internal` em vez de rejeição de validação. [repositories/consultaHistorico.ts:182]
- [x] [Review][Patch] Evento da timeline sem snapshot do vínculo — `EventoLinhaDoTempo.ator` só tem `{nome, papel}` (`domain/consultaHistorico.ts:80-83`); o AC pede ator, papel/vínculo em snapshot, data/hora. [domain/consultaHistorico.ts:80]
- [x] [Review][Patch] Falha parcial derruba a tela inteira — `Future.wait([ficha, timeline])` sem tratamento individual (`consulta_ficha_screen.dart:61-90`): falha da timeline descarta a ficha carregada e mostra "Acesso Restrito". Tratar cada chamada separadamente. [consulta_ficha_screen.dart:61]
- [x] [Review][Patch] Tela `ConsultaFichaAutorizadaScreen` inalcançável — nenhum componente/rota a constrói (a integração em `MinhaFichaScreen` usa apenas `LinhaDoTempoWidget`); vira código morto. Ligar via navegação ou remover. [consulta_ficha_screen.dart:12]
- [x] [Review][Patch] Layout responsivo desktop da linha do tempo não implementado — `isDesktop` é calculado e repassado (`linha_tempo_widget.dart:39`, `:80`) mas nunca usado (`:203`, `:208`); implementar painel desktop de duas colunas (lista + detalhe) com tokens canônicos, mantendo coluna única no mobile (decisão: implementar agora). [linha_tempo_widget.dart:203]
- [x] [Review][Patch] Teste ausente: isolamento da timeline para Responsável de Equipe — nenhum caso cobre descarte de evidências de outra equipe (`functions/src/repositories/consultaHistorico.ts:373`); inverter o `continue` passa na suíte. [test/consultaHistoricoAutorizado.test.ts]
- [x] [Review][Patch] Teste ausente: exposição de CPF por papel — não há asserção de CPF para `PASTOR_LOCAL` (mascarado) e `COORDENADOR_GERAL`/`ADMINISTRADOR` (completo). [repositories/consultaHistorico.ts:215]
- [x] [Review][Patch] Teste ausente: filtro `participacaoId` da timeline — nenhum teste passa o 4º argumento ao repositório. [repositories/consultaHistorico.ts:368]
- [x] [Review][Patch] Teste ausente: caminho autenticado do callable e mapeamento de erro — os testes só cobrem `auth: null`; nada verifica forwarding de argumentos nem `AcessoNaoAutorizadoError` → `permission-denied`. [commands/consultarFichaAutorizada.ts:25]
- [x] [Review][Patch] Inconsistência de fuso entre vigência e timeline — vigência formatada com `.toUtc()` (`consulta_ficha_screen.dart:421`) e eventos com `.toLocal()` (`linha_tempo_widget.dart:470`), podendo divergir em um dia. [consulta_ficha_screen.dart:421]
- [x] [Review][Patch] Estado desconhecido tratado como sucesso — `estadoVisual` ausente/desconhecido cai no default `'CONCLUIDO'` (`historico_service.dart:45`; `linha_tempo_widget.dart:453`), renderizando "Concluído" verde para status inválido. [historico_service.dart:45]
- [x] [Review][Patch] Classificação de erro por substring — falha de rede vs. autorização decidida por `e.toString().contains('permission-denied')` (`consulta_ficha_screen.dart:74`) em vez de `FirebaseFunctionsException.code`. [consulta_ficha_screen.dart:74]
- [x] [Review][Patch] `Semantics` sem `container`/`ExcludeSemantics` duplica anúncio — o leitor de tela pode anunciar o rótulo do item e todos os descendentes (`linha_tempo_widget.dart:214`). [linha_tempo_widget.dart:214]

### Deferred
- [x] [Review][Defer] Leituras sensíveis não geram trilha de auditoria — `consultarFichaAutorizada`/`consultarLinhaDoTempoAutorizada` expõem CPF integral (próprio/coordenador/admin) e histórico completo sem gravar `auditOutbox`/evidência de acesso. [commands/consultarFichaAutorizada.ts:25] — deferred: política de auditoria de leitura (finalidade/retenção) a definir.
- [x] [Review][Defer] Mensagem canônica duplicada — `MENSAGEM_CANONICA_DECISAO_NEGATIVA`/`MENSAGEM_NEUTRA_CANONICA` (`domain/mensagens.ts`) não são usadas; `decisaoPastor.ts:10`, `decisaoResponsavelEquipe.ts:10` e `decisaoCoordenador.ts:10` mantêm cópias literais. — deferred: pré-existente, migrar as três constantes sai do escopo da consulta.
- [x] [Review][Defer] Tipo de evento `CANCELAMENTO` declarado e nunca produzido — pertence às Stories 4.3/4.4 de cancelamento. [domain/consultaHistorico.ts:73] — deferred: estado ainda não alcançável nesta entrega. (A decisão negativa do Coordenador foi corrigida no patch correspondente.)
- [x] [Review][Defer] Sanitização por heurística de substring — `sanitizarEventoParaVoluntario` só detecta negativa por `estadoVisual`/`'desfavor'`/`'rejeit'` (`domain/consultaHistorico.ts:124-127`); hoje os eventos negativos gerados sempre carregam `ORIENTACAO_PASTORAL`, mas um novo tipo poderia escapar. — deferred: sem caso alcançável atual.
- [x] [Review][Defer] Código morto `FichaNaoEncontradaConsultaError` nunca lançado (o repo lança `AcessoNaoAutorizadoError`). [domain/consultaHistorico.ts:12] — deferred: limpeza sem impacto funcional.
- [x] [Review][Defer] Leituras sem limite/paginação e N+1 — `consultarLinhaDoTempoAutorizadaRepo` lê todas as `evidenciasDecisao`/`participacoes` sem `limit` e faz leitura de `equipes` por evidência (`repositories/consultaHistorico.ts:354`, `:401`, `:246`). — deferred: otimização de custo/latência, sem impacto funcional imediato.
- [x] [Review][Defer] Estados `CANCELADA`/`EXPIRADA` não sanitizados como negativa para o voluntário — resolvido no patch de estado público (`ehEstadoNegativo` cobre `REJEITADA`/`CANCELADA`/`EXPIRADA`). Registro mantido como histórico.
- [x] [Review][Defer] Formatos divergentes de mascaramento de CPF — `domain/consultaHistorico.ts:109` (`***.456.789-**`) vs `repositories/decisaoCoordenador.ts:63` (`123.***.***-01`). — deferred: ambos os formatos são testados e exibidos em telas distintas; unificar é decisão de UX fora do escopo desta story.

### Rejected
- `false` — ID opaco vs. ownerUid (BH17/AA7): a ficha é criada com doc id = UID (`repositories/ficha.ts:105`), então `atorUid === targetFichaId` é a prova de propriedade; o mau resultado descrito não ocorre.
- `false` — scope creep em `index.ts` (BH24): `obterDetalheSolicitacao`/`notificarEventoAuditOutbox` pertencem à Story 3.4, não à 4.1; refletem o escopo do commit `b61af5a`, não um defeito da mudança.
- `false` — integração em `MinhaFichaScreen` ausente do diff (AA10): a integração existe no commit `d25ebf4`; foi um artefato do diff capturado (commit concorrente durante o review).
- `low` — largura fixa `SizedBox(width: 140)` sem wrap (`consulta_ficha_screen.dart:392`): risco especulativo de overflow sob escala de texto, corrigir exigiria reestruturação de layout; não vale patch.

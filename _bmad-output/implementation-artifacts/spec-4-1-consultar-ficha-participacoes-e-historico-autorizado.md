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

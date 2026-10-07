---
title: 'Story 3.4: Comunicação de decisões e acompanhamento por público'
type: 'feature'
created: '2026-10-06'
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
Com a conclusão das etapas de aprovação (Pastor Local - Story 3.1, Responsáveis de Equipe - Story 3.2, e Coordenador Geral com ativação anual - Story 3.3), o sistema precisa garantir uma comunicação de decisões e um acompanhamento seguro, transparente e estritamente segregado por público:
1. **Voluntário (`MinhaFichaScreen`):**
   - Deve acompanhar com total clareza a evolução individual de cada equipe solicitada:
     * **Equipes ativas:** indicação inequívoca de voluntariado ativo com vigência anual explícita (`vigenciaInicio` e `vigenciaFim`).
     * **Equipes pendentes:** indicação precisa de em qual etapa do fluxo a solicitação está tramitando (Pastor Local, Responsável de Equipe ou Coordenador Geral).
     * **Equipes com decisão desfavorável:** mensagem neutra canônica OBRIGATÓRIA: *"Procure o Pastor da igreja local para mais informações"*.
     * **INVARIANTE CRÍTICO:** Em hipótese alguma expor a palavra "rejeitado", justificativas internas, motivos de indeferimento ou identidade dos avaliadores ao voluntário (FR28, AD-12).
2. **Pastores e Responsáveis de Equipe (Filas e Consultas):**
   - Preservam a visualização interna completa da linha do tempo, motivos e justificativas das decisões, estritamente restrita ao seu escopo territorial (igreja) ou funcional (equipe).
   - Revalidação em tempo real: o acesso a qualquer detalhe ou deep link é reautorizado no momento da abertura (verificando identidade, papel atual e vínculo ativo), bloqueando acessos caso o responsável tenha sido substituído ou expirado.
3. **Notificações Pós-Compromisso (AD-10 e AD-12):**
   - Disparadas exclusivamente a partir de eventos já persistidos em `auditOutbox` (sem escrita direta de cliente).
   - Notificações estritamente SEM PII, SEM justificativas internas e SEM decisões acionáveis incorporadas (contendo apenas estado, próxima ação e link autorizável para o sistema).

**Approach:**
1. **Sanitização e Projeções Autorizadas no Backend (Cloud Functions):**
   - `obterMinhasParticipacoes`: Enriquecimento da projeção do voluntário retornando o estado real (`RASCUNHO`, `AGUARDANDO_PASTOR_LOCAL`, `AGUARDANDO_RESPONSAVEL_EQUIPE`, `AGUARDANDO_COORDENADOR`, `ATIVA`, `REJEITADA`), vigência anual (`vigenciaInicio`, `vigenciaFim`), com sanitização ativa: para qualquer participação com decisão negativa, a `proximaAcao` é fixada como *"Procure o Pastor da igreja local para mais informações"* e dados confidenciais (justificativas, UIDs de avaliadores) são estritamente omitidos.
   - `obterMinhaFicha`: Projeção da ficha consolidada sanitizada garantindo que ficha desfavorável (`REJEITADA`) oculte justificativas internas.
   - Módulo de Notificação Segura Pós-Compromisso (`notificacao.ts`):
     * Geração de payloads de notificação sem PII (`destinatarioUid`, `tipo`, `estado`, `proximaAcao`, `linkAutorizavel`, `timestamp`).
     * Verificação de autorização em tempo de consulta para deep links e histórico.
2. **Frontend Flutter Web/PWA Mobile-First (Sally + Amelia):**
   - Atualização de `ParticipacaoModel` e `MinhaFichaScreen`:
     * Mobile-first: cards refinados no celular com espaçamento consistente e tipografia do Design System (`navy-900`, `blue-600`, `gray-700`).
     * Cards de Equipes Ativas exibindo chip de sucesso e período de vigência anual (`DD/MM/AAAA até DD/MM/AAAA`).
     * Cards de Equipes Pendentes indicando chip informativo e próxima ação textual.
     * Cards com decisão desfavorável exibindo o container neutro institucional com a mensagem canônica *"Procure o Pastor da igreja local para mais informações"*, sem utilizar a palavra "rejeitado" nem tonalidades hostis.
     * Alvos de toque >= 44px e conformidade estrita WCAG 2.2 AA.

## Boundaries & Constraints

**Always:**
- Acompanhamento do voluntário para decisões negativas exibe EXATAMENTE *"Procure o Pastor da igreja local para mais informações"*.
- Notificações pós-compromisso baseadas em eventos persistidos, estritamente sem PII e sem justificativas internas.
- Vigência anual exibida com clareza para equipes ativadas (`vigenciaInicio` e `vigenciaFim`).
- Acesso a qualquer solicitação reautorizado em runtime contra papéis e vínculos vigentes no momento da consulta.
- Acessibilidade WCAG 2.2 AA: touch targets >= 44px, contraste semântico e ausência de dependência exclusiva de cor para indicar status.

**Never:**
- Nunca exibir a palavra "rejeitado", motivos, justificativas internas ou atores desfavoráveis ao voluntário.
- Nunca incluir dados sensíveis (CPF, nome completo, justificativas) em payloads de notificação externa ou FCM.
- Nunca aceitar escrita direta de cliente em projeções ou coleções de domínio.
- Nunca conceder acesso a relatórios ou filas com base em links antigos após expiração ou revogação de vínculo.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Voluntário consulta participações com equipes ativas | Voluntário autenticado, participações em `ATIVA` | Retorna lista com `estado: 'ATIVA'`, `vigenciaInicio` e `vigenciaFim` preenchidos | `200 OK` |
| Voluntário consulta participação indeferida | Voluntário autenticado, participação com decisão negativa | Retorna `proximaAcao: 'Procure o Pastor da igreja local para mais informações'`, omitindo `justificativaInterna` | `200 OK` sanitizado |
| Usuário não autenticado consulta participações | Requisição sem auth | Erro de autenticação | `unauthenticated` |
| Voluntário tenta consultar participações de outro UID | `request.data.uid !== request.auth.uid` | Bloqueio imediato | `permission-denied` |
| Disparo de notificação pós-compromisso | Evento em `auditOutbox` (ex: `DECISAO_COORDENADOR`) | Notificação gerada sem PII, com estado, próxima ação neutra e deep link | Idempotente via outbox |
| Pastor/Responsável acessa link de ficha após expiração de vínculo | Usuário autenticado cujo vínculo na igreja/equipe foi encerrado | Revalidação no backend bloqueia exibição de dados da solicitação | `permission-denied: Usuário não possui vínculo vigente.` |
| Consulta de ficha consolidada em estado negativo | Ficha do voluntário em `REJEITADA` | Exibe resumo neutro com mensagem canônica, sem a palavra "rejeitado" | `200 OK` com texto neutro |

</frozen-after-approval>

## Code Map

- `functions/src/domain/participacao.ts` -- Modelagem e tipos de projeção de acompanhamento sanitizada e vigência.
- `functions/src/domain/notificacao.ts` -- Estruturas, contratos e sanitizadores de notificações sem PII e deep links seguros.
- `functions/src/repositories/participacao.ts` -- Repositório com projeção de acompanhamento sanitizada e leitura segura de participações.
- `functions/src/repositories/notificacao.ts` -- Repositório e gerador de notificações pós-compromisso a partir de eventos de auditoria.
- `functions/src/commands/obterMinhasParticipacoes.ts` -- Callable autenticada retornando participações com vigência e sanitização neutra.
- `functions/test/comunicacaoAcompanhamento.test.ts` -- Suíte Vitest validando ausência de PII, mensagem neutra, vigência anual e reautorização em runtime.
- `flutter_app/lib/features/voluntario/participacao_service.dart` -- Modelos e gateways atualizados com suporte a vigência e acompanhamento.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Interface mobile-first atualizada com cards de acompanhamento por equipe, vigência e texto canônico.
- `flutter_app/test/acompanhamento_decisoes_test.dart` -- Testes de widget garantindo conformidade visual, acessibilidade, texto neutro e vigência.

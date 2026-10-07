---
title: 'Story 3.4: Comunicação de decisões e acompanhamento por público'
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

### Review Findings

- [x] [Review][Patch] Integrar notificações via trigger em `auditOutbox` (ex-Decisão D1, opção 1) [functions/src/triggers/] — `emitirNotificacaoSeguraRepo` (`functions/src/repositories/notificacao.ts:23`) só é referenciado pelos próprios testes; nenhum comando de decisão (`decidirFichaPastorLocal`, `decidirParticipacaoResponsavelEquipe`, `decidirAtivacaoCoordenador`) o invoca e não há trigger sobre `auditOutbox`; `EventoAuditoriaOutbox` (`functions/src/domain/notificacao.ts:31`) é declarado e nunca usado; nenhum gateway/tela Flutter consome `obterMinhasNotificacoes` (zero referências em `flutter_app/lib`). Efeito: nenhuma notificação pós-compromisso é emitida em produção e a callable fica inerte, enquanto o AC/AD-10 exigem disparo exclusivamente a partir de eventos persistidos. Os testes não falham porque nenhum liga decisão→notificação. Decidir a forma de integração (trigger em `auditOutbox` vs. chamada pós-commit nos repositórios de decisão). Fontes: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor.
- [x] [Review][Patch] Reautorização em runtime de deep link/consulta após troca ou expiração de vínculo (ex-Decisão D2, opção 3) [functions/src/commands/] — nenhuma superfície nova revalida identidade/vínculo no momento da abertura; `obterMinhasNotificacoes` (`functions/src/commands/obterMinhasNotificacoes.ts:16-25`) apenas compara `request.data.uid` com `request.auth.uid`. As filas existentes já revalidam vínculo vigente, mas não há endpoint de detalhe/deep link de ficha que atenda à linha da matriz de I/O (“acesso é reautorizado no momento da abertura”; `permission-denied: Usuário não possui vínculo vigente.`). Decidir se o requisito é coberto pelas filas atuais ou se exige um endpoint dedicado. Fontes: blind-hunter, acceptance-auditor.
- [x] [Review][Patch] Suprimir banner de status duplicado para estados cobertos pela seção (ex-Decisão D3, opção 2) [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1152] — `_buildBannerStatus` (`minha_ficha_screen.dart:1152`) e `_buildSecaoEnvioAprovacao` (`minha_ficha_screen.dart:2158`) são ambos renderizados em `_buildConteudo` (linhas 445 e 638) e repetem conteúdo equivalente (ex.: “Voluntariado Ativo no Maanaim” / “Próxima Ação”) para `ATIVA`, `REJEITADA` e `AGUARDANDO_*`. Redundância visual e duplicação de anúncios para leitor de tela; decidir qual apresentação manter. Fonte: blind-hunter.

- [x] [Review][Patch] Leituras sem `.limit()` e ordenação em memória (AD-9) [functions/src/repositories/participacao.ts:62-69; functions/src/repositories/notificacao.ts:69-87] — `obterMinhasParticipacoesRepo` e `obterMinhasNotificacoesRepo` fazem `.get()` sem `.limit` e `notificacoes` ordena em memória (`.sort`) em vez de `orderBy`, divergindo do padrão com `.limit(...)` usado em `decisaoCoordenador.ts`. Fontes: blind-hunter, acceptance-auditor.
- [x] [Review][Patch] Mensagem canônica com ponto final no subtítulo do cabeçalho [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:78] — `_obterSubtituloHeader` retorna `'Procure o Pastor da igreja local para mais informações.'` (com “.”), divergindo do texto exato exigido, enquanto banner/card usam a constante sem ponto. Fontes: edge-case-hunter, acceptance-auditor.
- [x] [Review][Patch] Cores hardcoded fora do Design System [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:223,305,374,483,978,1010] — `Color(0xFFF3F4F6)`, `Color(0xFFF8FAFC)` e `Color(0xFFF9FAFB)` não existem em `flutter_app/lib/ui/tokens.dart` nem no `DESIGN-SYSTEM.md`, ferindo a policy de tokens canônicos do `AGENTS.md`. Fonte: acceptance-auditor.
- [x] [Review][Patch] Vigência com `.toLocal()` pode deslocar o dia [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:1139-1146] — `_formatarDataApenas` aplica `.toLocal()` a instantes UTC do servidor; valores próximos da meia-noite UTC podem renderizar o dia anterior, divergindo de `vigenciaInicio`/`vigenciaFim`. Fontes: blind-hunter, acceptance-auditor.
- [x] [Review][Patch] Validador de PII com checagem de campos case-sensitive [functions/src/domain/notificacao.ts:107-113] — `camposPiiProibidos` é testado via `campo in payload` (case-sensitive) enquanto apenas o texto serializado é minúsculo; chaves como `nomeCompleto`/`CPF` escapam do guard de PII. Fontes: blind-hunter, edge-case-hunter.
- [x] [Review][Patch] Chips de participação pendente caem no estilo “desconhecida” e podem exibir estado cru [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:935-941,966-969] — passa `p.estado` (ex.: `AGUARDANDO_PASTOR_LOCAL`) a `StatusChip`, cujo `resolveConfig` reconhece apenas `AGUARDANDO` (`flutter_app/lib/ui/components/status_chips.dart:61-70`), resultando em estilo cinza; o rótulo cai para `p.estado` cru em estados não mapeados (ex.: `RASCUNHO`). Fontes: blind-hunter, acceptance-auditor.
- [x] [Review][Patch] `mensagemVoluntario`/`proximaAcao` projetados mas nunca renderizados [functions/src/commands/obterMinhaFicha.ts:46-47; flutter_app/lib/features/voluntario/ficha_service.dart:71-72] — a projeção sanitizada da ficha retorna `mensagemVoluntario`/`proximaAcao`, mas a UI de `REJEITADA` usa texto fixo (`minha_ficha_screen.dart:505,719`); mudança server-side não chega à tela (campo morto). Fontes: blind-hunter, verification-gap.
- [x] [Review][Patch] Chaves de widget duplicadas por `equipeId` [flutter_app/lib/features/voluntario/minha_ficha_screen.dart:796,876,944,1041] — os cards usam `Key('card_participacao_$eqId')`; duas participações da mesma equipe (ex.: ciclos distintos) geram chaves duplicadas na mesma `Column`, quebrando a árvore em debug e o reaproveitamento em release. Correção direta: usar o id da participação. Fonte: edge-case-hunter.
- [x] [Review][Patch] Fallback de sanitização morto [functions/src/repositories/participacao.ts:34] — `dados.decisao === 'DESFAVORAVEL'` nunca casa: os repositórios de decisão gravam decisão aninhada (`decisaoPastoral`/`decisaoResponsavel`/`decisaoCoordenador`) e `estado`; a sanitização depende exclusivamente de `estado === 'REJEITADA'`. Fonte: verification-gap.
- [x] [Review][Patch] Duplicação da mensagem canônica sem fonte única [functions/src/domain/notificacao.ts:12; functions/src/domain/participacao.ts:31; functions/src/repositories/ficha.ts:66,70] — a frase canônica está redefinida em 3+ pontos além dos literais na UI, permitindo divergência futura. Fonte: blind-hunter.
- [x] [Review][Patch] `ParticipacaoRascunho` perdeu tipagem literal de estado/ciclo [functions/src/domain/participacao.ts:29-31] — `estado: string`/`ciclo: string` removem a validação em compile-time; estados inválidos passam silenciosamente enquanto a UI compara strings cruas. Fonte: blind-hunter.
- [x] [Review][Patch] Cobertura de testes incompleta para a nova fiação [functions/test/comunicacaoAcompanhamento.test.ts:250-285; flutter_app/test/acompanhamento_decisoes_test.dart] — o mock de `where` ignora o filtro e todos os fixtures usam o mesmo `destinatarioUid`, então a remoção do filtro de isolamento passaria; nenhum teste exercita `obterMinhasNotificacoes` no caminho autenticado feliz nem o `_obterSubtituloHeader`/chips. Fontes: blind-hunter, verification-gap.
- [x] [Review][Defer] Campos/modelo sem uso (`cicloAtualId`, `FichaModel.isAtiva`/`isRejeitada`/`proximaAcao`) [flutter_app/lib/features/voluntario/participacao_service.dart:31; flutter_app/lib/features/voluntario/ficha_service.dart:76-77] — deferred: provavelmente reservados às Stories 4.x/5.x (deep link de ciclo/renovação); sem dano imediato.

#### Rejected

- `false` — “projeção retorna `estado: 'REJEITADA'` verbatim”: a matriz de I/O do SPEC lista `REJEITADA` entre os estados retornados ao voluntário; a confidencialidade recai sobre justificativas/avaliadores, não sobre o estado.
- `false` — “copy de ATIVA superestima o resultado”: o texto diz “equipes aprovadas foram homologadas”, o que é literalmente verdadeiro; não afirma que todas as equipes foram aprovadas.

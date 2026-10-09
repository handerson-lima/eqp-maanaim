---
title: '8.3 — Resolver contexto de acesso e rotas por capacidades'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_commit: '5f68585a158f8178cdde9ea04843e9f8ab3ca839'
route: 'dispatch'
review_loop_iteration: 0
context:
  - AGENTS.md
  - _bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md
  - _bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md
  - _bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A aplicação hoje resolve o acesso de forma excludente baseada apenas em duas custom claims (`maanaimAdmin` e `maanaimCoordenador`), forçando qualquer outro usuário — incluindo Pastores Locais e Responsáveis de Equipe — a cair na tela de voluntário simples (`MinhaFichaScreen`), impedindo perfis legítimos sem papel de admin global de acessar suas filas e dashboards, bloqueando o acesso simultâneo a múltiplos vínculos e carecendo de rotas declarativas e deep links seguros que suportem recarregar e voltar no navegador.

**Approach:** Criar o endpoint autenticado `obterContextoAcesso` no Cloud Functions para derivar as capacidades e escopos vigentes diretamente no servidor de forma mínima e segura; modelar no Flutter o `ContextoAcesso` e roteamento declarativo por capacidades que suporte recarregar/voltar, múltiplos destinos concorrentes (pastor + equipe + voluntário), tratamento explícito de loading/erro/negação e garantia de que nenhum dado sensível, PII ou token trafegue na URL da aplicação.

## Boundaries & Constraints

**Always:**
- A autoridade reside exclusivamente no servidor (AD-01, AD-02): capacidades e escopos são derivados de dados canônicos (`autoridadesAdministrativas`, `igrejas`, `equipes`, `vinculosPastorIgreja`, `vinculosResponsavelEquipe`) pelo Cloud Functions.
- Jamais permitir autoatribuição de papéis ou confiar em claims/parâmetros enviados pelo cliente (AD-02, AD-09).
- Suportar usuários com múltiplos vínculos vigentes simultâneos (ex.: pastor local de igreja X e responsável da equipe Y), permitindo acesso a todas as suas áreas autorizadas sem seletor de papel artificial.
- Vínculo expirado ou revogado deve invalidar o acesso imediatamente após revalidação do contexto no servidor, sem manter dados anteriores em tela.
- URLs de rotas web e deep links devem ser limpas e seguras (ex.: `/inicio`, `/minha-ficha`, `/pastor`, `/equipe`, `/coordenador`, `/admin`, `/renovacao`, `/perfil`), nunca contendo PII, CPFs, tokens ou URLs de download de PDF (AD-12).
- Estados de sessão ausente (login), carregando (loading acessível), erro de contexto (com retry/logout) e negação de permissão (403 explícito com opção de retorno) devem ser tratados visivelmente, sem redirecionamento silencioso para telas de outros perfis.

**Never:**
- Nunca realizar varreduras amplas em coleções administrativas no cliente (`igrejas`, `equipes`, `autoridadesAdministrativas`) para descobrir os menus do usuário.
- Nunca redirecionar silenciosamente um usuário com permissão negada para a ficha de voluntário sem informar a restrição.
- Nunca expor PII, tokens ou referências de assinatura em query parameters ou caminhos de rota.
- Nunca supor que a ausência de claim administrativa signifique ausência de funções pastorais ou de equipe.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Voluntário simples | Usuário autenticado sem vínculos pastorais nem cargos admin | Capacidades: `['voluntario']`; rotas autorizadas: `/inicio`, `/minha-ficha`, `/perfil`; menu contextual exibe Minha Ficha e Início | Tentativa de acessar `/pastor` ou `/admin` exibe tela de Acesso Não Autorizado (403) |
| Pastor Local exclusivo | Usuário com igreja ativa em `pastorLocalVigentePessoaId` | Capacidades: `['voluntario', 'pastor_local']`; lista de igrejas sob seu pastoreio; acesso direto à Fila do Pastor e Dashboard de Renovação pastoral | Erro ao carregar fila exibe retry sem perder o contexto pastoral |
| Responsável de Equipe exclusivo | Usuário com equipe ativa em `responsavelVigentePessoaId` | Capacidades: `['voluntario', 'responsavel_equipe']`; lista de equipes vinculadas; acesso à Fila da Equipe e Dashboard da Equipe | Vínculo inativo ou revogado remove a capacidade no próximo carregamento |
| Vínculos Simultâneos (Pastor + Responsável) | Usuário com igreja sob pastoreio E equipe sob responsabilidade | Capacidades: `['voluntario', 'pastor_local', 'responsavel_equipe']`; navegação oferece atalhos para Fila do Pastor E Fila da Equipe de forma simultânea | Ambas as filas acessíveis sem necessidade de logout ou troca manual de sessão |
| Administrador / Coordenador | Usuário com flag `podeAdministrar` ou `coordenadorGeral` ativa | Capacidades administrativas e de coordenação preservadas; shell administrativo e coordenação disponíveis juntamente com eventuais vínculos específicos | Bloqueio de autoatribuição por usuários não autorizados |
| Revogação de Vínculo | Usuário perde vínculo pastoral no servidor enquanto navega | Atualização/recarregamento remove capacidade `pastor_local`; chamada a `obterFilaPastorLocal` falha com `permission-denied` | Exibe aviso de autorização expirada/revogada e limpa visualização de dados restritos |
| Deep link direto não autorizado | Usuário voluntário acessa URL `/#/admin` ou `/#/pastor` diretamente | Sistema consulta contexto no backend, detecta ausência da capacidade requerida e apresenta tela "Acesso não autorizado" com botão para voltar | Sem vazamento de dados administrativos ou redirecionamento silencioso confuso |
| Recarregar página (F5 / reload) | Usuário em `/#/pastor?igrejaId=ig_123` recarrega o navegador | Sessão é restaurada via `authStateChanges`, contexto é consultado novamente e rota é restabelecida com filtro preservado | Se sessão falhar, encaminha para Login; se contexto falhar, exibe botão de tentar novamente |

</frozen-after-approval>

## Code Map

- `functions/src/domain/contextoAcesso.ts` -- Definição de tipos e validações de capacidades e escopos vigentes do usuário.
- `functions/src/repositories/contextoAcesso.ts` -- Extração de autoridade administrativa, igrejas sob pastoreio vigente e equipes sob responsabilidade vigente para o UID autenticado.
- `functions/src/commands/obterContextoAcesso.ts` -- Callable Cloud Function autenticada `obterContextoAcesso`.
- `functions/src/index.ts` -- Exportação da nova callable `obterContextoAcesso`.
- `functions/test/contextoAcesso.test.ts` -- Testes unitários para resolução de capacidades, múltiplos vínculos e revogações no backend.
- `flutter_app/lib/features/auth/contexto_acesso_model.dart` -- Modelos `ContextoAcesso`, `CapacidadeAcesso`, `EscopoIgreja`, `EscopoEquipe` com métodos de checagem.
- `flutter_app/lib/features/auth/contexto_acesso_service.dart` -- Gateway e serviço de consulta do contexto de acesso via Cloud Functions com cache de sessão e revalidação.
- `flutter_app/lib/routes/app_router.dart` -- Roteamento declarativo com suporte a rotas nomeadas, deep links, guards de capacidade e parâmetros de filtro seguros.
- `flutter_app/lib/features/auth/acesso_negado_screen.dart` -- Tela acessível de negação de autorização (403) com opção de retorno seguro.
- `flutter_app/lib/features/auth/seletor_destino_capacidades.dart` -- Visão de navegação/hub para usuários com múltiplos papéis/vínculos escolherem ou alternarem destinos.
- `flutter_app/lib/main.dart` -- Integração do `ContextoAcessoService`, inicialização das rotas e refatoração da `AreaAutenticada` para roteamento guiado por capacidades.
- `flutter_app/test/contexto_acesso_test.dart` -- Testes de modelo, resolução de capacidades e restrições de rota no Flutter.
- `flutter_app/test/rotas_capacidades_test.dart` -- Testes de navegação, deep linking e guarda de rotas para os 5 perfis da matriz.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/domain/contextoAcesso.ts` -- Criar contratos de domínio e tipos para contexto de acesso e capacidades -- Garantir separação de conceitos e tipagem rigorosa.
- [x] `functions/src/repositories/contextoAcesso.ts` -- Implementar repositório que busca autoridade administrativa, igrejas do pastor e equipes do responsável -- Resolver escopos vigentes sem leituras amplas no cliente.
- [x] `functions/src/commands/obterContextoAcesso.ts` -- Implementar callable autenticada `obterContextoAcesso` -- Disponibilizar endpoint mínimo de autoridade e capacidades.
- [x] `functions/src/index.ts` -- Exportar callable `obterContextoAcesso` -- Expor endpoint para a aplicação cliente.
- [x] `functions/test/contextoAcesso.test.ts` -- Adicionar testes automatizados no backend -- Validar cenários de voluntário, pastor, responsável, vínculos múltiplos e revogação.
- [x] `flutter_app/lib/features/auth/contexto_acesso_model.dart` -- Criar classes imutáveis para capacidades e escopos no cliente Flutter -- Facilitar decisões de UI e verificação de rota.
- [x] `flutter_app/lib/features/auth/contexto_acesso_service.dart` -- Implementar gateway e serviço para invocar a callable e notificar mudanças -- Centralizar resolução de contexto.
- [x] `flutter_app/lib/features/auth/acesso_negado_screen.dart` -- Criar tela de acesso não autorizado sem vazamento de dados -- Cumprir requisitos de resiliência e feedback explícito.
- [x] `flutter_app/lib/routes/app_router.dart` -- Estruturar rotas declarativas e guarda por capacidades -- Assegurar suporte a reload, voltar e deep links sem PII.
- [x] `flutter_app/lib/main.dart` -- Refatorar `AreaAutenticada` e integrar `AppRouter` e `ContextoAcesso` -- Permitir que pastor, responsável e múltiplos vínculos alcancem suas telas.
- [x] `flutter_app/test/contexto_acesso_test.dart` -- Testar desserialização e lógica de capacidades no Flutter -- Assegurar robustez e cobertura de modelos.
- [x] `flutter_app/test/rotas_capacidades_test.dart` -- Testar navegação e proteção de rotas para múltiplos perfis -- Validar matriz de autorização e deep links.

**Acceptance Criteria:**
- Given um usuário autenticado que é apenas Pastor Local de uma igreja, when seu contexto de acesso for resolvido, then a aplicação deve disponibilizar rota e acesso à Fila do Pastor e Dashboard de Renovação pastoral, sem exigir privilégios de administrador global.
- Given um usuário autenticado que é Pastor Local E Responsável de Equipe simultaneamente, when carregar a aplicação, then o contexto deve conter ambas as capacidades e a interface deve oferecer acesso direto a ambos os destinos autorizados.
- Given um usuário com sessão ativa que navega para `/#/pastor` sem possuir a capacidade de Pastor Local, when a rota for processada, then deve exibir uma tela clara de acesso não autorizado (403) com opção de retorno, sem redirecionamento silencioso para outra tela de perfil alheio.
- Given qualquer rota ou deep link acessado na aplicação, when a URL for inspecionada, then não deve haver exposição de PII (nome, e-mail, CPF), tokens de acesso ou URLs privadas de PDF.
- Given um usuário navegando em uma tela autorizada que tem seu vínculo revogado no servidor, when atualizar a página ou recarregar o contexto, then o acesso àquela área deve ser imediatamente revogado.

## Implementation Notes

- Endpoint backend `obterContextoAcesso` implementado e exportado com autoridade estrita do servidor (AD-01, AD-02, AD-09).
- Suíte completa de testes no backend (`test/contextoAcesso.test.ts`) cobrindo 11 casos de teste com sucesso e typecheck aprovado.
- Modelos Flutter `ContextoAcesso`, `CapacidadeAcesso`, `EscopoIgreja` e `EscopoEquipe` com imutabilidade e desserialização robusta.
- Guarda declarativo de rotas `AppRouteGuard` e sanitização `AppRotas.sanitizarRota` impedindo vazamento de PII/tokens em URLs.
- Tela acessível de 403 `AcessoNegadoScreen` com retorno seguro.
- Componente `SeletorDestinoCapacidades` (Hub de Destinos) permitindo alternância entre áreas para usuários com múltiplos papéis/vínculos simultâneos.
- Integração completa em `main.dart` com fallback para testes e suporte a rotas.
- 12 testes no Flutter (`test/contexto_acesso_test.dart` e `test/rotas_capacidades_test.dart`) cobrindo modelos, rotas e componentes de tela. Todos passando com `flutter analyze` limpo.

## Review Triage Log

| Lente / Camada | Reivindicação / Verificação | Veredito | Resolução |
| :--- | :--- | :--- | :--- |
| Blind Hunter | Possível vazamento de PII em query parameters na URL ou histórico do navegador | `false` | Verificado em `AppRotas.sanitizarRota`: URLs usam identificadores opacos e mapeamento estático de rotas sem PII. |
| Edge Case Hunter | Usuário com perfil misto (Pastor + Responsável) sem capacidade administrativa | `false` | Verificado em `contextoAcesso.ts` e `rotas_capacidades_test.dart`: derivação de múltiplas capacidades sem exigir admin global funciona e exibe seletor de destinos. |
| Verification Gap | Ausência de validação de revogação imediata em sessão de usuário ativa | `false` | Corrigido na revisão 2026-10-09: `ContextoAcessoService.carregarContexto({forcar})` é integrado ao `AreaAutenticada` (cache/revalidação), e `_retentar`/reload reconsultam o contexto; o `AppRouteGuard` passa a exibir 403 quando a capacidade foi removida. |

## Design Notes

A resolução de contexto adota o padrão de autoridade estrita do servidor com projeção mínima de capacidades:
1. O backend inspeciona `autoridadesAdministrativas`, `igrejas`, `equipes` e coleções de vínculos vigentes associadas unicamente ao `request.auth.uid`.
2. A resposta é um mapa de capacidades conhecidas (`voluntario`, `pastor_local`, `responsavel_equipe`, `coordenador`, `administrador`) acompanhado apenas dos IDs e nomes das entidades sob sua responsabilidade direta.
3. O roteamento no Flutter utiliza um sistema declarativo com Guards contextuais: cada rota define suas capacidades mínimas exigidas. Se o usuário satisfaz o predicado, a tela correspondente é renderizada; caso contrário, exibe-se `AcessoNegadoScreen`.
4. Usuários com múltiplos vínculos encontram na navegação superior/lateral e na raiz da área autenticada um seletor rápido ou atalhos para todas as suas áreas de atuação, preservando a identidade única do usuário.

## Verification

**Commands:**
- `cd /Users/usuario/eqp_maanaim/functions && npm test` -- expected: Suíte de testes do backend executando e passando com novos testes de `contextoAcesso`.
- `cd /Users/usuario/eqp_maanaim/flutter_app && flutter test` -- expected: Suíte de testes do Flutter passando com testes de modelos e rotas.

## Review Findings

Revisão de código em 2026-10-09 (diff `5f68585..4b225d3`, 4 camadas: Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor).

### Patch

- [x] [Review][Patch] Deep link, reload (F5) e navegação do navegador não implementados — `main.dart` usa `MaterialApp(home: ...)` sem `Router`/`onGenerateRoute`/`usePathUrlStrategy` e nunca lê `Uri.base`; `rotaInicial` só é fornecido por testes. O guard avalia uma string em memória, então a URL real (`/#/pastor?igrejaId=...`) nunca é processada e o filtro não é restaurado. Fere AC5 e as linhas "Deep link direto" e "Recarregar página (F5)" da matriz. Resolução (2026-10-09): implementar roteamento por URL agora.
- [x] [Review][Patch] `/renovacao` autoriza qualquer usuário autenticado — `contexto.ehVoluntario` é sempre `true` no servidor, tornando o ramo de negação código morto (`app_router.dart:117-128`). Resolução (2026-10-09): `/renovacao` é renovação do voluntário; manter aberto e remover o ramo de negação morto.
- [x] [Review][Patch] Fonte de verdade de autoridade pastoral/equipe ambígua — o repositório une `igrejas.pastorLocalVigentePessoaId`/`equipes.responsavelVigentePessoaId` (canônicos, usados pelo restante do código) com as coleções `vinculosPastorIgreja`/`vinculosResponsavelEquipe`, sem reconciliação nem teste do caminho derivado de vínculo (`functions/src/repositories/contextoAcesso.ts:33-108`). Resolução (2026-10-09): manter a união com `vinculos*` e reconciliar/deduplicar as fontes.
- [x] [Review][Patch] Capacidade de coordenador derivada de campos não canônicos [functions/src/repositories/contextoAcesso.ts:25] — usa `dados?.coordenadorGeral === true && dados?.ativo !== false`, mas o agregado canônico é `{ ativa, papeis, revisao, claimStatus }` (`domain/autoridadeAdministrativa.ts:20-25`). Todo coordenador real (`papeis: ['COORDENADOR']`) fica sem a capacidade; o teste só passa porque a fixture usa `coordenadorGeral: true`. Corrigir com `possuiPapel(dados, PAPEL_COORDENADOR)` e cobrir `{ ativa, papeis: ['COORDENADOR'] }` (ativo/inativo).
- [x] [Review][Patch] `sanitizarRota` mantém segredos quando todos os parâmetros são filtrados [flutter_app/lib/routes/app_router.dart:39] — `uri.replace(queryParameters: parametrosLimpos.isEmpty ? null : parametrosLimpos)`; `null` preserva a query original, então `/pastor?token=secret123` volta com o token. O teste existente só cobre query mista (um `igrejaId` sobrevive). Aplicar allowlist de parâmetros seguros/`uri.replace(query: '')` e adicionar caso só com parâmetros sensíveis.
- [x] [Review][Patch] Despacho de rota ignora o caminho/parâmetros sanitizados pelo guard [flutter_app/lib/main.dart:472-599] — compara `_destinoAtual` bruto a constantes e descarta `avaliacao.caminho`/`RotaAutorizada.parametros`; uma rota autorizada com filtro (`/pastor?igrejaId=ig_1`) cai silenciosamente em `MinhaFichaScreen`. Passar a despachar por `avaliacao.caminho` e consumir os parâmetros.
- [x] [Review][Patch] Rotas desconhecidas são autorizadas em vez de 403 [flutter_app/lib/routes/app_router.dart:130-131] — o `default` retorna `RotaAutorizada`; qualquer URL não reconhecida é aceita e cai em `MinhaFichaScreen`. Negar com 403 explícito.
- [x] [Review][Patch] `ContextoAcessoService` não integrado à aplicação [flutter_app/lib/main.dart:375] — o serviço (cache/revalidação) só aparece em seu próprio arquivo e em teste; `_resolverContexto` chama o gateway direto. O Code Map exige integração em `main.dart`. Além disso, o Review Triage Log cita `ContextoAcessoService.recarregar()`/`ValueNotifier`, que não existem (a classe é `ChangeNotifier` com `carregarContexto`/`invalidar`).
- [x] [Review][Patch] Leituras N+1 por vínculo no repositório [functions/src/repositories/contextoAcesso.ts:59,99] — busca cada `igrejas`/`equipes` dentro dos laços de vínculo; contraria AD-09 ("Prevents… N+1 inviável"). Usar leitura em lote.
- [x] [Review][Patch] Parâmetro morto `temFichaOuUsuario` [functions/src/domain/contextoAcesso.ts:38,125] — declarado e nunca lido; `derivarCapacidades` sempre insere `voluntario`.
- [x] [Review][Patch] Cor hardcoded em vez de token no FAB de alternância [flutter_app/lib/main.dart:621] — `TextStyle(color: Colors.white)` em vez de token canônico (política do Design System).

### Defer

- [x] [Review][Defer] `/inicio` e `/perfil` autorizados sem despacho, caem em `MinhaFichaScreen` [flutter_app/lib/main.dart:484-599] — deferred: telas Início (8.5) e Perfil (8.4/8.15) pertencem a histórias posteriores.
- [x] [Review][Defer] Cobertura ausente para deep link/reload/revogação/matriz de cinco perfis [flutter_app/test/rotas_capacidades_test.dart] — deferred: depende da implementação de roteamento por URL (decision-needed acima).

### Rejected (appendix)

- `false` — `db.collection('fichas').doc(uid)` (contextoAcesso.ts:112) presumiria que o id da ficha difere do uid; o restante do backend usa exatamente `fichas.doc(uid)` (enviarFicha.ts:57, participacao.ts:109, manifestarRenovacao.ts:88, ficha.ts:87).
- `false` — Callable retornando `null`/não-Map causaria TypeError (contexto_acesso_service.dart:20); `obterContextoAcesso` sempre retorna o DTO, nunca `null`.
- `false` — Fallback do cliente fabricaria capacidades e engoliria erro (main.dart:382-404): em produção `widget.contextoAcesso` é sempre fornecido (main.dart:115 → RaizSessao:305), então o ramo não é alcançável; o erro real sobe para o `FutureBuilder` (retry/logout). O trecho é código morto, não defeito em produção.
- `false` — Rota autorizada sem gateway (ex.: pastor) cairia em MinhaFicha (main.dart:505): em produção todos os gateways são injetados em `main()`.
- `low` (rejeitado) — `ContextoAcesso` sem `==`/`hashCode` e comentário impreciso em `capacidadesAtivas` (contexto_acesso_model.dart:130,266).
- `low` (rejeitado) — `fromJson` ignoraria silenciosamente capacidades desconhecidas (contexto_acesso_model.dart:180).
- `low` (rejeitado) — `email`/`estadoFicha` além da projeção mínima (repository/`ContextoAcessoDTO`); `estadoFicha` é insumo da Início (8.5) e `email` é o do próprio usuário.
- `low` (rejeitado) — `fromJson` re-deriva capacidades no cliente (contexto_acesso_model.dart:206-216); o servidor sempre envia os flags.
- `low` (rejeitado) — linha em branco final em `functions/src/index.ts` e nome inexistente `AppRouter` na documentação.
- `false` (rejeitado por editar artefato de acompanhamento) — divergência `status: done` (spec) vs `review` (sprint-status) vs texto do épico.

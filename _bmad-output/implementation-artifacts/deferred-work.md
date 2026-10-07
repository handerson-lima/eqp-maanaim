- source_spec: none
  summary: Implementar cadastro público de voluntários e recuperação de senha por e-mail.
  evidence: Foi separado da importação administrativa de pastores e vínculos, pois pode ser entregue e validado como fluxo público independente.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Executar a integração por Firebase Emulator da transação da callable e das Rules.
  evidence: A verificação só existe sob `firebase emulators:exec`; a Firebase CLI falha ao iniciar o Emulator neste ambiente (firepit-log.txt), então Rules e transação seguem cobertas apenas por testes de contrato/domínio.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Tornar a PWA instalável com ícones e alvo de deploy (`hosting`/`.firebaserc`).
  evidence: O manifesto não declara `icons` e não há bloco `hosting` nem alias de projeto; impacta instalabilidade e publicação, fora do bootstrap de autenticação.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Restaurar sessão ao recarregar e permitir encerrar sessão.
  evidence: `main.dart` sempre abre `Inicio` e `AreaAutenticada` não tem sign-out, deixando o usuário autenticado sem retorno ao rascunho; a entrega atual cobre apenas cadastro/login/recuperação.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Adicionar verificação de e-mail e unicidade de CPF.
  evidence: Nenhuma etapa exige e-mail verificado nem impede UIDs distintos com o mesmo CPF; são regras de domínio/identidade não previstas nesta entrega.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Definir consumidor, TTL/retenção de `commands` e `auditOutbox` e minimização de PII da ficha.
  evidence: Recibo e auditoria são gravados sem política de retenção documentada e a ficha guarda CPF em texto plano sem minimização definida.
- source_spec: `_bmad-output/implementation-artifacts/spec-autenticacao-publica.md`
  summary: Unificar a validação Dart/TS, expor o estado da callable ao cliente e cobrir acessibilidade/CI.
  evidence: Regras de campo e mensagem genérica duplicadas em `validadores.dart`/`rascunho.ts`; `cadastrar` descarta `estado`/`retomado`; não há verificação automatizada de teclado/44 px/leitor de tela nem workflow de CI.
- source_spec: `_bmad-output/implementation-artifacts/spec-importacao-inicial-de-pastores-e-vinculos.md`
  summary: Orquestrar a suíte de Emulator da carga inicial em runner automatizado.
  evidence: A persistência real (adapter Firestore/Auth de `firestoreImportacao.ts`) só é exercitada por `importacao.emulator.test.ts`, marcada com `skipIf` sem `FIRESTORE_EMULATOR_HOST`/`FIREBASE_AUTH_EMULATOR_HOST`; o script `test:emulator` não chama `firebase emulators:exec` e não há CI, então o comando padrão passa com a suíte pulada.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Exercitar no Emulator a callable de administração, o reconciliador de claim, o script operacional e as Rules de Firestore/Storage.
  evidence: A verificação depende de Auth/Firestore/Storage Emulator; a CLI falha ao iniciar o Emulator neste ambiente (mesma causa registrada para `spec-autenticacao-publica`), então a cobertura segue em testes de domínio e contratos de texto.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Definir consumidor/materializador de `auditOutbox` e retomada de recibos `PENDENTE_CLAIM`.
  evidence: A transação grava recibo e outbox, mas nenhum worker drena a outbox nem finaliza a claim após falha entre a gravação canônica e a projeção externa; um crash deixa estado recuperável apenas manualmente.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Compartilhar o nome da Custom Claim administrativa entre Dart e TypeScript.
  evidence: `maanaimAdmin` é literal em `auth_service.dart` e em `functions/src/domain/autoridadeAdministrativa.ts`; sem contrato compartilhado, uma renomeação de um lado silenciosamente desautoriza o outro.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Serializar a escrita de Custom Claims para não perder claims de outros domínios em corridas.
  evidence: `setCustomUserClaims` substitui o mapa inteiro; duas reconciliações sobrepostas (callable + bootstrap) podem reescrever claims alheias a partir de uma leitura anterior, e o teto de tentativas apenas detecta a corrida da revisão canônica.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-acesso-administrativo-seguro.md`
  summary: Revalidar a existência da identidade de destino dentro da transação.
  evidence: A callable valida `getUser` antes da transação, mas um alvo excluído entre a validação e o commit grava autoridade ativa para conta inexistente e deixa o recibo em `PENDENTE_CLAIM`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-seed-idempotente-de-igrejas-e-equipes.md`
  summary: Gestão administrativa de igrejas e equipes (edição e inativação sem exclusão física).
  evidence: O núcleo desta story ficou no seed idempotente e na consulta read-only; a inativação sem exclusão física (4º critério de aceite do épico) e a edição do catálogo foram diferidas para conter o escopo e o tamanho do spec, e serão retomadas em uma story de gestão administrativa.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-seed-idempotente-de-igrejas-e-equipes.md`
  summary: (resolvido) Expor o disparo do seed inicial do catálogo na área administrativa.
  evidence: A ação foi entregue no shell administrativo (`AdminShell` -> aba Seed -> `SeedCatalogo`), que invoca `semearCatalogoInicial` por Auth/App Check. Entrada mantida apenas como histórico de que a cobertura de UI deixou de estar diferida.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-1-2-frontend-admin-pwa.md`
  summary: Tratar erro do stream `authStateChanges` em `RaizSessao` sem rebaixar uma sessão ativa para a tela de login.
  evidence: `RaizSessao.build` (`flutter_app/lib/main.dart:111-127`) trata apenas `waiting` e `data == null`; um snapshot com erro cai em `Inicio`, escondendo a sessão. Severidade não verificada (`medium` se verdadeiro): é preciso confirmar se o stream de `FirebaseAuth.authStateChanges()` pode emitir erro em algum caminho real; se não puder, o finding não procede.

## Deferred from: code review of story 1.1 (2026-09-30)

- TOCTOU do alvo entre a validação `getUser` e o commit: uma conta deletada na janela deixa autoridade ativa para identidade inexistente e recibo pendente. Corrida inerente; exige revalidação dentro da transação ou compensação.
- Escrita de Custom Claims concorrente de outro domínio pode ser perdida entre a releitura e `setCustomUserClaims` (Auth não oferece CAS). Mitigação exigiria serialização/coordenação externa.
- `storage.rules` verificado apenas por asserção textual; sem teste de Rules no Emulator (não há harness; Emulator indisponível no ambiente).
- A UI não revalida a autorização durante a sessão (só no erro/relogin); uma revogação mantém a tela até recarregar. O servidor permanece autoritativo; atualização contínua é decisão de UX.
- `_bmad-output/implementation-artifacts/epic-1-context.md` sem proveniência/versão de origem; sem data/fonte, não é possível detectar drift contra o SPEC/Architecture Spine.

## Deferred from: code review of story 1.2 (2026-09-30)

- README afirma que o cliente lê `equipes` ativas como dropdown, mas nenhum código cliente consulta `equipes`; a regra de leitura de `equipes` e a frase ficam sem consumidor.
- `consultarCatalogo` calcula filtro/`rotulo` por termo no servidor, mas `ConsultaCatalogo` sempre chama sem termo e filtra localmente: fonte de verdade duplicada que pode divergir.
- README perdeu o parágrafo sobre registrar os domínios autorizados no Firebase Authentication de cada ambiente (impacta redirecionamento de recuperação de senha).

## Deferred from: code review of story 1.3 (2026-09-30)

- `lerPessoas` carrega as coleções `pessoas`, `autoridadesAdministrativas` e `coordenadores` inteiras, sem paginação/limite; custo/latência crescem de forma ilimitada com o volume.
- Nenhum teste assegura que os três callables novos enviam token de App Check a partir do cliente; depende de infraestrutura de Emulator/CI.

## Deferred from: code review of spec-1-4-gestao-temporal-de-vinculos-de-responsabilidade (2026-09-30)

- Suíte de Emulator dos vínculos não roda no caminho padrão: `npm test` a ignora via `skipIf` e `test:emulator` não usa `firebase emulators:exec` nem CI, então transação, recibo, auditoria e códigos de erro da 1.4 só são exercitados com o Emulator ativo (mesma lacuna registrada em `deferred-work.md:24`).
- Rules de Firestore verificadas apenas por asserção textual de `firestore.rules` (sem `@firebase/rules-unit-testing`): uma regra permissiva em `vinculosPastorIgreja`/`vinculosPastorEquipe` passaria na suíte (mesma lacuna de `deferred-work.md:54`).

## Deferred from: code review of story-2.3 (2026-10-06)

- Alterações fora do escopo declarado da story: `flutter_app/lib/features/admin/termos_screen.dart` (botões "Modelo Oficial (PDF)"/"Carregar texto oficial do modelo" com CNPJ/endereço no cliente) e `functions/src/commands/importarPastoresIniciais.ts` (bootstrap de `projectId`) não constam no Code Map/Tasks. Reavaliar em mudança separada.
- Pré-condição "ao menos uma equipe" não filtra estado/ciclo da participação (`functions/src/repositories/termos.ts:365-376`): hoje não alcançável porque participações `CANCELADA`/`APROVADA` só surgem em epics posteriores; confirmar se estados não-rascunho podem coexistir com o aceite.

## Deferred from: code review of story-3.4 (2026-10-06)

- Campos/modelo introduzidos sem uso: `ParticipacaoModel.cicloAtualId` (`flutter_app/lib/features/voluntario/participacao_service.dart:31`) e `FichaModel.isAtiva`/`isRejeitada`/`proximaAcao` (`flutter_app/lib/features/voluntario/ficha_service.dart:76-77`) não são lidos por nenhuma tela; provavelmente consumidos nas Stories 4.x/5.x (deep link de ciclo/renovação). Diferido por não ter uso imediato e sem dano atual.

## Deferred from: code review of spec-4-1-consultar-ficha-participacoes-e-historico-autorizado (2026-10-07)

- Auditoria de leitura: `consultarFichaAutorizada`/`consultarLinhaDoTempoAutorizada` expõem CPF integral e histórico completo sem gravar `auditOutbox`/evidência de acesso; política de auditoria de leitura (finalidade/retenção) a definir antes de implementar.
- Mensagem canônica duplicada: `functions/src/domain/mensagens.ts` declara `MENSAGEM_CANONICA_DECISAO_NEGATIVA`/`MENSAGEM_NEUTRA_CANONICA` como fonte única, mas `decisaoPastor.ts:10`, `decisaoResponsavelEquipe.ts:10` e `decisaoCoordenador.ts:10` mantêm o literal. Migrar as três cópias está fora do escopo da consulta (FR28).
- Tipo de evento `CANCELAMENTO` declarado em `functions/src/domain/consultaHistorico.ts:73` e nunca produzido; pertence às Stories 4.3/4.4 (a decisão negativa do Coordenador foi corrigida no review 4.1).
- Sanitização por heurística: `sanitizarEventoParaVoluntario` (`functions/src/domain/consultaHistorico.ts:124-127`) detecta negativa por `estadoVisual`/substring `'desfavor'`/`'rejeit'`; um novo tipo de evento sem esses marcadores poderia escapar da sanitização.
- Código morto: `FichaNaoEncontradaConsultaError` nunca é lançado (`functions/src/domain/consultaHistorico.ts:12`); o repositório lança `AcessoNaoAutorizadoError`.
- Leituras sem limite/paginação e N+1 em `consultarLinhaDoTempoAutorizadaRepo` (lê todas as `evidenciasDecisao`/`participacoes` e consulta `equipes` por evidência — `functions/src/repositories/consultaHistorico.ts:246,354,401`).
- Formatos divergentes de mascaramento de CPF: `functions/src/domain/consultaHistorico.ts:109` (`***.456.789-**`) vs `functions/src/repositories/decisaoCoordenador.ts:63` (`123.***.***-01`); unificar é decisão de UX fora do escopo desta story.

## Deferred from: code review of spec-4-2-solicitar-equipe-adicional (2026-10-07)

- Callable `solicitarEquipeAdicional`: sucesso e mapeamento de erros de domínio não exercitados; os dois únicos testes cobrem `unauthenticated` e `permission-denied`, e o caminho feliz só é testado no repositório (`test/solicitarEquipeAdicional.test.ts:441`). Diferido: testes de repositório fixam os desfechos; contrato do callable pode ser pinado com emulator depois.
- Cobertura de verificação ausente no repositório: recibo de outro uid (`PermissaoNegadaError`), bloqueio por estado não-terminal não-rejeitado, propagação de `correlationId` e corrida com `commandId` distinto para a mesma equipe. Diferido: reforço de suíte.
- `SOLICITAR_EQUIPE_ADICIONAL` ausente de `MAPA_ACOES_NOTIFICAVEIS` (`functions/src/domain/notificacao.ts:60`): o evento de auditoria não notifica o responsável pela equipe. Diferido: notificar nova solicitação não está no escopo explícito da story; decisão de produto.
- Concorrência sem garantia determinística: duas solicitações com `commandId` distintos para a mesma equipe não têm chave de unicidade determinística (`functions/src/repositories/solicitarEquipeAdicional.ts:122`); a isolação serializável do Firestore pode já impedir o duplo, mas não há teste que comprove. Marca maybe-false: um teste de concorrência no emulator (duas transações simultâneas) settle o caso.
- Contrato de segurança/Rules não estendido para o novo endpoint: a lista de callables do cliente em `security-contract.test.ts:162` não inclui `solicitarEquipeAdicional`. Diferido: verificação de contrato, sem impacto funcional imediato.

## Deferred from: code review of spec-4-3-cancelar-participacao-ou-voluntariado (2026-10-07)

- Cancelamento administrativo pelas filas de Pastor/Equipe/Coordenador não implementado: o `Approach` da story prevê ação de cancelamento/desligamento com justificativa nas filas, mas só `MinhaFichaScreen` foi integrada com `isLideranca: false` fixo; o backend já valida a autoridade de liderança. Diferido: backend autoritativo; superfície de UI das filas em story própria.
- Nomenclatura diverge do Code Map: o spec nomeia `ConfirmarCancelamentoParticipacaoDialog`/`ConfirmarCancelamentoVoluntariadoDialog` e `FichaService`/`FirebaseFichaService`/`MemoriaFichaService`; o código usa `Cancelar...Dialog` e `FichaGateway`/`FirebaseFichaGateway`, sem implementação em memória de `FichaGateway`. Diferido: cosmético, sem consumidor.
- Vigência temporal do vínculo não validada nas checagens de autoridade: `verificarSePastorLocal`/`verificarSeResponsavelEquipe` só filtram `estado == 'VIGENTE'`, sem janela `inicioVigencia`/`fimVigencia` (AD-2), mesma convenção pré-existente de `decisaoPastor.ts:220-238`/`decisaoResponsavelEquipe.ts:240-260`. Diferido: padrão do codebase; o modelo marca o vínculo como `ENCERRADO` ao encerrar, sem caso alcançável hoje.

## Deferred from: code review of story-5.1-calcular-vigencia-anual-e-alertas-de-renovacao (2026-10-07)

- Job de expiração processa uma transação por participação (`functions/src/repositories/expirarCiclo.ts`): aumento de latência proporcional ao volume e aplicação parcial em caso de falha no meio do lote (recuperável por reexecução idempotente). Reestruturar para lote/claims atômicos é mudança maior, deferida.

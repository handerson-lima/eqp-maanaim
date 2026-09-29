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

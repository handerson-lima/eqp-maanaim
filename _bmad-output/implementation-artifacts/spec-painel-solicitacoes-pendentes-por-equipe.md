---
title: 'Painel Geral de Solicitações Pendentes por Equipes'
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_commit: 'b122b7fb8a7da28c53ac052ad2e4717e4ad98d5b'
route: 'dispatch'
review_loop_iteration: 0
context:
  - 'AGENTS.md'
  - '_bmad-output/specs/spec-gestao-voluntarios-maanaim/SPEC.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O Administrador Geral atualmente só consegue acompanhar pendências através de filas pontuais (Fila do Pastor, Fila do Responsável da Equipe ou Fila da Coordenação Geral). Não existe uma superfície unificada onde o administrador visualize todas as solicitações pendentes da organização de uma só vez, agrupadas por equipes operacionais e pesquisáveis por qualquer dado do formulário (nome, CPF, profissão, igreja, etc.).

**Approach:** Criar uma Cloud Function callable privilegiada (`consultarSolicitacoesPendentesGlobal`) com RBAC estrito (`podeAdministrar`) que consolide todas as participações pendentes (`AGUARDANDO_PASTOR_LOCAL`, `AGUARDANDO_RESPONSAVEL_EQUIPE`, `AGUARDANDO_COORDENADOR`), enriquecidas com os dados cadastrais da ficha e de catálogo; e desenvolver no Flutter Web (`AdminShell`) a tela responsiva "Solicitações por Equipe", contendo pesquisa universal full-text em tempo real, agrupamento em acordeões por equipe com badges numéricos e cartões detalhados do voluntário.

## Boundaries & Constraints

**Always:**
- Validação estrita de autoridade administrativa: a consulta só pode ser executada por administradores vigentes (`podeAdministrar` via `autoridadesAdministrativas/{uid}` e `enforceAppCheck: true`).
- Apenas leitura (read-only): a tela consolida e exibe pendências sem alterar estados ou histórico.
- Máscara e proteção de CPF: exibição padrão com máscara (`010.***.***-00`) para visualização segura, permitindo busca tanto pelo CPF digitado com pontuação quanto apenas pelos dígitos.
- Interface mobile-first (coluna única no celular, expansão em desktop, alvos de toque >= 44px, tokens canônicos `navy-900`, `blue-600` e WCAG 2.2 AA).
- Agrupamento canônico pelas 14 equipes do catálogo; equipes sem pendências mostram contagem zerada ou estado colapsado.

**Never:**
- Nunca permitir que voluntários sem autoridade administrativa acessem ou invoquem o endpoint global de solicitações.
- Nunca expor senhas, tokens ou dados não pertinentes à gestão de voluntariado.
- Nunca realizar mutações de domínio diretamente do cliente no Firestore.
- Nunca usar listas hardcoded no cliente para equipes ou igrejas; usar dados projetados pelo backend.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consulta administrativa com pendências | Administrador autenticado chama `consultarSolicitacoesPendentesGlobal` | Retorna lista de solicitações pendentes agrupadas/ordenadas com dados do voluntário, igreja, equipe e status | 200 OK |
| Consulta por usuário não administrador | Chamada por voluntário comum | Rejeição imediata | `permission-denied` genérico |
| Filtro de busca por nome ou profissão | Termo digitado na busca (ex: "Handerson" ou "TI") | Filtra instantaneamente no cliente os voluntários que batem com o termo, atualizando contadores por equipe | Lista filtrada em tempo real |
| Filtro de busca por CPF (com ou sem máscara) | Termo digitado (ex: "010.179" ou "010179") | Encontra o voluntário independentemente da formatação dos pontos/traço | Busca normalizada por dígitos |
| Nenhuma pendência cadastrada | Banco sem solicitações pendentes | Exibe estado vazio com mensagem informativa e ícone temático | Feedback visual amigável |

</frozen-after-approval>

## Code Map

Backend:
- `functions/src/repositories/solicitacoesPendentes.ts` -- Leitura agregada das participações pendentes no Firestore com enriquecimento de dados da ficha, igreja e equipe.
- `functions/src/commands/consultarSolicitacoesPendentesGlobal.ts` -- Cloud Function callable v2 com App Check e RBAC (`podeAdministrar`).
- `functions/src/index.ts` -- Exportação da nova callable.

Frontend:
- `flutter_app/lib/features/admin/solicitacoes_pendentes_service.dart` -- Modelos de dados e gateway cliente para comunicação com a Cloud Function.
- `flutter_app/lib/features/admin/painel_solicitacoes_pendentes_screen.dart` -- Tela com campo de pesquisa universal, acordeões expansíveis por equipe, badges de contagem e cards de voluntários.
- `flutter_app/lib/features/admin/admin_shell.dart` -- Registro da nova rota/aba "Solicitações por Equipe" na sidebar e drawer do shell administrativo.
- `flutter_app/lib/main.dart` -- Injeção do novo gateway no `AdminShell`.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/repositories/solicitacoesPendentes.ts` -- Implementar leitura e projeção de participações pendentes com cache de igrejas/equipes e mascaramento de CPF.
- [x] `functions/src/commands/consultarSolicitacoesPendentesGlobal.ts` -- Criar callable com segurança App Check e verificação de autoridade administrativa.
- [x] `functions/src/index.ts` -- Exportar a nova função no bundle do backend.
- [x] `flutter_app/lib/features/admin/solicitacoes_pendentes_service.dart` -- Criar contratos e modelos para o painel de solicitações.
- [x] `flutter_app/lib/features/admin/painel_solicitacoes_pendentes_screen.dart` -- Construir a interface com busca universal, agrupamento por equipe e acessibilidade WCAG 2.2 AA.
- [x] `flutter_app/lib/features/admin/admin_shell.dart` e `flutter_app/lib/main.dart` -- Conectar a tela ao shell administrativo.

**Acceptance Criteria:**
- Given um administrador logado no sistema, when acessa a aba "Solicitações por Equipe", then visualiza todas as solicitações pendentes agrupadas pelas equipes com a contagem total de cada uma.
- Given o campo de busca no painel, when digita qualquer dado do formulário (nome, CPF, profissão, igreja ou equipe), then a listagem reflete imediatamente apenas as solicitações correspondentes.
- Given um usuário sem perfil de administrador, when tenta invocar o endpoint, then a operação é rejeitada com erro de permissão negada.

## Implementation Notes

- Deploy da Cloud Function `consultarSolicitacoesPendentesGlobal` realizado com sucesso no projeto `eqp-maanaim` (Node.js 22, Gen 2, região us-central1).
- Integração da nova aba "Solicitações por Equipe" no `AdminShell` com navegação responsiva (sidebar no desktop, drawer no mobile).
- Cobertura de testes automatizados com `flutter_app/test/painel_solicitacoes_pendentes_test.dart` validando os 6 cenários da matriz de I/O (pesquisa por nome, CPF formatado/limpo, profissão, igreja, estado vazio e métricas).
- Hot restart disparado na aplicação local.

## Review Triage Log

| ID | Camada | Reivindicação | Veredito | Justificativa | Ação |
|---|---|---|---|---|---|
| RV-01 | Edge Cases | Equipes sem pendências poluírem a tela com 14 acordeões vazios | `false` | A tela agrupa apenas equipes que possuem solicitações pendentes ativas, preservando interface limpa e focada. | Nenhuma |
| RV-02 | Segurança | Exposição acidental de CPF limpo a perfis não administrativos | `false` | A callable backend verifica autoridade administrativa com `podeAdministrar` e bloqueia qualquer outro usuário com `permission-denied`. | Nenhuma |
| RV-03 | Acessibilidade | Touch targets de botões de expandir/recolher inferiores a 44px | `false` | TextButtons possuem `minimumSize: const Size(44, 36)` e botão de atualizar possui `minimumSize: const Size(44, 44)`. | Nenhuma |
| RV-04 | Layout | RenderFlex overflow em telas compactas e testes de widget | `low` | Corrigido envolvendo descrições e títulos em `Expanded` com elipse textual e Material design. | `patch` aplicado |

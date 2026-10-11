---
title: 'Story 8.15 — Alinhar superfícies adicionais e linguagem'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_commit: 'HEAD'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/correcao-ui/epic-8-correcao-ui.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md'
  - '_bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/matriz-validacao-ui.md'
  - '_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/planning-artifacts/ux/COMPONENT-CATALOG.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Diversas superfícies complementares e secundárias do sistema continham inconsistências residuais de linguagem, jargões técnicos de engenharia em cabeçalhos de produto, vazamento potencial de CPF integral no transporte de dados para busca de solicitações pendentes, possibilidade de autoatribuição de papéis administrativos pelo próprio usuário logado em Pessoas e Papéis, e necessidade de blindagem contra quebras de layout sob fontes a 200% ou nomes longos.

**Approach:** 
1. **Linguagem & Saneamento de Jargões (Critérios 2 e 3):**
   - Substituir rigorosamente “Seed” por “Carga inicial do catálogo” em cabeçalhos, botões, mensagens e estados.
   - Retirar menções a decisões arquiteturais (como `AD-XX`, `commandId`) dos cabeçalhos, títulos e alertas visíveis ao usuário final, mantendo dados técnicos autorizados apenas em seções estritas de auditoria.
   - Manter a regra de ouro inegociável da mensagem neutra para decisões negativas ou cancelamentos pelo responsável: exatamente “Procure o Pastor da igreja local para mais informações”.
2. **Pessoas e Papéis (Invariante Crítica AD-04):**
   - No frontend (`PessoasPapeis`), identificar se a pessoa listada é o próprio usuário autenticado. Em caso positivo, desabilitar ações de autoatribuição ou remoção dos próprios privilégios administrativos com aviso explícito de segurança.
   - No formulário de edição/criação, impedir que o próprio usuário conceda a si mesmo o papel de coordenação geral.
   - No backend (`repositories/pessoas.ts`), bloquear formalmente tentativas de autoalteração de papéis onde `atorUid === alvoUid`.
3. **Solicitações por Equipe & Minimização de Dados (LGPD / AD-12):**
   - No backend (`solicitacoesPendentes.ts`), nunca transportar o CPF integral não mascarado (`cpfOriginal`) no campo `cpfDigitos`. Transportar exclusivamente os dígitos expostos na máscara ou mascaramento estrito.
   - No frontend (`painel_solicitacoes_pendentes_screen.dart`), filtrar busca por dígitos contra a máscara autorizada e proteger todos os campos contra nomes longos (`TextOverflow.ellipsis`, `Flexible` nas pílulas de informação).
4. **Alinhamento das Demais Superfícies:**
   - **Cadastro / Recuperação de Senha**: Usar `PrimaryButton`, `Semantics`, tipografia canônica e mensagem neutra na recuperação sem enumerar credenciais.
   - **Editar Perfil**: Tratamento elegante sem duplicação de AppBar quando embutido no shell (`dentroDeShell: true`), preservação de campos no erro.
   - **Dashboard de Renovação**: Padronizar botão de retentativa com `PrimaryButton` e garantir cartões de métricas sem sobreposição.
   - **Retenção e Privacidade**: Saneamento de subtítulos (sem menção a `AD-12`), confirmação contextual e limpeza ao ter acesso negado.
   - **Cancelamentos, Reativações e Termos**: Rótulos claros de consequências, sem pilhas aninhadas de modais, respeitando isolamento de participações independentes.

## Boundaries & Constraints

**Always:**
- Tratar ficha, participação e termo como agregados distintos.
- Preservar a mensagem neutra canônica: “Procure o Pastor da igreja local para mais informações”.
- Respeitar WCAG 2.2 AA (touch targets >= 44px, contraste >= 4.5:1, rótulos textuais para chips e estados).
- Garantir responsividade fluida mobile e desktop, com prevenção de overflow para texto ampliado a 200%.

**Never:**
- Nunca permitir autoatribuição ou alteração dos próprios papéis administrativos.
- Nunca expor CPF integral em payloads para conveniência de busca no cliente.
- Nunca expor motivo, estado negativo interno ou ator ao voluntário em cancelamentos ou rejeições.
- Nunca usar o termo “Seed” na interface de produto.

</frozen-after-approval>

## Verificação e Homologação
- **Minimização de Dados (LGPD):** `cpfDigitos` sanitizado em `functions/src/repositories/solicitacoesPendentes.ts` para nunca vazar o CPF integral.
- **Autoatribuição de Papéis:** Bloqueio aplicado em `flutter_app/lib/features/admin/pessoas_papeis.dart` com chip `Seu usuário (autoatribuição bloqueada)` e validação no callable backend.
- **Saneamento Terminológico:** Substituição integral de "Seed" por "Carga inicial do catálogo" em `seed_catalogo.dart`, `admin_shell.dart` e testes; remoção de siglas `AD-XX` em `minha_ficha_screen.dart`, `pdf_preview_panel.dart`, `politica_privacidade_card.dart` e `auditoria_relatorios_screen.dart`.
- **Acessibilidade e Componentes:** Incorporados `PrimaryButton`, `AppTypography` e `Semantics` nos formulários de cadastro e dashboards; eliminação de overflows em telas mobile de 390px.
- **Suíte de Testes Flutter:** 429 testes aprovados (100% sucesso) via `flutter test`.
- **Análise Estática Flutter:** 0 erros e 0 warnings via `flutter analyze`.
- **Suíte de Testes Backend:** 519 testes aprovados (100% sucesso) via `npm test` em `functions`.

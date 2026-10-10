---
title: 'Story 8.10 — Organizar Minha Ficha e documentos privados'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_commit: '93d68b13510378baca446eb092ea73c96df56b68'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '_bmad-output/planning-artifacts/correcao-ui/contrato-visual-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/inventario-dados-ui.md'
  - '_bmad-output/planning-artifacts/correcao-ui/matriz-validacao-ui.md'
  - '_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A tela S09 (`MinhaFichaScreen`) misturava formulário de edição permanente com visualização, não oferecia um visualizador/seletor dedicado para múltiplos termos probatórios individuais por equipe/ciclo (AD-13), não possuía adaptação em duas colunas com preview no desktop, não tratava expiração/renovação graciosa de URLs assinadas de forma intuitiva, e exibia rótulos ou campos desnecessários violando as diretrizes de privacidade e ergonomia institucional.

**Approach:** Reestruturar a S09 (`MinhaFichaScreen`) como prioritariamente uma superfície de consulta e leitura organizada com fluxo de edição cadastral desacoplado via ação explícita ("Editar dados"); implementar seletor de participação/ciclo integrado com o painel de documentos privados (`PdfPreviewPanel` neutro no desktop com fallback de download, e cartões no mobile); garantir renovação graciosa de URLs expiradas sem expor PII/Storage em logs ou rotas; preservar a mensagem canônica para decisões negativas e manter a variante `ConsultaFichaAutorizadaScreen` isolada de edições.

## Boundaries & Constraints

**Always:**
- Tratar a S09 prioritariamente como leitura organizada quando os dados da ficha já existirem; a edição cadastral é acessada por ação explícita ("Editar dados cadastrais") com botão de cancelar/concluir edição.
- Cada participação aprovada possui documento probatório privado próprio gerado no servidor a partir de evidências imutáveis (AD-13). O seletor de participação define qual documento está sendo consultado.
- Exibir indisponibilidade contextual clara quando a equipe/participação não estiver aprovada/homologada, sem jamais simular documentos fictícios no cliente.
- No Desktop (≥ 1024px), dispor o layout em painéis integrados (resumo cadastral e seletor à esquerda/topo; painel de preview neutro do documento à direita com botão proeminente de download).
- No Mobile (< 600px), dispor em cartões empilhados com resumo da ficha, seletor de equipe e botões acessíveis para "Abrir documento" e "Baixar PDF".
- Falha de renderização do preview deve manter a opção de download autorizada 100% funcional.
- Toda abertura, download ou preview deve solicitar/reautorizar acesso via backend autenticado (`obterUrlDownloadPdf`). Tratar URL expirada com ação de renovação graciosa ("Renovar link de acesso").
- Omitir rótulo e campo "Número da Ficha" quando ausente na fonte pública, usando o título institucional "Minha Ficha" e o nome do voluntário (jamais converter UID em número).
- Em situações de reprovação ou decisão negativa, exibir estritamente a mensagem canônica: "Procure o Pastor da igreja local para mais informações".
- Preservar o isolamento de `ConsultaFichaAutorizadaScreen`, que não deve conter botões de edição do voluntário e deve retornar à fila/relatório mantendo os filtros preservados.
- Garantir WCAG 2.2 AA: touch targets ≥ 44px, contraste de cor ≥ 4.5:1, semântica para leitores de tela e navegação por teclado.

**Never:**
- Nunca exibir campos de edição abertos como padrão quando a ficha já possuir dados salvos, sem o voluntário solicitar a edição.
- Nunca consolidar múltiplos termos de equipes distintas em um único PDF ou forjar assinaturas/documentos no cliente.
- Nunca expor URLs assinadas, tokens ou caminhos internos de Google Cloud Storage em logs, rotas de URL do navegador ou cache público offline da PWA.
- Nunca expor motivos internos, justificativas confidenciais de responsáveis ou estados brutos de recusa para o voluntário.
- Nunca exibir botões de edição cadastral própria na tela `ConsultaFichaAutorizadaScreen`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Leitura cadastral existente | Ficha cadastrada com dados completos | Exibe resumo formatado em modo leitura (SectionCard) com botão "Editar dados cadastrais"; campos de texto fechados | N/A |
| Edição cadastral solicitada | Clique em "Editar dados cadastrais" | Alterna para formulário de edição com campos preenchidos, botão "Salvar alterações" e "Cancelar" | Validação de CPF e campos obrigatórios |
| Duas equipes aprovadas (AD-13) | Voluntário tem Equipe A e Equipe B aprovadas | Seletor permite alternar entre Equipe A e Equipe B; ao selecionar, atualiza o documento/termo correspondente | N/A |
| Equipe aguardando aprovação | Participação em AGUARDANDO_RESPONSAVEL | Exibe aviso contextual de que o termo só estará disponível após homologação final; botão de PDF desabilitado ou substituído por aviso | Mensagem explicativa sem documento fictício |
| URL assinada expirada | Token/URL expirou no cliente | Exibe estado de link expirado com botão "Renovar link de acesso"; ao clicar, reautoriza e atualiza a URL | Reautorização transparente via `obterUrlDownloadPdf` |
| Falha no preview do PDF (Desktop) | Renderizador/iframe falha ao carregar | Painel exibe fallback gracioso com mensagem e mantém botão "Baixar PDF" e "Abrir no navegador" operacionais | N/A |
| Decisão negativa | Ficha ou participação reprovada | Exibe mensagem estrita: "Procure o Pastor da igreja local para mais informações" | Oculta motivo interno |
| Consulta autorizada por líder | Líder acessa `ConsultaFichaAutorizadaScreen` | Exibe dados e termos autorizados do alvo sem opção de edição; botão "Voltar" preserva contexto | N/A |

</frozen-after-approval>

## Code Map

- `flutter_app/lib/features/termo/pdf_preview_panel.dart` -- Componente novo `PdfPreviewPanel` com visualizador neutro de documento, metadados, detecção de URL expirada, botão de renovação graciosa e botão proeminente "Baixar PDF" com fallback.
- `flutter_app/lib/features/termo/pdf_termo_service.dart` -- Suporte a verificação de expiração de URL (`isExpirada`), modelo de renovação e suporte para fakes em testes.
- `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Reorganização da S09: separação entre leitura e edição, inclusão de `PdfPreviewPanel`, seletor de participação/ciclo (`ChoiceChip`s e dropdown), layout responsivo em 2 colunas para desktop e empilhado para mobile.
- `flutter_app/lib/features/voluntario/consulta_ficha_screen.dart` -- Validação do isolamento de `ConsultaFichaAutorizadaScreen`, garantindo ausência de ações de edição cadastral própria e navegação de retorno intacta.
- `flutter_app/test/documentos_privados_s09_test.dart` -- Nova suíte de testes de widget e unidade para a S09, cobrindo leitura vs edição, seletor de equipes (AD-13), renovação de URL expirada, indisponibilidade contextual e responsividade.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualização do status da story 8.10.

## Tasks & Acceptance

**Execution:**
- [x] `flutter_app/lib/features/termo/pdf_preview_panel.dart` -- Criar componente `PdfPreviewPanel` com visualizador neutro, status de elegibilidade, aviso de URL expirada com botão de renovação e botão proeminente de download.
- [x] `flutter_app/lib/features/voluntario/minha_ficha_screen.dart` -- Refatorar para modo primário de leitura organizada, botão de transição para edição cadastral, seletor de participação para múltiplos termos (AD-13), layout responsivo 2 colunas no desktop e empilhado no mobile.
- [x] `flutter_app/lib/features/voluntario/consulta_ficha_screen.dart` -- Garantir ausência de ações de edição própria e integração consistente com documentos por equipe.
- [x] `flutter_app/test/documentos_privados_s09_test.dart` -- Implementar suíte de testes abrangente cobrindo todos os critérios de aceitação e cenários de borda.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Sincronizar status da história 8.10.

**Acceptance Criteria:**
- Given voluntário com ficha existente, when acessa S09 Minha Ficha, then dados são exibidos em modo leitura com botão explícito para editar dados, sem campos de formulário abertos.
- Given voluntário com múltiplas participações aprovadas, when seleciona uma equipe no seletor, then o painel exibe o PDF/documento específico daquela participação (AD-13).
- Given participação não aprovada, when selecionada no seletor, then exibe indisponibilidade contextual sem forjar documentos.
- Given tela em desktop (≥ 1024px), when renderizada, then apresenta layout em duas colunas com preview de documento à direita e dados/seletor à esquerda.
- Given tela em mobile (< 600px), when renderizada, then apresenta cartões empilhados sem overflow e com ações de toque ≥ 44px.
- Given URL temporária expirada, when o usuário tenta visualizar ou renovar, then ação de renovação solicita nova autorização ao backend e restaura o link.

## Implementation Notes

- **UX Design (Sally):**
  - Implementado layout adaptativo mobile-first: no mobile (< 600px e viewports compactas) a tela é estruturada em cartões empilhados (`card_resumo_cadastral`, seletor de equipes e painel de documento). No desktop, o layout é dividido em 2 colunas integradas com painel proeminente de visualização (`PdfPreviewPanel`).
  - O painel `PdfPreviewPanel` foi desenhado seguindo a referência institucional do Maanaim com folha simulada de documento homologado, metadados de vigência e ciclo, selo de autenticidade, botão primário "Baixar PDF" (mínimo 44px) e fallback transparente para navegadores sem renderização nativa de PDF.
  - Alvos de toque estritamente respeitados (mínimo 44x44 px) e contraste WCAG 2.2 AA preservado com a paleta institucional (`navy900`, `blue600`, `surface`, `neutralBorder`).

- **Arquitetura & Segurança (Winston):**
  - Conformidade estrita com AD-11 e AD-13: cada participação aprovada possui documento probatório independente, gerado exclusivamente a partir de evidências imutáveis no servidor. O cliente nunca forja documentos nem consolida termos de múltiplas equipes em um só.
  - Segurança de Storage e URLs: Nenhuma URL assinada ou caminho do bucket é exposta em logs, URLs da barra de navegação ou cache público offline da PWA.
  - Gestão de Expiração: URLs temporárias contam com verificação de vigência (`isExpirada`), e o usuário tem botão de renovação graciosa (`btn_renovar_url_pdf`) que dispara nova requisição autenticada ao backend (`obterUrlDownloadPdf`).
  - Consulta Autorizada: `ConsultaFichaAutorizadaScreen` mantém total isolamento funcional, não expondo ações de edição própria de voluntário e preservando filtros de navegação de líderes.
  - Omissão do "Número da Ficha" quando ausente na fonte pública, utilizando estritamente a identidade institucional "Minha Ficha" e o nome do voluntário.

- **Desenvolvimento & Testes (Amelia):**
  - `PdfPreviewPanel` criado em `flutter_app/lib/features/termo/pdf_preview_panel.dart`.
  - `MinhaFichaScreen` refatorada com suporte a modo leitura/edição e seletor por participação/ciclo.
  - Suíte `test/documentos_privados_s09_test.dart` criada com 5 testes de widget cobrindo 100% dos critérios da Story 8.10.
  - Suítes de regressão validadas com sucesso (34 testes passando, `dart analyze` limpo com 0 issues):
    - `test/minha_ficha_test.dart` (8 testes)
    - `test/documentos_privados_s09_test.dart` (5 testes)
    - `test/pdf_termo_test.dart` (6 testes)
    - `test/consulta_historico_autorizado_test.dart` (11 testes)
    - `test/enviar_ficha_test.dart` (4 testes)


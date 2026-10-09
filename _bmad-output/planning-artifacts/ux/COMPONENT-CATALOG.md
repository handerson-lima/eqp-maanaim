# COMPONENT CATALOG --- Flutter UI

Contrato consolidado: [contrato visual](../correcao-ui/contrato-visual-ui.md), [inventário](../correcao-ui/inventario-dados-ui.md) e [contratos de dados](../architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md). Estado: especificação documental de 8.1; implementação e homologação permanecem futuras.

**Objetivo:** orientar agents BMAD na criação de componentes
reutilizáveis, sem impor implementação prematura.

## 1. Estrutura

-   `AppShell`
-   `AppSidebar`
-   `AppTopBar`
-   `PageHeader`
-   `ResponsiveContent`
-   `SectionCard`

## 2. Navegação

### AppSidebar

Props conceituais: itens, item ativo, usuário/perfil quando necessário,
modo compacto. Estados: desktop, compacto, drawer mobile.

### AppTopBar

Suporta: avatar, nome, papel, número da ficha, status, seletor
contextual, ações.

### NavItem

Ícone + label. Estados default/hover/active/disabled.

## 3. Formulários

-   `AppTextField`
-   `PasswordField`
-   `SearchField`
-   `AppDropdown`
-   `AutocompleteField`
-   `CheckboxTile`
-   `TeamSelectionTile`
-   `FormSection`
-   `InlineValidationMessage`

Todos devem compartilhar altura, radius, border, foco e tipografia do
Design System.

## 4. Ações

-   `PrimaryButton`
-   `SecondaryButton`
-   `ApproveButton`
-   `RejectButton`
-   `DangerButton`
-   `IconActionButton`

Ações destrutivas exigem confirmação quando houver impacto persistente.

## 5. Status e feedback

-   `StatusChip`
-   `MetricCard`
-   `ProgressValidityCard`
-   `Toast/Snackbar`
-   `ConfirmationDialog`
-   `EmptyState`
-   `ErrorState`
-   `LoadingSkeleton`

Estados internos são mapeados do contrato do domínio por público autorizado; não constituem lista hardcoded de negócio. Voluntário não recebe chip de rejeição/cancelamento por responsável: usa a mensagem neutra canônica.

## 6. Dados operacionais

### AppDataTable

Recursos: - cabeçalho; - ordenação quando aplicável; - paginação; -
filtros externos; - ações por linha; - adaptação responsiva.

### ResponsiveRecordList

Alternativa mobile à tabela.

### FilterBar

Busca + filtros contextuais + limpar filtros.

## 7. Domínio

-   `VolunteerSummaryCard`
-   `VolunteerIdentityHeader`
-   `TeamStatusRow`
-   `TeamSelectionCard`
-   `ApprovalSummary`
-   `DecisionPanel`
-   `SignatureRecord`
-   `AuditTimeline`
-   `TermAcceptanceCard`
-   `ValidityCard`
-   `RenewalCard`
-   `ChurchSelector`
-   `ChurchAssignmentPanel`
-   `PastorAssignmentSummary`
-   `DocumentLinkRow`
-   `PdfPreviewPanel`

## 8. Composição esperada por tela

### LoginPage

`InstitutionalPanel + LoginCard`

### VolunteerDashboardPage

`PageHeader + MetricCardGrid + ValidityCard + TeamStatusList`

### TeamRequestPage

`PageHeader + WorkflowStepper + TeamSelectionGrid + FooterActions`

### PastorDashboardPage

`PageHeader + ContextFilter + MetricCardGrid + PendingApprovalsTable`

### ApprovalDetailPage

`VolunteerSummaryCard + RequestedTeamsCard + DocumentsCard + DecisionPanel`

### ChurchesAdminPage

`PageHeader + FilterBar + ChurchesTable`

### PastorChurchAssignmentPage

`PastorIdentity + ChurchSelector + ChurchAssignmentPanel + SaveAction`

### MyFormPage

`PageHeader + ResumoFicha + SeletorParticipacaoCiclo + PdfPreviewPanel + HistoricoAutorizado`

## 9. Regras de componentização

-   Não criar componente genérico se só existir um uso e não houver
    ganho de clareza.
-   Não duplicar estilos.
-   Não codificar nomes de igrejas/equipes em widgets.
-   Status devem vir do domínio e ser renderizados por mapeamento
    semântico central.
-   Responsividade deve ser responsabilidade de layouts/componentes
    apropriados, não de hacks por tela.

## 10. Inventário executável e lacunas (08/10/2026)

As listas das seções1–8 são **composições conceituais**, não garantia de que exista classe Flutter homônima. Nesta tabela, caminhos são relativos a `flutter_app/lib/ui/components/`. Existente significa classe encontrada, não componente homologado. Consultar o [inventário por tela](../correcao-ui/inventario-dados-ui.md) antes de duplicar.

| Implementação existente | Arquivo real | Reuso/ajuste previsto |
|---|---|---|
| AppShell, AppSidebar, AppTopBar, AppNavItem | `app_shell.dart` | 8.2/8.4: shell único, contexto/capacidades, drawer/compacto/sidebar; AppNavItem é o nome real do conceito NavItem. |
| PageHeader, SectionCard, LoadingSkeleton, EmptyState, ErrorState | `layout_elements.dart` | 8.2: geometria, texto ampliado, feedback acessível; E nos consumidores. |
| PrimaryButton, SecondaryButton, ApproveButton, RejectButton, DangerButton, IconActionButton | `buttons.dart` | 8.2: contraste e estados completos, loading, foco/alvos 44. |
| StatusChip, StatusConfig | `status_chips.dart` | 8.2/8.5: mapeamento semântico por público; nunca projetar negativo interno ao voluntário. |
| MetricCard, ProgressValidityCard | `metrics.dart` | 8.2/8.5/8.6: unidade/indisponível, vigência por participação; texto “Validade da Ficha” deve ser substituído no componente futuro. |
| AppDataTable, AppDataColumn, ResponsiveRecordList, FilterBar | `responsive_data_table.dart` | 8.2/8.6/8.11/8.13: tabela desktop/cards mobile, filtros e paginação autorizados. |
| LogoMaanaim | `logo_maanaim.dart` | 8.4: assets existentes sem recolorir marca, sem imagem do mockup. |
| FeedbackOrientacaoCard | `feedback_orientacao_card.dart` | 8.5/8.15: mensagem neutra canônica intacta inclusive semântica. |
| VigenciaBadge | `vigencia_badge.dart` | 8.5/8.9: vigência real por participação/ciclo. |
| CpfText, CpfInputFormatter | `cpf_formatter.dart` | Reusar máscara/formatação; não ampliar exposição de CPF. |

AppTextField/PasswordField/SearchField/AppDropdown/AutocompleteField, TeamSelectionTile/Grid, WorkflowStepper, ResponsiveContent, ConfirmationDialog, VolunteerSummaryCard/DecisionPanel e PdfPreviewPanel são **conceitos planejados**, sem equivalência de classe comprovada nesse diretório. Antes de extraí-los, aproveitar campos Material tematizados, diálogos/formulários e serviços existentes nas features. Somente criar abstração quando compartilhamento ou clareza justificar: 8.2 controles comuns; 8.7 resumo/decisão; 8.8/8.9 etapas/seleção; 8.10 preview; 8.12 seleção/revisão de vínculos. Composições como MetricCardGrid/PendingApprovalsTable também não são classes existentes confirmadas.

Status de domínio não são uma lista de permissões/estados inventada pelo catálogo. Rótulos vêm do mapeamento do domínio autorizado; negativa/cancelamento por responsável para voluntário sempre usa “Procure o Pastor da igreja local para mais informações”. Não usar chip, ícone, KPI ou semântica para revelar o estado interno. MyFormPage compõe resumo da ficha, seletor de participação/ciclo, documento próprio e histórico; nunca um PDF consolidado.

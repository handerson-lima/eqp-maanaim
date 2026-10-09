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

Status mínimos: `ATIVA`, `EM APROVAÇÃO`, `AGUARDANDO`, `REJEITADA`,
`INATIVA`, `CANCELADA`, `EXPIRADA`, `EM RENOVAÇÃO`.

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

`PageHeader + PdfPreviewPanel`

## 9. Regras de componentização

-   Não criar componente genérico se só existir um uso e não houver
    ganho de clareza.
-   Não duplicar estilos.
-   Não codificar nomes de igrejas/equipes em widgets.
-   Status devem vir do domínio e ser renderizados por mapeamento
    semântico central.
-   Responsividade deve ser responsabilidade de layouts/componentes
    apropriados, não de hacks por tela.

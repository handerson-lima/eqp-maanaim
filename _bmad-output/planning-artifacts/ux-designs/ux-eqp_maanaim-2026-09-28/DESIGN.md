---
name: Sistema de Gestão de Voluntários do Maanaim
status: final
sources:
  - ../../PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md
updated: 2026-09-28
colors:
  primary: '#1F5B45'
  primary-foreground: '#FFFFFF'
  surface: '#FFFFFF'
  surface-subtle: '#F6F8F6'
  ink: '#17211C'
  muted: '#5C6A62'
  border: '#D6E0D9'
  success: '#16794A'
  warning: '#9A6700'
  danger: '#B42318'
typography:
  display: { note: 'Flutter Material 3 headline' }
  body: { note: 'Flutter Material 3 body' }
  meta: { note: 'Flutter Material 3 label' }
rounded: { sm: 6px, md: 12px, lg: 16px }
spacing: { '1': 4px, '2': 8px, '3': 12px, '4': 16px, '5': 24px, '6': 32px }
components:
  primary-action: { background: '{colors.primary}', foreground: '{colors.primary-foreground}', radius: '{rounded.md}' }
  status: { radius: '{rounded.full}', 'note': 'texto + ícone; nunca apenas cor' }
---

## Brand & Style

**[ASSUMPTION]** Interface institucional, sóbria e acolhedora: clareza sobre o estado do processo acima de ornamentação. O sistema não possui identidade visual fornecida; estes tokens são provisórios e devem ser substituídos por diretrizes do Maanaim quando existirem.

## Colors

Verde identifica ação principal e continuidade; cores de estado só reforçam texto e ícone. Nunca usar vermelho para rejeição sem a explicação e a ação seguinte.

## Typography

Usar a escala Material 3 do Flutter; suportar escala de fonte do sistema sem truncar ações ou estados.

## Layout & Spacing

Escala de 4 px. Conteúdo em uma coluna no celular; no desktop, navegação lateral e área de trabalho com largura de leitura. Tabelas de pendências viram cartões agrupados no celular.

## Elevation & Depth

Elevação discreta apenas para superfícies acionáveis. A prioridade vem da ordem, títulos e estados, não de sombras pesadas.

## Shapes

Campos e botões usam `{rounded.sm}`; cartões e painéis usam `{rounded.md}`. Status podem usar forma pill, sem depender só dela para comunicar significado.

## Components

- **Linha de pendência:** responsável, entidade, prazo/vigência, estado textual e ação primária contextual.
- **Linha do tempo auditável:** ator, papel/vínculo em snapshot, ação, data/hora e justificativa; é somente leitura.
- **Cartão de participação:** equipe, ciclo, estado e próxima ação; cada equipe é independente.
- **Confirmação de ação crítica:** resume alvo, consequência, justificativa quando obrigatória e autenticação/aceite registrado.
- **Indicador de ciclo anual:** início, vencimento, janela de renovação e situação por equipe.

## Do's and Don'ts

| Fazer | Não fazer |
|---|---|
| Mostrar situação por equipe e por ciclo | Reduzir várias equipes a um único status opaco |
| Explicar quem deve agir e o que bloqueia | Exibir apenas “pendente” |
| Preservar histórico e contexto de decisão | Oferecer edição/exclusão de eventos |
| Confirmar ações irreversíveis operacionalmente | Usar confirmação genérica sem alvo ou consequência |

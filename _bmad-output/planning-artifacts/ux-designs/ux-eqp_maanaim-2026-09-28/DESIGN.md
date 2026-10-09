---
name: Sistema de Gestão de Voluntários do Maanaim
status: final
sources:
  - ../../PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md
updated: 2026-10-08
colors:
  primary: '#0B6FE8'
  primary-foreground: '#FFFFFF'
  surface: '#FFFFFF'
  surface-subtle: '#F5F7FA'
  ink: '#172033'
  muted: '#667085'
  border: '#DDE3EA'
  success: '#16794A'
  warning: '#9A6700'
  danger: '#B42318'
typography:
  display: { note: 'H1 24/700; H2 20/700; H3 16/600 institucional' }
  body: { note: '14/400; Inter, fallback Roboto/sans-serif' }
  meta: { note: 'label 13/600; caption 12/400; botão 14/600' }
rounded: { sm: 6px, md: 10px, full: 999px }
spacing: { '1': 4px, '2': 8px, '3': 12px, '4': 16px, '5': 24px, '6': 32px }
components:
  primary-action: { background: '{colors.primary}', foreground: '{colors.primary-foreground}', radius: '{rounded.sm}' }
  status: { radius: '{rounded.full}', 'note': 'texto + ícone; nunca apenas cor' }
---

## Brand & Style

Referência visual fornecida pelo usuário em 29/09/2026: interface institucional com navegação azul-marinho (#082C49), ações azuis, fundo azul muito claro e painéis brancos com bordas discretas. No acesso desktop, marca à esquerda e formulário à direita; no celular, marca compacta acima do formulário. Reutilizar LogoMaanaim e assets locais inventariados no contrato; fotografia institucional ausente usa navy sólido.

## Colors

Azul identifica ações principais; verde identifica estados positivos; cores de estado só reforçam texto e ícone. Para o voluntário, decisão negativa/cancelamento por responsável usa somente “Procure o Pastor da igreja local para mais informações”; não revela rejeição, motivo nem ator.

## Typography

Usar a escala institucional de DESIGN-SYSTEM (Material apenas mapeia os tokens); suportar escala de fonte do sistema sem truncar ações ou estados.

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

## Aplicação da referência

Cabeçalho claro com identidade e papel ativo; menu lateral escuro no desktop; conteúdo organizado em painéis com títulos curtos. As telas futuras seguem essa composição, adaptando tabelas para cartões no celular. A imagem é referência de aparência, não fonte de dados, permissões ou funcionalidades. Não reproduzir contagens fictícias, login Google sem implementação ou rótulos de rejeição ao voluntário: prevalecem os contratos do domínio. Campos interativos mantêm contorno com contraste próprio, distinto das bordas decorativas.

## Contrato consolidado em 08/10/2026

[Contrato visual](../../correcao-ui/contrato-visual-ui.md), [Design System](../../ux/DESIGN-SYSTEM.md) e [contratos de integração](../../architecture/architecture-eqp_maanaim-2026-09-28/UI-CONTRACTS.md) detalham estas regras. O pacote ux/ prevalece sobre defaults Material e exemplos legados; preservam-se SPEC e ADs. 8.1 consolida documentação, sem homologar UI.

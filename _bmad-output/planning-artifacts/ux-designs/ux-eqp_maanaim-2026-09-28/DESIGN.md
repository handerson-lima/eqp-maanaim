---
name: Sistema de Gestão de Voluntários do Maanaim
status: final
sources:
  - ../../PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md
updated: 2026-09-29
colors:
  primary: '#005BD8'
  primary-foreground: '#FFFFFF'
  surface: '#FFFFFF'
  surface-subtle: '#F3F7FB'
  ink: '#13233D'
  muted: '#50627A'
  border: '#DCE5EF'
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

Referência visual fornecida pelo usuário em 29/09/2026: interface institucional com navegação azul-marinho (#0C2940), ações azuis, fundo azul muito claro e painéis brancos com bordas discretas. No acesso desktop, marca à esquerda e formulário à direita; no celular, marca compacta acima do formulário. Usar o nome Maanaim até que os arquivos oficiais do logotipo e da fotografia estejam disponíveis.

## Colors

Azul identifica ações principais; verde identifica estados positivos; cores de estado só reforçam texto e ícone. Nunca usar vermelho para rejeição sem a explicação e a ação seguinte.

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

## Aplicação da referência

Cabeçalho claro com identidade e papel ativo; menu lateral escuro no desktop; conteúdo organizado em painéis com títulos curtos. As telas futuras seguem essa composição, adaptando tabelas para cartões no celular. A imagem é referência de aparência, não fonte de dados, permissões ou funcionalidades. Não reproduzir contagens fictícias, login Google sem implementação ou rótulos de rejeição ao voluntário: prevalecem os contratos do domínio. Campos interativos mantêm contorno com contraste próprio, distinto das bordas decorativas.

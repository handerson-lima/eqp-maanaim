---
title: 'Layout baseado na referência visual Maanaim'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

Aplicar a direção visual da imagem fornecida às telas existentes do projeto: identidade azul-marinho, ações azuis, superfícies claras, formulário de acesso em painel e navegação lateral no desktop. Preservar responsividade mobile-first, acessibilidade, autenticação e comportamento do catálogo. Registrar a referência no DESIGN.md para orientar telas futuras. A imagem orienta composição e aparência; suas métricas e funcionalidades ilustradas não constituem dados reais nem novos fluxos funcionais.

</frozen-after-approval>

## Implementation Notes

- Mudança visual local e reversível, sem alteração de APIs, dados ou implantação.
- Centralizar tema e moldura de acesso; adaptar main.dart, admin_shell.dart e apresentação do catálogo. Preservar rotas e ações existentes.

- Tema compartilhado azul e marinho; início, login e cadastro com moldura responsiva; administração com menu e cabeçalho; DESIGN atualizado para telas futuras.
- Validação: análise estática sem problemas; 40 testes passaram; após acrescentar cenários de navegação em 600/1000 px com texto 2×, os cinco testes administrativos passaram.
- Não foi feita inspeção visual em navegador. Logotipo e fotografia originais não estão disponíveis no repositório; aplicação utiliza marca textual e degradê.

## Review Triage Log

- medium: cabeçalho do catálogo agravava restrição de altura com teclado; título movido para a lista rolável.
- medium: linha do cabeçalho administrativo podia exceder largura com fonte ampliada; substituída por Wrap e validada em 600/1000 px a 2×.
- low: cadastro sem continuidade visual; moldura compartilhada aplicada.
- low: menu móvel sem identidade azul-marinho; tema local do Drawer atualizado.
- low: títulos sem semântica de cabeçalho; Semantics aplicado aos títulos adicionados.
- medium: cobertura insuficiente dos limites; testes adicionados com tema real, fonte ampliada e larguras mobile/desktop. Teste revelou overflow no login após aviso, corrigido removendo a altura intrínseca que restringia o formulário.

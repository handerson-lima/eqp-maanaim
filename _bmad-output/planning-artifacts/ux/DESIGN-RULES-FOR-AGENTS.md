# DESIGN RULES FOR BMAD AGENTS

**Aplicação:** todos os agents que planejem, especifiquem, implementem
ou revisem UI/UX.

## Regra 1 --- Referência normativa

Use `references/maanaim-ui-reference.png` como referência visual
normativa. Não redesenhar o produto com preferências próprias.

## Regra 2 --- Ordem de precedência

Quando houver conflito: 1. requisito funcional/segurança do PRD; 2.
acessibilidade; 3. SCREEN-SPECS; 4. UX-LAYOUT-SPEC; 5. DESIGN-SYSTEM; 6.
imagem de referência; 7. defaults do Flutter/Material.

Defaults de framework têm a menor prioridade visual.

## Regra 3 --- Não inventar identidade

Não introduzir: - nova paleta; - gradientes decorativos; -
glassmorphism; - cards excessivos; - ilustrações aleatórias; - navegação
diferente; - Material 3 default sem customização.

## Regra 4 --- Reutilização

Antes de criar widget novo, verificar `COMPONENT-CATALOG.md`.
Componentes equivalentes devem compartilhar estilos e comportamento.

## Regra 5 --- Dados

Nunca hardcodar igrejas, equipes, pastores, status de negócio ou
permissões na UI. Seeds são dados de backend.

## Regra 6 --- Responsividade

Cada story de tela deve declarar comportamento desktop/tablet/mobile.
"Reduzir tudo" não é estratégia responsiva.

## Regra 7 --- Estados

Toda tela assíncrona deve especificar: - loading; - empty; - error; -
success; - permission denied quando aplicável.

## Regra 8 --- Ações críticas

Aprovar, rejeitar, cancelar, substituir responsável, publicar termo e
outras ações críticas devem ter contexto inequívoco e confirmação quando
o impacto justificar.

## Regra 9 --- Fidelidade verificável

Critérios de aceite de UI devem incluir comparação com a referência
visual. O reviewer deve verificar sidebar, topbar, tipografia, spacing,
radius, cores semânticas, tabelas e estados.

## Regra 10 --- Material

Flutter Material é infraestrutura, não identidade visual. Criar
ThemeData/tokens próprios derivados do Design System.

## Regra 11 --- Texto

Usar português do Brasil. Labels curtos e objetivos. Não usar jargão
técnico para usuários finais.

## Regra 12 --- Segurança visual

Ocultar botão não é autorização. A UI pode esconder ações indisponíveis,
mas a autorização real permanece no backend conforme PRD.

## Regra 13 --- Alterações

Se uma story exigir mudança significativa do design, registrar a decisão
no artefato de UX antes de implementar. Não fazer deriva visual
silenciosa.

## Checklist obrigatório para UI story

-   [ ] Usa AppShell e navegação padrão
-   [ ] Respeita tokens
-   [ ] Usa componentes existentes quando aplicável
-   [ ] Possui desktop/mobile
-   [ ] Possui loading/empty/error
-   [ ] Status têm texto, não só cor
-   [ ] Ações críticas têm contexto
-   [ ] Sem dados de domínio hardcoded
-   [ ] Sem Material default destoante
-   [ ] Comparada com a referência visual

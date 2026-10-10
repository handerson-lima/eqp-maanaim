---
title: 'Story 8.14 — Exibir versões e aceites pendentes dos termos'
type: 'feature'
created: '2026-10-10'
status: 'done'
baseline_commit: '43a6a86cd4fa0ddec7ad77daaa551415bd82b8ed'
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

**Problem:** A tela administrativa S13 (`TermosScreen`) exibia apenas o título, hash e conteúdo das versões sem fornecer métricas auditáveis de adesão por versão. Além disso:
1. Ao publicar um novo termo, o total de voluntários impactados não persistia o universo nominal imutável $U(V)$ de fichas em estado `ATIVA`, impedindo a verificação de quem efetivamente aceitou aquela versão ao longo do tempo.
2. Não havia diferenciação entre **Pendência Operacional Vigente** ("Ativos com aceite vigente pendente" — fichas atualmente ATIVA sem comprovante da versão vigente) e **Histórico da Versão** ("Afetados na publicação sem aceite desta versão" — baseado no snapshot $U(V)$ no instante da publicação).
3. Dados legados sem snapshot $U(V)$ corriam o risco de alucinar contagens zeradas ou deduzir errôneamente os ativos atuais como sendo os ativos na data da publicação.
4. O backend (`aceitarTermoVigenteRepo`) restringia o aceite estritamente a fichas em `RASCUNHO`, bloqueando voluntários já ativos com ficha `ATIVA` de registrar novo aceite após a publicação de uma nova versão vigente desatualizada.
5. A UI carecia de tabela adaptativa no desktop (`AppDataTable`) e cartões limpos no mobile (`AppCard` / `ResponsiveRecordList`), além de exibir o hash SHA-256 completo na listagem principal em vez de restringi-lo ao detalhe técnico.
6. A publicação de termo não apresentava modal de revisão detalhado com impacto estimado sobre os voluntários ativos e alerta enfático de imutabilidade.

**Approach:** 
1. **Universo de Aceites por Versão $U(V)$ e Projeção Autorizada:**
   - Ao publicar uma nova versão $V$, persistir na transação atômica o snapshot imutável $U(V)$ contendo a contagem de afetados, lista de `fichaId` opacos (sem PII), instante do servidor e critério `ESTADO_ATIVA_NA_PUBLICACAO`.
   - Registrar no documento de aceite da versão $V$ em `termos/{termoId}/versoes/{versaoId}/aceites/{uid}` e na subcoleção do voluntário `fichas/{uid}/aceites/{versaoId}`.
   - Calcular aceites históricos como $|U(V) \cap A(V)|$ e pendências históricas como $|U(V) - A(V)|$.
   - Calcular separadamente a pendência operacional vigente como o número de voluntários atualmente em estado `ATIVA` cujo `termoAceito.versaoId !== versaoVigenteId`.
2. **Tratamento Rigoroso de Dados Ausentes vs. Zero (Anti-Alucinação):**
   - Para versões legadas sem snapshot $U(V)$ registrado, exibir explicitamente `"Indisponível — universo histórico não registrado"`.
   - Exibir zero somente quando a consulta completa e autorizada comprovar matematicamente que o conjunto está vazio ($|U(V)| = 0$).
3. **Extensão de Aceite para Fichas ATIVA:**
   - Estender `aceitarTermoVigenteRepo` para permitir aceite em fichas em estado `RASCUNHO` ou `ATIVA`.
   - Preservar ciclos, histórico e participações já aprovados (nenhuma regressão de estado).
   - Validar versão vigente, `hashSha256`, idempotência via `commandId` e declaração de leitura explícita.
   - Rejeitar com `TermoNaoVigenteError` caso a versão mude durante o fluxo.
4. **Interface S13 Responsiva (Mobile-First e Desktop):**
   - Desktop: `AppDataTable` com colunas Versão, Publicação, Situação (Vigente/Histórico), Ativos com Aceite Vigente Pendente, Afetados na Publicação e Ações ("Ver documento" e "Histórico/Detalhes"). Nenhuma opção de edição ou exclusão (estrita imutabilidade).
   - Mobile: Cartões responsivos sem rolagem horizontal, com hash resumido e detalhes em bottom sheet modal.
5. **Modal de Revisão de Publicação:**
   - Exibir título, versão prevista, hash SHA-256 pré-calculado, impacto estimado sobre voluntários ativos atuais e aviso de imutabilidade irreversível.
6. **Acessibilidade WCAG 2.2 AA:**
   - Touch targets $\ge 44$px, contraste $\ge 4.5:1$, `StatusChip` com rótulo explícito e sem depender de cor isolada.

## Boundaries & Constraints

**Always:**
- Tratar ficha, participação e termo como agregados distintos.
- Manter documentos de termos, versões e comprovantes de aceite estritamente imutáveis e append-only.
- Diferenciar os rótulos canônicos: "Ativos com aceite vigente pendente" (vigente operacional) vs "Afetados na publicação sem aceite desta versão" (histórico).
- Exibir "Indisponível — universo histórico não registrado" quando não houver snapshot $U(V)$.
- Permitir que voluntários em estado `ATIVA` aceitem o termo vigente sem que isso altere suas participações ou ciclos passados.
- Exigir `commandId` idempotente (mínimo 16 caracteres) e hash determinístico.
- Garantir responsividade fluida mobile e desktop via `AppDataTable` e cartões.

**Never:**
- Nunca inventar contagens zeradas ou deduzir ativos atuais como substituto de snapshot histórico.
- Nunca permitir edição ou exclusão de versão publicada.
- Nunca expor PII, CPF ou nomes em metadados de auditoria e listas de afetados.
- Nunca bloquear ou regredir participações aprovadas ao aceitar novo termo vigente em ficha ativa.

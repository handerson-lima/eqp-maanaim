---
id: SPEC-gestao-voluntarios-maanaim
companions:
  - ../../planning-artifacts/PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md
  - ../../planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/DESIGN.md
  - ../../planning-artifacts/ux-designs/ux-eqp_maanaim-2026-09-28/EXPERIENCE.md
  - ../../planning-artifacts/architecture/architecture-eqp_maanaim-2026-09-28/ARCHITECTURE-SPINE.md
sources: []
---

> **Contrato canônico.** Este SPEC e seus `companions` constituem o contrato completo para construir, testar e validar o Sistema de Gestão de Voluntários do Maanaim. Os ADs do architecture spine são invariantes vinculantes para toda story e implementação.

# Sistema de Gestão de Voluntários do Maanaim

## Why

Digitalizar o ciclo de voluntariado — cadastro, aprovação, gestão, renovação e encerramento — para que voluntários e responsáveis possam agir com clareza, escopo correto e rastreabilidade, sem perder decisões, termos ou histórico quando equipes e responsáveis mudam.

## Capabilities

- **CAP-1 — Ficha e solicitação inicial**
  - **intent:** Voluntário pode manter ficha permanente, informar Nome Completo, Profissão e CPF no primeiro preenchimento, selecionar múltiplas equipes e enviar a solicitação após aceitar o termo vigente.
  - **success:** O envio cria participações independentes e comprovante do termo; nenhuma solicitação segue sem os dados obrigatórios, equipes e aceite válidos.

- **CAP-2 — Autorização contextual de decisões**
  - **intent:** Responsável pode decidir somente a pendência correspondente a seu papel, vínculo vigente, escopo e estado.
  - **success:** Tentativas com papel, vínculo, entidade ou estado inválidos são recusadas pelo backend e não geram alteração nem evidência.

- **CAP-3 — Fluxo por equipe**
  - **intent:** Sistema permite aprovação local e análises simultâneas, independentes, pelas equipes.
  - **success:** A rejeição de uma equipe não bloqueia as demais aprovadas, e cada estado é visível por equipe.

- **CAP-4 — Conclusão coordenada**
  - **intent:** Coordenador pode concluir uma solicitação elegível após confirmar a reunião de pastores e realizar aceite autenticado.
  - **success:** A ativação ocorre apenas com todas as evidências exigidas persistidas e consultáveis.

- **CAP-5 — Gestão do ciclo de participação**
  - **intent:** Usuários autorizados podem adicionar equipe, cancelar participação ou voluntariado, inativar e reativar sem apagar o passado.
  - **success:** Ações alteram somente os agregados permitidos, mantêm os ciclos anteriores finais e recalculam o resumo da ficha de forma determinística.

- **CAP-6 — Renovação anual seletiva**
  - **intent:** Voluntário manifesta por equipe se deseja continuar, e equipes selecionadas atravessam um novo ciclo de aprovação.
  - **success:** Existe no máximo um ciclo não terminal por participação e ano; renovação não sobrescreve aprovação ou renovação anterior.

- **CAP-7 — Administração de configuração e vínculos**
  - **intent:** Administrador gerencia igrejas, equipes, termos e vínculos históricos de responsáveis.
  - **success:** Há no máximo um Pastor Local vigente por igreja; substituições preservam decisões e roteiam apenas pendências não decididas.

- **CAP-8 — Evidência, consulta e documentos**
  - **intent:** Usuários autorizados consultam histórico, auditoria, dashboards, relatórios e um PDF por equipe aprovada, derivado de evidências reais.
  - **success:** Cada mutação crítica possui recibo, evento/evidência e auditoria correlacionados; cada PDF privado reproduz a estrutura do termo e só é entregue após nova autorização.

## Constraints

- Flutter Web/PWA é cliente; Cloud Functions transacionais são a única fronteira de mutação crítica (AD-1).
- Autorização combina Firebase Auth, papel não autoatribuível, vínculo vigente no tempo do servidor, escopo e máquina de estados (AD-2, AD-5).
- Ficha, participação e ciclo anual são agregados distintos; estados e redução seguem AD-4, AD-5 e AD-11.
- Termos, evidências e auditoria são versionados/append-only; comandos usam idempotência e outbox transacional (AD-6 a AD-10).
- Firestore e Storage negam acesso por padrão; PII é minimizada e PDFs permanecem privados (AD-9, AD-12).
- Cada equipe aprovada gera PDF próprio no formato do termo de adesão: dados do voluntário, equipe, data, assinatura do voluntário, Coordenador, Pastor Local e Pastor responsável pela equipe; dados preenchidos somente de registros/evidências autorizados (AD-13).
- UX, acessibilidade, superfícies e jornadas seguem `EXPERIENCE.md`; identidade visual segue `DESIGN.md`.
- Cada ciclo vigora por 1 ano a partir da aprovação final do Coordenador; ficha, auditoria, PDFs e backups têm retenção de 5 anos, salvo obrigação legal superior.

## Non-goals

- Certificado digital, provedor externo de assinatura, validação pública/QR Code e WhatsApp não fazem parte do escopo inicial.
- Dados iniciais de igrejas e equipes não são enums, listas hardcoded ou constantes do Flutter.
- Auditoria, decisões, ciclos, termos e vínculos históricos não são editáveis ou removíveis por fluxos comuns de produto.

## Success signal

Em uma demonstração ponta a ponta, uma voluntária pode ser aprovada em uma equipe e rejeitada em outra, renovar somente a participação desejada e obter PDF/histórico que comprovem cada decisão, mesmo após troca de responsável. Tentativas de agir fora de vínculo, vigência ou estado são bloqueadas sem modificar o domínio.

## Assumptions

- Cada equipe possui um responsável canônico vigente; não há co-responsáveis neste momento.
- Projetos Firebase de desenvolvimento, homologação e produção serão isolados; confirmar no plano operacional.

## Open Questions

- Qual é a janela anual e o calendário/escalonamento de alertas derivados do vencimento de cada ciclo?
- Qual base legal e responsável institucional LGPD aplicam a retenção de 5 anos?

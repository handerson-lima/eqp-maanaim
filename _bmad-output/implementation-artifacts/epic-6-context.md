# Epic 6 Context: Evidência, documentos e visão operacional

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Garantir evidência imutável e auditável das decisões de voluntariado, entregar PDFs privados individuais por equipe, oferecer consultas autorizadas e operar o sistema sob retenção, minimização de dados pessoais, acessibilidade e controles de segurança de ambiente.

## Stories

- Story 6.1: Registrar e reconciliar evidência/auditoria imutável
- Story 6.2: Consultar auditoria e relatórios autorizados
- Story 6.3: Gerar e entregar PDF privado da ficha
- Story 6.4: Aplicar retenção, minimização e controles operacionais de dados
- Story 6.5: Acesso inclusivo e responsivo às superfícies do voluntariado
- Story 6.6: Verificar segurança, índices e ambientes Firebase

## Requirements & Constraints

- Eventos de auditoria, FCM, logs e erros contêm apenas IDs opacos, ação, estado, timestamps UTC, papel/vínculo em snapshot e motivo categorizado; nunca ficha completa, documento, endereço, token ou assinatura.
- Ficha, auditoria, PDFs e backups são retidos por 5 anos, salvo obrigação legal superior; anonimização preserva IDs e eventos e mascara PII nas projeções elegíveis.
- PDFs ficam em bucket privado, só funções autorizadas os criam/leem, com URL curta revogável e registro de geração/acesso.
- Alterações de IAM, Rules, deleções e falhas de backup devem ser monitoradas por Cloud Audit Logs; contas de serviço com menor privilégio.
- Toda tela atende WCAG 2.2 AA, mobile-first, alvos ≥44 px e estado nunca só por cor.
- Mensagem ao voluntário em decisão negativa é exatamente "Procure o Pastor da igreja local para mais informações".

## Technical Decisions

- Mutações críticas apenas em Cloud Functions; Firestore e Storage negam escrita/delete do cliente.
- Estados em `UPPER_SNAKE_CASE`; `commandId` idempotente com recibo em `commands` e evento em `auditOutbox`, materializado em `auditoria` por trigger/reconciliação.
- Transações respeitam o orçamento de 500 operações; relógio sempre do servidor.
- Configuração operacional fica em `configuracoes/{doc}`; igrejas e equipes são dados, nunca constantes.

## UX & Interaction Patterns

- Reutilizar AppShell, SectionCard, tokens `navy-900`/`blue-600` e gateways Cloud/Memória; sem gradientes ou glassmorphism.
- Telas assíncronas declaram loading, empty, error, success e permission denied; ações críticas pedem confirmação.

## Cross-Story Dependencies

- 6.4 depende da auditoria (6.1) e do PDF privado (6.3); 6.6 verifica índices, Rules e ambientes que 6.4 amplia.

# Revisão de rubric — Architecture Spine

**Veredito: NEEDS_CHANGES.** A espinha fixa bem a autoridade de mutação, evidência, escopo temporal e a separação ficha/participação/ciclo, mas ainda deixa divergências que as stories de renovação, cancelamento e auditoria inevitavelmente decidirão de maneiras incompatíveis.

Lint mecânico: **aprovado** (`0` achados).

## Achados prioritários

### HIGH — Matriz de transições e de autoridade ainda está diferida

**Evidência:** AD-5 só torna explícito o caminho inicial; `Deferred` adia a matriz de cancelamento, expiração e reativação. O PRD e a UX exigem renovação seletiva por equipe, encerramento da não renovada, cancelamento parcial/total e reativação.

**Por que falha no rubric:** duas stories podem escolher estados, quem pode comandá-los, qual ciclo nasce e quando uma participação volta à fila de formas distintas. Isso é um ponto real de divergência do nível abaixo, não detalhe de implementação.

**Ação:** antes das stories, adicionar uma regra/tabela canônica (pode viver no módulo único referido por AD-5) para cada comando: estado/ciclo de origem, ator e vínculo exigidos, transição/efeito por participação, evidência e projeção de fila. Fixar explicitamente se renovação repete todas as aprovações e o tratamento de “não continuar”.

### HIGH — Atomicidade da auditoria não está garantida fora do limite transacional

**Evidência:** AD-8 exige estado + dois eventos “na mesma transação quando couber no limite Firestore”, mas não define o protocolo quando não couber. AD-10 permite processamento posterior de notificação, não de auditoria.

**Por que falha no rubric:** implementadores podem fazer writes parciais, retries diferentes ou aceitar mutação sem a dupla evidência, contrariando o paradigma append-only e a promessa auditável.

**Ação:** vincular um protocolo único para comandos que excederem a transação (por exemplo, limite de agregado por comando ou registro transacional de `command/outbox` que bloqueia a projeção até a escrita idempotente de todos os eventos), com invariantes de recuperação e reconciliação.

### HIGH — Limite de acesso a PII/auditoria e ACL de PDF está materialmente aberto

**Evidência:** AD-9 fala genericamente em “dados sensíveis”; `Deferred` deixa retenção, acesso operacional à auditoria e ACL de download de PDF para depois. O PRD inclui ficha pessoal, histórico, relatórios e auditoria para papéis com escopos diferentes.

**Por que falha no rubric:** Rules, Functions e UI podem divergir sobre quais campos um pastor de equipe, pastor local, coordenador e administrador leem; links/PDF podem ser implementados com acesso excessivo.

**Ação:** fixar agora uma classificação mínima por recurso/campo e a política de leitura/geração/entrega de PDF (incluindo Storage path/ACL e expiração). Deixar apenas prazo institucional de retenção como Deferred, com condição de revisão.

### MEDIUM — Stack e envelope operacional não são reproduzíveis o suficiente

**Evidência:** Flutter/Dart está “versão estável a ser fixada”; ambientes separados são `[ASSUMPTION]`; não há regra para identidades de serviço, segredos, backup/restauração, observabilidade ou resposta a falhas.

**Ação:** confirmar ou registrar como questão bloqueadora os ambientes; pinçar versões/geradores no bootstrap e decidir ownership de secrets, logs/métricas/alertas e backup/export do Firestore antes de produção. Isso fecha o envelope operacional sem transformar o spine em manual de infraestrutura.

## Pontos sólidos

- AD-1/2/3 evitam a maior fonte de erro: autorização baseada apenas em perfil, sem vínculo e vigência.
- AD-4/6/7 preservam corretamente a independência por equipe e a evidência histórica/versionada.
- O mapa de capacidades cobre as áreas centrais do PRD e a UX é coerente com filas e decisões por equipe.

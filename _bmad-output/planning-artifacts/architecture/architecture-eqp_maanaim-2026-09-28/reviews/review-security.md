# Revisão de Segurança e Integridade

**Escopo:** `ARCHITECTURE-SPINE.md` contra PRD v1.1, com foco em Firebase, PII, auditoria, vínculos e renovação.  
**Conclusão:** a direção (comandos no servidor, evidência append-only e autorização no instante da decisão) é adequada, mas há decisões de controle que devem ficar fechadas antes de derivar stories.

## Achados que bloqueiam stories de acesso/auditoria

| Prioridade | Achado | Risco | Fechamento necessário |
|---|---|---|---|
| P0 | AD-1 nega escrita direta de “recursos de domínio”, porém não especifica a matriz Firestore/Storage para `users`, ficha em rascunho, termos, vínculos, projeções, auditoria e PDFs. | Uma regra permissiva, uma collection-group query ou um caminho novo pode expor PII ou permitir elevação de privilégio. Firestore Rules não filtram resultados: a consulta inteira deve ser autorizável. | Publicar matriz por coleção/subcoleção: leitor, predicado verificável, campos expostos e `create/update/delete`; `deny` por padrão; tests Emulator de acesso cruzado, coleção-grupo, enumeração de IDs e acesso após expiração do vínculo. |
| P0 | Fonte e ciclo de vida de papéis administrativos não são definidos. | Se perfil/claim puder ser criado ou atualizado pelo próprio cliente, qualquer usuário pode se tornar administrador/pastor/coordenador. Mesmo Functions privilegiadas ignoram Rules. | Definir autoridade única de RBAC (por exemplo, custom claims somente por função administrativa com IAM restrito), revogação/propagação de token, e separação entre identidade, papel e vínculo. Auditar cada concessão/revogação e impedir autoatribuição. |
| P0 | “Append-only” é uma intenção de Rules, não uma garantia contra a conta de serviço das Functions, administradores Firebase/GCP, importações ou scripts. AD-8 também permite a auditoria deixar de estar na mesma transação “quando couber”. | Uma mutação pode ficar sem evento, ou uma operação privilegiada pode reescrever/apagar provas sem detecção. | Definir um *transactional outbox*/registro de comando: estado + evidência/auditoria obrigatória no mesmo commit; rejeitar comandos que excedam o limite e particionar com correlação, nunca continuar silenciosamente. Restringir IAM de produção/contas de serviço, registrar Admin Activity/Cloud Audit Logs e prever exportação/backup imutável e monitoramento de deleção. |
| P0 | A política LGPD (retenção, anonimização, acesso operacional) e ACL/TTL do PDF foram postergadas, embora o PRD as exija. | Dados pessoais, justificativas e assinaturas podem persistir indefinidamente; PDF/URL assinado pode vazar e relatórios/exportações podem ampliar o acesso. | Antes de stories: inventário/classificação de PII, finalidade/base legal e prazos; campos permitidos no `antes/depois`; fluxo de anonimização que preserva evidência; retenção/backup; autorização e auditoria de exportações. Para PDF: bucket privado, sem URL pública, verificação de autorização na emissão/download, TTL/revogação, metadados mínimos e política de cache/remoção. |

## Achados importantes

| Prioridade | Achado | Fechamento necessário |
|---|---|---|
| P1 | A evidência captura nome, papel, vínculo e justificativa, e a auditoria pode capturar `antes/depois`; “snapshots mínimos” não define limites. | Especificar schema de evento e lista de campos permitidos/redigidos; não copiar ficha completa, documento, token, endereço ou dados sensíveis para eventos, FCM, logs, erros ou Analytics. Criptografia em repouso não substitui minimização e controle de leitura. |
| P1 | A autorização temporal é sólida conceitualmente, mas precisa de semântica implementável. | Usar tempo do servidor exclusivamente; definir intervalo semiaberto `[inicioVigencia, fimVigencia)`, fuso/configuração de corte anual e tratamento de ausência de fim. A transação deve ler vínculo, estado e versão, e gravar o snapshot/hora efetivamente autorizadores. |
| P1 | O comando de renovação não fixa a identidade da configuração anual, nem a unicidade por ficha/participação/ano. | Versionar e referenciar o snapshot da configuração (janela, termo e regra) no ciclo; impor chave/idempotência única por escopo e ano; impedir que retry ou mudança administrativa crie dois ciclos ou aplique regra posterior retroativamente. |
| P1 | Termo “imutável” deveria ser verificável, inclusive na saída PDF. | Armazenar conteúdo canônico e hash da versão publicada; evidência/aceite e PDF referenciam ID + hash. Apenas publicação cria uma versão; nenhuma edição destrutiva. |
| P1 | AD-9 cita leituras mediadas quando Rules não provam escopo, sem contrato de redaction/paginação. | Definir endpoints de relatório/auditoria/exportação com autorização contextual no servidor, paginação limitada, filtros obrigatórios de escopo, mascaramento por papel e evento de auditoria para consulta/exportação sensível. |
| P1 | App Check aparece no diagrama, sem política de aplicação. | Exigir validação de Auth + App Check nas funções e recursos suportados, definir comportamento para clientes legítimos sem atestação e proteção contra abuso (rate limit/quota) em comandos e geração de PDF. App Check não é autorização. |

## Critérios mínimos de aceite de segurança

1. Matriz de Rules e testes Emulator negativos/positivos para cada papel, vínculo expirado/trocado e escopo alheio.
2. Testes de concorrência/idempotência para dupla decisão, troca de responsável, expiração no limite e renovação repetida.
3. Prova de que todo comando crítico produz estado, evidência e auditoria correlacionados ou falha integralmente.
4. Modelo de PII/retenção/PDF/exportação aprovado, com testes de que URLs e notificações não expõem dados fora do escopo.
5. IAM de produção, contas de serviço e procedimento de auditoria/recuperação documentados e verificados.

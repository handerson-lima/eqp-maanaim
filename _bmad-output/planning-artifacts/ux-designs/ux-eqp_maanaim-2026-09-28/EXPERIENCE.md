---
name: Sistema de Gestão de Voluntários do Maanaim
status: final
sources:
  - ../../PRD-GESTAO-VOLUNTARIOS-MAANAIM-v1.1.md
updated: 2026-09-28
---

# Experiência — Gestão de Voluntários do Maanaim

## Foundation

Web responsiva/PWA em Flutter para celular, tablet e desktop. `DESIGN.md` é a referência visual; este documento define comportamento. A experiência assume usuários ocasionais, linguagem direta e ações críticas sempre rastreáveis.

## Information Architecture

| Superfície | Acesso | Finalidade |
|---|---|---|
| Início / minhas pendências | abertura | próxima ação, vigência e alertas relevantes ao papel atual |
| Minha ficha | início | dados permanentes, termo, ciclos e histórico pessoal |
| Participações | minha ficha | situação e ações independentes por equipe |
| Fila de aprovação | início de responsável | pendências filtradas apenas pelos vínculos vigentes autorizados |
| Detalhe da solicitação | fila, notificação | evidências, decisões, justificativas e ação permitida |
| Renovação | início, participação | manifestação por equipe e acompanhamento do ciclo anual |
| Administração | navegação do administrador | igrejas, equipes, termos, usuários e vínculos vigentes/históricos |
| Auditoria e relatórios | navegação autorizada | consulta filtrável e exportações futuras |

No desktop, menu lateral; em celular, menu compacto. O papel ativo é visível e a troca de contexto não amplia permissões. Não há pilha de modais: confirmação abre sobre uma única superfície.

## Voice and Tone

| Fazer | Evitar |
|---|---|
| “Aguardando decisão do Pastor Local de Goianinha.” | “Em processamento.” |
| “Segurança não foi aprovada. As outras equipes seguem em análise.” | “Solicitação rejeitada.” |
| “Sua participação em Recepção vence em 31/12/2026.” | “Expira em breve!” |
| “Esta ação será registrada no histórico.” | Linguagem técnica sobre regras internas |

## Component Patterns

| Componente | Regras comportamentais |
|---|---|
| Seletor de equipes | múltipla seleção; resultados e estado por equipe sempre separados |
| Termo | exibe versão e conteúdo antes do aceite; aceite requer declaração explícita e gera comprovante imutável |
| Aprovação | apresenta vínculo usado, estado atual, justificativa e assinatura autenticada; ação só aparece quando autorizada |
| Troca de responsável | mostra responsável atual, data de vigência e pendências que serão redirecionadas; decisões passadas ficam intactas |
| Linha do tempo | ordenação cronológica, sem editar/excluir; abre detalhes de evento quando permitido |
| PDF | sempre gerado a partir de eventos persistidos, não de texto digitado na tela |

## State Patterns

| Estado | Tratamento |
|---|---|
| Rascunho | progresso salvo; envio indisponível até dados, equipe e termo válidos |
| Equipes em análise | cartão por equipe e resumo da ficha; rejeição parcial não bloqueia aprovadas |
| Aguardando coordenador | lista apenas equipes aptas; mostra decisões e confirmação de reunião requerida |
| Ativa | vigência e participações; nova equipe abre fluxo paralelo sem afetar as ativas |
| Em renovação | cada equipe pede “continuar?”; decisões do novo ciclo não sobrescrevem o anterior |
| Expirada | ação operacional bloqueada conforme regra do backend; histórico e renovação permanecem consultáveis |
| Sem permissão | esconder ação e explicar, no detalhe acessível, que o vínculo vigente ou estado não permite atuar |
| Conflito/atualização | recarregar o detalhe e informar que o estado foi alterado; nunca repetir cegamente a decisão |

## Interaction Primitives

- Ação crítica: revisar → informar justificativa quando aplicável → confirmar → aguardar resultado do backend → ver evento registrado.
- Filtros de fila preservam igreja/equipe e ciclo; URL/deep link reabre a mesma superfície quando permitido.
- Ação por equipe não atua em lote por padrão. Operações administrativas em lote exigem confirmação com contagem e itens afetados.
- Notificações levam ao detalhe, não executam decisões.

## Accessibility Floor

- WCAG 2.2 AA; contraste e foco visível conforme `DESIGN.md`.
- Leitor de tela anuncia papel, entidade, equipe, estado e próxima ação.
- Alvos de toque ≥ 44 px; navegação integral por teclado no web.
- Cor nunca é o único sinal de aprovação, rejeição ou vencimento.
- Datas apresentam formato local e, em eventos, data/hora com fuso configurado.

## Fluxos-chave / User Journeys

### Jornada 1 — Primeiro cadastro (Ana, voluntária, no celular após o culto)

1. Ana cria a conta e abre **Minha ficha**.
2. Informa a igreja, completa seus dados e seleciona Recepção e Cozinha.
3. Lê o termo vigente, confirma que leu e aceita eletronicamente.
4. Revisa o resumo: igreja, equipes e termo/versionamento.
5. Envia a ficha; a tela mostra o Pastor Local responsável e o que acontecerá depois.
6. **Clímax:** Ana vê as duas participações como “Aguardando Pastor Local” e o comprovante do termo no histórico.

Falha: termo desatualizado ou dados obrigatórios ausentes impedem o envio com indicação do item a corrigir.

### Jornada 2 — Aprovação paralela por equipe (Pr. Marcos, responsável por duas equipes, no desktop)

1. Após a aprovação local, Marcos abre **Fila de aprovação** já filtrada pelos vínculos vigentes dele.
2. Abre a solicitação de Ana e revisa dados, termo e sua equipe.
3. Aprova Recepção e assina eletronicamente; o evento confirma papel, vínculo e horário.
4. A decisão de Cozinha continua disponível apenas ao responsável daquela equipe.
5. **Clímax:** a ficha de Ana mostra Recepção aprovada e Cozinha ainda em análise, sem ocultar a independência dos processos.

Falha: se o vínculo de Marcos terminou ou outra decisão venceu a ação, o backend rejeita a tentativa e a tela recarrega o estado atual.

### Jornada 3 — Renovação seletiva (Ana, semanas antes do vencimento)

1. Ana recebe um alerta e abre **Renovação 2027**.
2. Vê cada equipe ativa, sua vigência e escolhe continuar em Recepção, mas não em Cozinha.
3. Confirma a manifestação; o sistema registra um novo ciclo, mantendo o anterior consultável.
4. Recepção segue para Pastor Local atual, Pastor de Equipe atual e Coordenador; Cozinha segue pelo encerramento previsto.
5. **Clímax:** Ana acompanha dois desfechos explícitos — “Recepção em renovação” e “Cozinha não será renovada” — sem perder seu histórico.

Falha: se a janela anual estiver fechada, a tela informa a situação e o canal administrativo aplicável, sem prometer renovação automática.

### Jornada 4 — Troca de Pastor Local com pendências (Administração)

1. A administradora abre a igreja e seleciona “substituir responsável”.
2. Informa o novo pastor e a data efetiva; a tela mostra o vínculo anterior e as pendências que mudarão de destinatário.
3. Confirma a operação administrativa.
4. O sistema encerra e cria vínculos de modo consistente, registra auditoria e encaminha apenas pendências não decididas ao novo responsável.
5. **Clímax:** a página da igreja exibe a linha temporal dos dois responsáveis, enquanto decisões anteriores preservam o responsável original.

## Questões assumidas para validação antes de implementação

- **[ASSUMPTION]** Janelas, prazos e regras de expiração serão configuráveis por ciclo anual.
- **[ASSUMPTION]** Cancelamento e reativação exibem motivo obrigatório quando realizados por responsáveis; a matriz exata de motivos fica na arquitetura/story.
- **[ASSUMPTION]** Notificações in-app/PWA são o canal mínimo; WhatsApp permanece fora do escopo inicial.

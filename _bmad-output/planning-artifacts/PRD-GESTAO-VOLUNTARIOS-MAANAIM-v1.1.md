# PRD — Sistema de Gestão de Voluntários do Maanaim

**Versão:** 1.1  
**Status:** Planejamento consolidado  
**Plataforma:** Web / PWA  
**Frontend:** Flutter / Dart  
**Backend:** Firebase / Google Cloud  
**Metodologia:** BMAD  
**IDE / Ambiente de desenvolvimento:** Antigravity  

---

# 1. Visão do Produto

O Sistema de Gestão de Voluntários do Maanaim será uma aplicação Web/PWA destinada a digitalizar e controlar todo o processo de cadastro, aprovação, renovação, ativação, inativação e cancelamento de voluntários e suas respectivas participações em equipes.

O processo envolve uma sequência de validações realizadas por:

1. Voluntário;
2. Pastor Local;
3. Pastor responsável pela equipe;
4. Coordenador do Maanaim.

O sistema deverá transformar esse processo em um workflow eletrônico, rastreável e auditável.

Cada responsável poderá realizar somente as ações correspondentes às suas atribuições e vínculos.

O sistema deverá preservar todo o histórico das decisões durante o ciclo de vida do voluntário, inclusive:

- aprovações;
- rejeições;
- assinaturas eletrônicas;
- alterações;
- cancelamentos;
- reativações;
- mudanças de responsáveis;
- renovações anuais;
- versões de termos.

---

# 2. Objetivo do Produto

Criar uma plataforma centralizada para gerenciar:

```text
CADASTRO
   ↓
ACEITE DO TERMO
   ↓
APROVAÇÃO DO PASTOR LOCAL
   ↓
APROVAÇÃO DOS PASTORES DAS EQUIPES
   ↓
APROVAÇÃO DO COORDENADOR
   ↓
ATIVAÇÃO
   ↓
GESTÃO DO VOLUNTARIADO
   ↓
RENOVAÇÃO ANUAL
   ↓
INATIVAÇÃO / CANCELAMENTO
   ↓
HISTÓRICO
```

---

# 3. Objetivos Principais

O produto deverá:

1. Digitalizar a ficha de voluntário.
2. Permitir autenticação individual.
3. Permitir seleção de uma ou mais equipes.
4. Registrar eletronicamente o aceite do termo.
5. Implementar aprovação pelo Pastor Local.
6. Implementar aprovação independente pelos Pastores das Equipes.
7. Implementar aprovação final pelo Coordenador.
8. Registrar confirmação da consulta do nome na reunião de pastores.
9. Registrar assinaturas eletrônicas autenticadas.
10. Permitir geração da ficha em PDF.
11. Permitir cancelamentos controlados.
12. Permitir reativação.
13. Controlar validade anual.
14. Implementar renovação anual.
15. Permitir inclusão posterior de equipes.
16. Manter histórico completo.
17. Registrar ações para auditoria.
18. Disponibilizar relatórios.
19. Funcionar em desktop, tablet e celular.
20. Poder ser instalado como PWA.

---

# 4. Perfis de Usuário

O sistema terá inicialmente:

- Voluntário;
- Pastor Local;
- Pastor de Equipe;
- Coordenador do Maanaim;
- Administrador.

Um usuário poderá possuir mais de uma função.

Um pastor poderá:

- ser responsável por várias igrejas;
- ser responsável por várias equipes;
- ser simultaneamente Pastor Local e Pastor de Equipe.

As permissões deverão considerar tanto o perfil quanto os vínculos ativos.

---

# 5. Voluntário

O voluntário poderá:

- criar sua conta;
- autenticar-se;
- preencher seus dados;
- atualizar seus dados;
- selecionar uma ou mais equipes;
- visualizar o termo;
- aceitar eletronicamente o termo;
- enviar sua ficha;
- acompanhar o andamento;
- visualizar aprovações;
- visualizar situação por equipe;
- solicitar nova equipe posteriormente;
- manifestar interesse na renovação anual;
- escolher em quais equipes deseja continuar;
- gerar PDF;
- cancelar participação em determinada equipe;
- cancelar todo o voluntariado;
- solicitar reativação quando aplicável;
- consultar seu histórico.

---

# 6. Pastor Local

Cada igreja possuirá, via de regra, **um único Pastor Local vigente por vez**.

Um mesmo Pastor Local poderá ser responsável por várias igrejas simultaneamente.

Exemplo:

```text
Pr. José
   │
   ├── Igreja A
   ├── Igreja B
   └── Igreja C
```

O Pastor Local poderá:

- visualizar voluntários das igrejas sob sua responsabilidade;
- visualizar pendências consolidadas;
- filtrar por igreja;
- analisar fichas;
- aprovar;
- rejeitar;
- registrar justificativa;
- visualizar ativos;
- acompanhar renovações;
- cancelar participação quando permitido;
- cancelar voluntariado quando permitido;
- consultar histórico;
- consultar relatórios.

---

# 7. Relação Pastor ↔ Igreja

A relação deverá seguir:

```text
IGREJA
   │
   └── 1 Pastor Local vigente

PASTOR
   │
   └── 0..N Igrejas
```

Historicamente, uma igreja poderá possuir vários responsáveis em períodos diferentes.

Exemplo:

```text
IGREJA CENTRAL

Pr. João
01/01/2025 → 31/12/2025

Pr. Carlos
01/01/2026 → 30/09/2026

Pr. Antônio
01/10/2026 → atual
```

O vínculo deverá permitir registrar:

```text
pastorId
igrejaId
ativo
inicioVigencia
fimVigencia
```

Não deverão existir dois Pastores Locais simultaneamente vigentes para a mesma igreja.

---

# 8. Pastor de Equipe

Um Pastor de Equipe poderá ser responsável por uma ou várias equipes.

Exemplo:

```text
Pr. José
   │
   ├── Recepção
   ├── Segurança
   └── Apoio
```

Poderá:

- visualizar solicitações das equipes sob sua responsabilidade;
- visualizar pendências consolidadas;
- filtrar por equipe;
- aprovar;
- rejeitar;
- registrar justificativa;
- visualizar participantes ativos;
- acompanhar renovações;
- cancelar participação;
- consultar histórico;
- emitir relatórios.

---

# 9. Coordenador do Maanaim

O Coordenador realizará a etapa final.

Inicialmente a função será exercida pelo **Pr. João Costa**, mas a aplicação não deverá vincular tecnicamente o papel a uma pessoa específica.

Poderá:

- visualizar processos aguardando aprovação final;
- consultar aprovação do Pastor Local;
- consultar decisões dos Pastores das Equipes;
- confirmar consulta na reunião de pastores;
- aprovar;
- rejeitar;
- assinar eletronicamente;
- cancelar participação;
- cancelar voluntariado;
- acompanhar renovações;
- consultar relatórios;
- consultar histórico e auditoria.

---

# 10. Administrador

O Administrador poderá gerenciar:

- usuários;
- pastores;
- igrejas;
- equipes;
- vínculos Pastor ↔ Igreja;
- vínculos Pastor ↔ Equipe;
- Coordenador;
- termos;
- configurações;
- permissões;
- relatórios.

A função administrativa não poderá permitir alteração indevida do histórico de auditoria.

---

# 11. Ficha Permanente e Participações

O sistema deverá separar:

**Ficha do Voluntário**

de

**Participações em Equipes.**

Exemplo:

```text
FV-2026-00123
João Silva

├── Recepção
│   └── ATIVA
│
├── Cozinha
│   └── ATIVA
│
└── Segurança
    └── INATIVA
```

A ficha representará o histórico permanente do voluntário.

As participações representarão seus vínculos com as equipes.

---

# 12. Fluxo Inicial

```text
VOLUNTÁRIO
     │
     ▼
Preenche cadastro
     │
     ▼
Seleciona equipe(s)
     │
     ▼
Aceita termo
     │
     ▼
Envia ficha
     │
     ▼
PASTOR LOCAL
     │
     ├── Rejeita → REJEITADA
     │
     ▼
   Aprova
     │
     ▼
PASTORES DAS EQUIPES
     │
     ├── análises simultâneas
     │
     ├── Equipe A → aprovada
     ├── Equipe B → aprovada
     └── Equipe C → rejeitada
     │
     ▼
COORDENADOR
     │
     ├── verifica aprovações
     ├── confirma consulta na reunião
     ├── aprova/rejeita
     └── assina eletronicamente
     │
     ▼
VOLUNTARIADO ATIVO
```

---

# 13. Múltiplas Equipes

As equipes possuirão processos independentes.

Se o voluntário solicitar três equipes e duas forem aprovadas e uma rejeitada:

| Equipe | Situação |
|---|---|
| Recepção | Aprovada |
| Cozinha | Aprovada |
| Segurança | Rejeitada |

o processo seguirá para o Coordenador considerando as equipes aprovadas.

A rejeição de uma equipe não impedirá a continuidade das demais.

---

# 14. Aprovações Simultâneas

Após a aprovação do Pastor Local, todas as equipes solicitadas serão disponibilizadas simultaneamente aos respectivos responsáveis.

```text
Pastor Local aprova
        │
        ├────► Pastor Equipe A
        ├────► Pastor Equipe B
        └────► Pastor Equipe C
```

Não haverá ordem obrigatória entre os Pastores das Equipes.

---

# 15. Estados da Ficha

Estados previstos:

- RASCUNHO;
- AGUARDANDO_PASTOR_LOCAL;
- AGUARDANDO_EQUIPES;
- AGUARDANDO_COORDENADOR;
- ATIVA;
- EM_RENOVACAO;
- REJEITADA;
- CANCELADA;
- INATIVA;
- EXPIRADA.

A máquina de estados definitiva será especificada na arquitetura.

---

# 16. Estados da Participação

Cada participação poderá assumir:

- AGUARDANDO_APROVACAO;
- APROVADA;
- REJEITADA;
- ATIVA;
- EM_RENOVACAO;
- CANCELADA;
- INATIVA;
- EXPIRADA.

---

# 17. Aceite do Termo

Antes do envio da ficha, o voluntário deverá:

1. visualizar o termo vigente;
2. declarar que leu e concorda;
3. realizar aceite eletrônico.

Deverão ser registrados:

- usuário;
- termo;
- versão;
- data;
- hora;
- ficha;
- informações necessárias à auditoria.

O conteúdo da versão aceita deverá permanecer preservado.

---

# 18. Versionamento do Termo

Quando houver uma nova versão do termo, voluntários ativos deverão realizar novo aceite.

O sistema deverá:

1. identificar a nova versão;
2. identificar quem ainda não aceitou;
3. apresentar o novo termo;
4. registrar o aceite;
5. preservar o aceite anterior.

Nenhuma nova versão deverá sobrescrever o histórico anterior.

---

# 19. Aprovação do Pastor Local

Quando a ficha for enviada, o sistema deverá localizar o Pastor Local vigente da igreja do voluntário.

A decisão deverá registrar:

- pastor;
- igreja;
- vínculo utilizado;
- ficha;
- decisão;
- data;
- hora;
- observação;
- justificativa quando aplicável;
- assinatura eletrônica;
- informações de auditoria.

---

# 20. Aprovação dos Pastores das Equipes

Após a aprovação local, todas as equipes serão liberadas simultaneamente.

Cada decisão deverá registrar:

- equipe;
- pastor;
- vínculo de responsabilidade;
- decisão;
- data;
- hora;
- justificativa;
- assinatura eletrônica;
- histórico.

---

# 21. Aprovação do Coordenador

O Coordenador deverá visualizar:

- voluntário;
- igreja;
- Pastor Local;
- aprovação local;
- equipes solicitadas;
- situação de cada equipe;
- Pastores responsáveis;
- datas das decisões.

Para concluir deverá:

1. confirmar que o nome foi consultado na reunião de pastores;
2. aprovar ou rejeitar;
3. registrar observação quando necessário;
4. realizar aceite eletrônico autenticado.

---

# 22. Assinatura Eletrônica

Neste estágio não será utilizado certificado digital ou provedor externo.

As decisões serão consideradas **aceites eletrônicos autenticados**.

Cada assinatura deverá registrar:

- UID do usuário autenticado;
- nome do responsável;
- função exercida;
- igreja ou equipe relacionada;
- decisão;
- data;
- hora;
- ficha;
- etapa do workflow.

Exemplo:

```text
PASTOR LOCAL
Pr. José da Silva
Igreja Goianinha

Assinado eletronicamente
28/09/2026 às 14:32
```

Para equipe:

```text
PASTOR RESPONSÁVEL — RECEPÇÃO
Pr. Antônio Souza

Assinado eletronicamente
28/09/2026 às 16:41
```

Coordenador:

```text
COORDENADOR DO MAANAIM
Pr. João Costa

Assinado eletronicamente
29/09/2026 às 10:15
```

O texto apresentado no PDF deverá corresponder a um evento efetivamente registrado no backend.

---

# 23. Alterações Cadastrais

O voluntário poderá alterar seus dados posteriormente.

As aprovações existentes continuarão válidas.

Alterações relevantes deverão produzir histórico contendo, quando aplicável:

- responsável pela alteração;
- data/hora;
- campo alterado;
- valor anterior;
- novo valor.

---

# 24. Inclusão Posterior de Equipe

Um voluntário ativo poderá solicitar nova equipe sem criar nova ficha.

Exemplo:

```text
FV-2026-00123
ATIVA

Recepção → ATIVA
Cozinha → ATIVA

        +

Nova solicitação
Segurança → EM APROVAÇÃO
```

As participações existentes permanecerão ativas enquanto a nova solicitação percorre o workflow.

---

# 25. Cancelamento

O sistema permitirá:

### Cancelamento de participação

Cancela somente determinada equipe.

### Cancelamento do voluntariado

Cancela o vínculo geral.

Poderão realizar cancelamentos conforme suas permissões:

- voluntário;
- Pastor Local;
- Pastor de Equipe;
- Coordenador.

O Pastor de Equipe somente poderá atuar sobre equipes pelas quais seja responsável.

Nenhum cancelamento excluirá o histórico.

---

# 26. Reativação

Voluntários cancelados ou inativos poderão ser reativados.

A reativação deverá preservar:

- situação anterior;
- data;
- histórico;
- responsáveis;
- equipes anteriores;
- decisões anteriores.

Um novo ciclo de aprovação poderá ser exigido conforme a máquina de estados definida posteriormente.

---

# 27. Validade Anual

A ficha possuirá validade anual.

O sistema deverá controlar:

- início da vigência;
- término da vigência;
- período de renovação;
- situação da renovação.

A proximidade do vencimento deverá aparecer nos dashboards:

- do voluntário;
- do Pastor Local;
- do Pastor de Equipe;
- do Coordenador.

---

# 28. Manifestação de Interesse

Antes da renovação, o voluntário deverá informar individualmente se deseja continuar em cada equipe.

Exemplo:

```text
RENOVAÇÃO 2027

Recepção
Deseja continuar?
[ SIM ] [ NÃO ]

Cozinha
Deseja continuar?
[ SIM ] [ NÃO ]

Segurança
Deseja continuar?
[ SIM ] [ NÃO ]
```

Isso permitirá permanecer em algumas equipes e sair de outras.

---

# 29. Renovação Anual

Para cada equipe em que o voluntário desejar permanecer:

```text
VOLUNTÁRIO
     │
     │ manifesta interesse
     ▼
PASTOR LOCAL ATUAL
     │
     ▼
PASTOR DA EQUIPE ATUAL
     │
     ▼
COORDENADOR
     │
     ▼
RENOVADA
```

As equipes poderão ser analisadas simultaneamente.

O sistema deverá distinguir:

- aprovação inicial;
- renovação 2027;
- renovação 2028;
- renovações posteriores.

Renovações não deverão sobrescrever ciclos anteriores.

---

# 30. Dashboard de Renovação

## Voluntário

Deverá visualizar:

- validade atual;
- proximidade do vencimento;
- manifestação pendente;
- equipes atuais;
- situação da renovação.

## Pastor Local

Deverá visualizar, para todas as suas igrejas:

- renovações pendentes;
- voluntários sem manifestação;
- próximos do vencimento;
- expirados.

## Pastor de Equipe

Deverá visualizar, para todas as suas equipes:

- participantes próximos do vencimento;
- manifestações;
- renovações pendentes;
- não renovações;
- expirados.

## Coordenador

Deverá possuir visão global do Maanaim.

---

# 31. Gestão dos Vínculos Pastor ↔ Igreja

O Administrador deverá poder:

- atribuir igreja a pastor;
- atribuir várias igrejas ao mesmo pastor;
- consultar responsável atual;
- substituir responsável;
- encerrar vínculo;
- consultar histórico.

Cada igreja deverá possuir somente **um Pastor Local vigente**.

---

# 32. Troca do Pastor Local

Quando ocorrer substituição:

```text
Igreja A

Pr. José
até 30/09/2026
        │
        ▼
Pr. Antônio
a partir de 01/10/2026
```

o sistema deverá:

1. encerrar o vínculo anterior;
2. criar o novo vínculo;
3. preservar o histórico;
4. transferir as pendências não decididas;
5. manter decisões anteriores vinculadas ao antigo responsável;
6. registrar a operação na auditoria.

A troca de uma igreja não deverá afetar outras igrejas sob responsabilidade do mesmo pastor.

---

# 33. Gestão dos Vínculos Pastor ↔ Equipe

O Administrador deverá poder:

- atribuir equipe;
- atribuir várias equipes ao mesmo pastor;
- substituir responsável;
- consultar responsável atual;
- encerrar vínculo;
- consultar histórico.

Pendências não decididas deverão acompanhar o responsável atual.

Decisões já tomadas permanecerão associadas ao responsável original.

---

# 34. Autorização Contextual

Possuir apenas o perfil não será suficiente.

Para aprovação local:

```text
Usuário autenticado
        ↓
É Pastor Local?
        ↓
Possui vínculo ATIVO com a igreja?
        ↓
A ficha pertence à igreja?
        ↓
A ficha está no estado correto?
        ↓
AÇÃO AUTORIZADA
```

Para equipe:

```text
Usuário autenticado
        ↓
É Pastor de Equipe?
        ↓
Possui vínculo ATIVO com a equipe?
        ↓
A participação pertence à equipe?
        ↓
Está aguardando decisão?
        ↓
AÇÃO AUTORIZADA
```

---

# 35. Auditoria

Todas as operações relevantes deverão produzir eventos de auditoria.

Incluindo:

- criação de conta;
- criação de ficha;
- alterações relevantes;
- aceite de termo;
- envio;
- aprovação;
- rejeição;
- assinatura;
- ativação;
- solicitação de nova equipe;
- cancelamento;
- reativação;
- manifestação anual;
- renovação;
- mudança de Pastor Local;
- mudança de Pastor de Equipe;
- alterações administrativas;
- geração de documentos.

Cada evento deverá registrar, quando aplicável:

```text
usuarioId
perfil
acao
entidade
entidadeId
timestamp
estadoAnterior
estadoPosterior
justificativa
metadados
```

Os registros deverão possuir proteção especial contra alteração e exclusão.

---

# 36. PDF da Ficha

Usuários autorizados poderão gerar PDF.

O documento deverá apresentar:

- número da ficha;
- identificação do voluntário;
- igreja;
- equipes;
- vigência;
- termo;
- versão do termo;
- aprovação do Pastor Local;
- aprovações das equipes;
- aprovação do Coordenador;
- assinaturas;
- datas e horários;
- situação.

Formato das assinaturas:

**Assinado eletronicamente por [nome] em [data] às [hora].**

Poderão futuramente ser adicionados:

- hash;
- QR Code;
- código de validação;
- página pública de autenticidade.

---

# 37. Relatórios

O sistema deverá oferecer relatório por equipe com:

- em aberto;
- ativa;
- inativa.

Também deverá permitir:

- aguardando aprovação;
- renovação pendente;
- próxima do vencimento;
- expirada;
- cancelada;
- rejeitada.

Filtros:

- equipe;
- igreja;
- situação;
- período;
- Pastor;
- voluntário;
- ano de vigência.

Deverá ser prevista exportação futura para:

- PDF;
- planilha.

---

# 38. Arquitetura Tecnológica

## Frontend

- Flutter;
- Dart;
- Flutter Web;
- PWA.

## Backend / Plataforma

Firebase / Google Cloud.

Serviços previstos:

- Firebase Authentication;
- Cloud Firestore;
- Cloud Functions;
- Cloud Storage;
- Firebase Cloud Messaging;
- Firebase Hosting;
- Firebase App Check;
- Firebase Emulator Suite.

---

# 39. Princípio de Segurança

O Flutter não será considerado fonte confiável de autorização.

Operações críticas deverão passar pelo backend.

Exemplos:

- enviar ficha;
- aprovar;
- rejeitar;
- assinar;
- cancelar;
- reativar;
- renovar;
- alterar responsáveis;
- publicar termo;
- alterar permissões.

As Cloud Functions deverão validar:

1. autenticação;
2. papel;
3. vínculo;
4. estado atual;
5. transição solicitada;
6. consistência da operação.

---

# 40. Estrutura Conceitual do Firestore

A modelagem definitiva será definida durante Architecture/Data Model.

Estrutura conceitual:

```text
/users/{uid}

/pastores/{pastorId}

/igrejas/{igrejaId}

/equipes/{equipeId}

/pastorIgrejas/{vinculoId}

/pastorEquipes/{vinculoId}

/voluntarios/{voluntarioId}

/fichas/{fichaId}
    /participacoes/{participacaoId}
    /aprovacoes/{aprovacaoId}
    /renovacoes/{renovacaoId}
    /eventos/{eventoId}

/termos/{termoId}

/auditoria/{eventoId}
```

A estrutura poderá ser desnormalizada durante a arquitetura para otimizar consultas, índices, Security Rules e custos do Firestore.

---

# 41. Cloud Functions Conceituais

Operações previstas:

```text
enviarFicha()

aprovarPastorLocal()
rejeitarPastorLocal()

aprovarEquipe()
rejeitarEquipe()

aprovarCoordenador()
rejeitarCoordenador()

solicitarNovaEquipe()

cancelarParticipacao()
cancelarVoluntariado()

solicitarReativacao()

manifestarInteresseRenovacao()
processarRenovacao()

publicarNovoTermo()
aceitarNovoTermo()

vincularPastorIgreja()
encerrarVinculoPastorIgreja()

vincularPastorEquipe()
encerrarVinculoPastorEquipe()

gerarPdf()
```

Cada operação crítica deverá:

1. autenticar;
2. autorizar;
3. verificar vínculos;
4. validar estado;
5. validar transição;
6. executar a operação consistentemente;
7. registrar evento;
8. registrar auditoria;
9. disparar notificação quando aplicável.

---

# 42. Requisitos Não Funcionais

## Segurança

- autenticação obrigatória;
- autorização por perfil e vínculo;
- princípio do menor privilégio;
- App Check;
- Security Rules;
- operações críticas via Cloud Functions;
- HTTPS;
- proteção dos logs;
- validação das transições.

## Responsividade

Suporte a:

- desktop;
- notebook;
- tablet;
- smartphone.

## PWA

Instalação em dispositivos compatíveis.

## Performance

Utilizar paginação, índices e consultas adequadas ao Firestore.

## Disponibilidade

Utilizar serviços gerenciados Firebase/Google Cloud.

## Desenvolvimento

Utilizar Firebase Emulator Suite para desenvolvimento e testes quando aplicável.

---

# 43. Privacidade e Proteção de Dados

O sistema manipulará informações pessoais e deverá considerar privacidade desde sua concepção.

Deverão ser tratados:

- minimização de dados;
- controle de acesso;
- rastreabilidade;
- retenção;
- backup;
- segurança dos PDFs;
- exportações;
- anonimização/exclusão quando aplicável;
- auditoria;
- exposição de dados em relatórios;
- conteúdo das notificações.

---

# 44. Equipes Iniciais do Maanaim

As seguintes equipes deverão compor a carga inicial:

| Equipe | Responsável inicial |
|---|---|
| Apoio | Claudio Jose da Silva |
| Cantina | Mauro Azevedo Inacio |
| Comunicação | Luando dos Santos Lucindo |
| Cozinha | Wellington Guilherme da Silva |
| Grupo de Louvor | Luando dos Santos Lucindo |
| Hospedagem | Robson Tertuliano da Silva |
| Libras | Hiltofrans Assis de Oliveira |
| Limpeza | Gilson Soares da Câmara |
| Livraria | Luiz Henrique Cirilo da Silva |
| Manutenção | Valdécio Fernandes de Lima |
| Professores UEF | Claudio Jose da Silva |
| Saúde | José Almir Lima de Sousa |
| Secretaria | Mauro Azevedo Inacio |
| Segurança | José Altemir da Silva França |

Esses dados constituem **configuração inicial**, não constantes da aplicação.

Equipes deverão ser administráveis.

---

# 45. Múltiplas Equipes por Pastor

A carga inicial já demonstra múltiplos vínculos:

### Claudio Jose da Silva

- Apoio;
- Professores UEF.

### Luando dos Santos Lucindo

- Comunicação;
- Grupo de Louvor.

### Mauro Azevedo Inacio

- Cantina;
- Secretaria.

Portanto:

```text
PASTOR
   │
   └── 0..N EQUIPES
```

O dashboard deverá consolidar todas as equipes do pastor e permitir filtro por equipe.

---

# 46. Cadastro Inicial de Igrejas

O sistema deverá possuir cadastro dinâmico de igrejas.

A carga inicial será:

| Nome | Código |
|---|---:|
| Acari | 240023 |
| Alecrim | 240012 |
| Alvorada - Jose Luiz da Silva | 240032 |
| Caico | 240038 |
| Ceará - Mirim | 240028 |
| Cidade das Rosas | 240042 |
| Extremoz | 240041 |
| Goianinha | 240008 |
| Igapó | 240001 |
| Lagoa D Anta | 240033 |
| Macau | 240005 |
| Mirassol | 240003 |
| Monte Alegre | 240022 |
| Montanhas | 240019 |
| Mossoró | 240006 |
| Nova Cruz | 240018 |
| Nova Parnamirim | 240013 |
| Pajuçara | 240004 |
| Parnamirim | 240015 |
| Planalto | 240017 |
| Ponta Negra | 240029 |
| Santa Tereza | 240027 |
| Santarém | 240002 |
| São José de Mipibú | 240025 |
| Uruaçu | 240034 |

Total inicial: **25 igrejas**.

---

# 47. Apresentação e Seleção de Igrejas

Seletores deverão utilizar:

```text
Nome - Código
```

Exemplo:

```text
Goianinha - 240008
```

As opções deverão ser ordenadas alfabeticamente pelo nome.

A pesquisa deverá aceitar:

- nome;
- código.

Exemplo:

```text
[ Goi____________ ]

Goianinha - 240008
```

ou:

```text
[ 240008_________ ]

Goianinha - 240008
```

---

# 48. Administração das Igrejas

O Administrador poderá:

- cadastrar;
- editar;
- ativar;
- inativar;
- consultar Pastor vigente;
- atribuir Pastor;
- substituir Pastor;
- consultar histórico de responsáveis.

Igrejas com histórico não deverão ser excluídas fisicamente.

---

# 49. Seleção de Igrejas pelo Administrador

Ao editar um pastor, o Administrador poderá selecionar uma ou várias igrejas.

Exemplo:

```text
PASTOR
Pr. José da Silva

Igrejas:

☑ Goianinha - 240008
☑ Nova Cruz - 240018
☐ Montanhas - 240019
☐ Parnamirim - 240015

[ Salvar ]
```

Se uma igreja já possuir responsável:

```text
Goianinha - 240008

Pastor Local atual:
Pr. João da Silva

Deseja substituir o responsável?
```

A confirmação deverá:

1. encerrar o vínculo anterior;
2. criar o novo;
3. registrar data/hora;
4. registrar quem realizou a alteração;
5. preservar histórico;
6. direcionar pendências ao novo responsável.

---

# 50. Seed Inicial

As igrejas e equipes deverão ser tratadas como **dataset inicial**.

Não deverão ser:

- enums;
- constantes Dart;
- listas hardcoded no Flutter.

Fluxo:

```text
Firestore
   │
   ├── igrejas
   └── equipes
        │
        ▼
Repository
        │
        ▼
Application
        │
        ▼
Flutter
```

A implantação deverá prever seed dos registros iniciais.

---

# 51. Identificação da Igreja

Estrutura mínima:

```text
id
codigo
nome
ativa
createdAt
updatedAt
```

Exemplo:

```text
codigo: "240008"
nome: "Goianinha"
ativa: true
```

O código deverá ser armazenado como **String**.

O ID interno do Firestore não deverá depender do nome.

---

# 52. Regras de Negócio Consolidadas

**RN-001 — Múltiplas equipes**  
A rejeição de uma equipe não impede a continuidade das equipes aprovadas.

**RN-002 — Aprovações simultâneas**  
Pastores de equipes poderão realizar suas análises simultaneamente.

**RN-003 — Cancelamento**  
Pastor Local e Coordenador poderão cancelar participação específica ou todo o voluntariado conforme contexto e permissão.

**RN-004 — Reativação**  
Voluntário cancelado ou inativo poderá ser reativado sem perda de histórico.

**RN-005 — Alterações cadastrais**  
Alterações posteriores não invalidarão automaticamente aprovações existentes.

**RN-006 — Nova equipe**  
Voluntário ativo poderá solicitar nova equipe sem criar nova ficha.

**RN-007 — Troca de responsável**  
Pendências deverão acompanhar o responsável atual. Decisões anteriores permanecerão vinculadas a quem as realizou.

**RN-008 — Validade**  
A ficha possuirá validade anual.

**RN-009 — Manifestação anual**  
O voluntário deverá manifestar interesse individualmente em permanecer em cada equipe.

**RN-010 — Renovação**  
Equipes mantidas deverão passar novamente pelo fluxo de aprovação.

**RN-011 — Novo termo**  
Nova versão do termo exigirá novo aceite dos voluntários ativos.

**RN-012 — Assinatura**  
As assinaturas serão aceites eletrônicos autenticados contendo identidade, função, decisão, data e hora.

**RN-013 — PDF**  
O PDF apresentará as assinaturas com a indicação "Assinado eletronicamente", nome, função, data e hora.

**RN-014 — Histórico**  
Renovações, reativações, rejeições e cancelamentos não poderão apagar eventos anteriores.

**RN-015 — Múltiplas igrejas por Pastor**  
Um Pastor Local poderá ser responsável por uma ou várias igrejas simultaneamente.

**RN-016 — Múltiplas equipes por Pastor**  
Um pastor poderá ser responsável por uma ou várias equipes simultaneamente.

**RN-017 — Acúmulo de responsabilidades**  
Um pastor poderá possuir simultaneamente vínculos com igrejas e equipes.

**RN-018 — Independência dos vínculos**  
Alterar um vínculo não deverá modificar os demais vínculos do pastor.

**RN-019 — Vigência dos vínculos**  
Vínculos Pastor ↔ Igreja e Pastor ↔ Equipe deverão possuir vigência e histórico.

**RN-020 — Autorização contextual**  
Perfil sozinho não concede autoridade. O backend deverá validar o vínculo ativo correspondente.

**RN-021 — Cadastro dinâmico de equipes**  
Equipes e responsáveis serão administráveis. A lista inicial é apenas seed.

**RN-022 — Responsável atual da equipe**  
Novas solicitações e pendências não decididas deverão ser direcionadas ao responsável vigente.

**RN-023 — Histórico de responsabilidade da equipe**  
O sistema deverá preservar os períodos de responsabilidade dos Pastores de Equipe.

**RN-024 — Pastor Local vigente por igreja**  
Cada igreja deverá possuir apenas um Pastor Local vigente por vez. Um pastor poderá responder por várias igrejas.

**RN-025 — Unicidade do responsável**  
O sistema não deverá permitir dois vínculos Pastor ↔ Igreja simultaneamente vigentes para a mesma igreja.

**RN-026 — Cadastro dinâmico de igrejas**  
As igrejas serão registros administráveis no Firestore.

**RN-027 — Código da igreja**  
Cada igreja deverá possuir código identificador e o sistema deverá impedir duplicidade de códigos.

**RN-028 — Ordenação das igrejas**  
Seletores deverão ordenar igrejas alfabeticamente pelo nome.

**RN-029 — Apresentação da igreja**  
O padrão de apresentação será "Nome - Código".

**RN-030 — Pesquisa de igreja**  
Seletores deverão permitir pesquisa por nome ou código.

**RN-031 — Inativação de igreja**  
Igrejas com histórico deverão ser inativadas em vez de excluídas fisicamente.

**RN-032 — Atribuição administrativa**  
Atribuição e substituição de Pastor Local serão operações administrativas auditáveis.

**RN-033 — Substituição do responsável**  
A substituição deverá encerrar o vínculo anterior e iniciar o novo sem período simultâneo de responsabilidade.

**RN-034 — Pendências após substituição**  
Pendências não decididas deverão ficar disponíveis automaticamente para o novo Pastor Local.

---

# 53. Critérios de Sucesso

O sistema será considerado funcional quando permitir:

1. autenticação;
2. cadastro do voluntário;
3. seleção de múltiplas equipes;
4. aceite do termo;
5. identificação automática do Pastor Local;
6. aprovação do Pastor Local;
7. aprovações simultâneas das equipes;
8. rejeição independente por equipe;
9. continuidade das equipes aprovadas;
10. aprovação final;
11. confirmação da consulta na reunião de pastores;
12. assinaturas eletrônicas;
13. ativação;
14. inclusão posterior de equipe;
15. cancelamento parcial;
16. cancelamento total;
17. reativação;
18. validade anual;
19. manifestação anual;
20. renovação;
21. nova aprovação na renovação;
22. novo aceite de termo;
23. Pastor responsável por várias igrejas;
24. Pastor responsável por várias equipes;
25. troca de responsáveis;
26. transferência automática de pendências;
27. preservação de decisões anteriores;
28. gestão administrativa das 25 igrejas iniciais;
29. gestão administrativa das 14 equipes iniciais;
30. geração de PDF;
31. relatórios;
32. auditoria completa.

---

# 54. Fora do Escopo Inicial / Evoluções

Poderão ser implementados posteriormente:

- WhatsApp;
- QR Code público;
- validação pública de ficha;
- dashboards analíticos avançados;
- certificado digital;
- provedor externo de assinatura;
- importação massiva;
- relatórios avançados;
- outras automações.

---

# 55. Diretriz para BMAD

Este PRD deverá ser tratado como **fonte de verdade funcional** para as próximas fases.

Sequência:

```text
PRD v1.1
   │
   ▼
UX / USER JOURNEYS
   │
   ▼
ARCHITECTURE
   │
   ├── Firestore Data Model
   ├── Security Model
   ├── Cloud Functions
   ├── Audit Model
   └── State Machines
   │
   ▼
EPICS
   │
   ▼
STORIES
   │
   ▼
READINESS CHECK
   │
   ▼
IMPLEMENTAÇÃO
```

O agente de implementação não deverá inventar regras de negócio.

Quando uma história depender de comportamento não definido neste PRD ou nos artefatos derivados, a questão deverá retornar para refinamento antes da implementação.

---

# 56. Diretrizes para Architecture

A fase de arquitetura deverá tratar explicitamente:

1. relação 1:N Pastor → Igrejas;
2. unicidade do Pastor Local vigente por igreja;
3. relação N:N Pastor ↔ Equipes;
4. autorização baseada em vínculo;
5. ficha permanente;
6. participações independentes;
7. ciclos anuais;
8. renovações;
9. histórico de responsáveis;
10. snapshots das assinaturas;
11. versionamento de termos;
12. máquina de estados;
13. auditoria imutável;
14. Firebase Security Rules;
15. Firebase App Check;
16. Cloud Functions;
17. transações Firestore;
18. índices;
19. desnormalização quando necessária;
20. consultas dos dashboards;
21. geração de PDF;
22. estratégia de seed;
23. tratamento de concorrência na troca de responsáveis;
24. estratégia de notificações.

---

# 57. Princípios do Produto

1. Nenhuma decisão importante sem rastreabilidade.
2. Nenhum cancelamento elimina histórico.
3. Cada equipe possui ciclo independente.
4. A ficha representa o histórico permanente do voluntário.
5. Participações possuem ciclos próprios.
6. Um pastor pode responder por múltiplas igrejas.
7. Uma igreja possui somente um Pastor Local vigente.
8. Um pastor pode responder por múltiplas equipes.
9. Permissões dependem de perfil e vínculo ativo.
10. Mudanças de responsáveis não alteram decisões passadas.
11. Pendências acompanham o responsável vigente.
12. Operações críticas são validadas no backend.
13. O Flutter não é fonte confiável de autorização.
14. Termos são versionados.
15. Assinaturas representam eventos reais do backend.
16. Renovações criam novos ciclos sem sobrescrever os anteriores.
17. Igrejas e equipes são dados administráveis.
18. Dados iniciais não deverão ser hardcoded.
19. Auditoria deverá ser concebida desde o início.
20. Regras não definidas não deverão ser inventadas durante a implementação.

---

# 58. Estado do Documento

Este documento constitui o **PRD v1.1 consolidado** do Sistema de Gestão de Voluntários do Maanaim.

As principais regras de negócio necessárias para avançar para UX e Architecture estão definidas.

O próximo estágio recomendado do BMAD é:

**UX / User Journeys → Architecture → Epics & Stories.**

Não iniciar a implementação das funcionalidades de negócio antes da definição da arquitetura, modelo de dados, modelo de segurança e máquinas de estados derivados deste PRD.
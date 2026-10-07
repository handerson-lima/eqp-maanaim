# Especificação Técnica — Story 6.3: Gerar e Entregar PDF Privado da Ficha (AD-6, AD-12, AD-13)

## 1. Visão Geral e Contexto de Domínio
A **Story 6.3** implementa a capacidade de projetar, assinar digitalmente e entregar com segurança o **Termo de Adesão de Voluntário** individual em formato PDF privado para cada participação aprovada/ativa de um ciclo de voluntariado concluído.

### Invariantes Vinculantes (AD-6, AD-12, AD-13):
1. **Geração Exclusiva no Servidor a partir de Evidências Persistidas (AD-6, AD-13):**
   - O PDF é construído exclusivamente no Cloud Functions utilizando dados dos agregados canônicos persistidos (`fichas`, `participacoes`, `ciclos`, `pessoas`, `igrejas`, `equipes` e `aceitesTermo`).
   - É **estritamente proibida** qualquer aceitação de assinaturas, textos, status ou dados cadastrais vindos da requisição do cliente.
   - Cada termo em PDF é **individual por equipe**: não existe termo consolidado multi-equipe.
2. **Estrutura Canônica Fiel ao Modelo Institucional (AD-13):**
   - Conformidade estrita com a Lei Federal nº 9.608/1998 e o padrão oficial da Igreja Cristã Maranata / Maanaim do Rio Grande do Norte.
   - Preenchimento compulsório de:
     * Identificação do voluntário: Nome Completo, Nacionalidade, Profissão e CPF (obtidos da ficha persistida).
     * Instituição celebrante: Igreja Cristã Maranata (CNPJ 27.056.910/0001-42).
     * Administrador Voluntário / Coordenador Geral: Nome Completo e CPF recuperados dos registros canônicos de `pessoas` / `autoridadesAdministrativas`.
     * Equipe de voluntariado: Nome oficial da equipe do catálogo.
     * Local e Data: Formatação por extenso (ex: "Natal – RN, 15 de outubro de 2026").
     * Assinaturas e Testemunhas com carimbos probatórios: Voluntário (com hash SHA-256 e data/hora do aceite), Coordenador do Maanaim (com dados e confirmação da reunião de pastores), Testemunha 1 (Pastor da Igreja Local) e Testemunha 2 (Pastor/Responsável pela Equipe).
     * Rodapé de integridade com identificador único e aviso de retenção legal por 5 anos (AD-12).
3. **Armazenamento Privado e Entrega Segura (AD-12):**
   - Armazenado em bucket privado sob caminho `pdfs/:fichaId/:participacaoId.pdf`.
   - Bloqueio irrestrito em Storage Rules (`allow read, write: if false;` para clientes diretos).
   - Entrega via Cloud Function autenticada gerando Signed URL com expiração curta de 15 minutos (900s).
   - Registro de auditoria probatória em `auditOutbox`: eventos `GERAR_PDF_TERMO` e `ACESSAR_PDF_TERMO`.
4. **Experiência do Usuário (Sally UX Mobile-First & WCAG 2.2 AA):**
   - Voluntário: Ação clara "Baixar Termo em PDF" na lista de participações ativas da `MinhaFichaScreen`.
   - Gestores/Pastores: Ação de visualização e download na `ConsultaFichaAutorizadaScreen`.
   - Feedback em tempo real com indicador de carregamento durante a geração sob demanda e tratamento de erros resiliente.
   - Alvos de toque $\ge 44$ px, alto contraste e suporte a leitores de tela.

---

## 2. Contratos de API (Cloud Functions v2)

### 2.1 `gerarPdfParticipacao`
Gera o arquivo PDF institucional para uma participação específica de uma ficha a partir das evidências gravadas no Firestore, armazena no bucket do Storage e retorna a URL assinada de curta duração.
- **Entrada:**
  ```json
  {
    "commandId": "cmd-gerar-pdf-...",
    "fichaId": "ficha-uid-123",
    "participacaoId": "part-456",
    "correlationId": "corr-..."
  }
  ```
- **Saída:**
  ```json
  {
    "sucesso": true,
    "caminhoStorage": "pdfs/ficha-uid-123/part-456.pdf",
    "urlDownload": "https://storage.googleapis.com/...signed...",
    "expiraEm": "2026-10-07T19:45:00.000Z",
    "nomeArquivo": "Termo_Voluntariado_Equipe_Som.pdf",
    "jaExistia": false
  }
  ```

### 2.2 `obterUrlDownloadPdf`
Gera uma nova Signed URL de curta duração para download do termo previamente gerado (ou dispara a geração se ainda não existir).
- **Entrada:**
  ```json
  {
    "fichaId": "ficha-uid-123",
    "participacaoId": "part-456",
    "correlationId": "corr-..."
  }
  ```
- **Saída:**
  ```json
  {
    "urlDownload": "https://storage.googleapis.com/...signed...",
    "expiraEm": "2026-10-07T19:45:00.000Z",
    "nomeArquivo": "Termo_Voluntariado_Equipe_Som.pdf"
  }
  ```

---

## 3. Matriz de Autorização e Escopo
| Papel | Condição de Acesso | Ação Permitida |
|---|---|---|
| **VOLUNTÁRIO** | `fichaId == uid` (proprietário da ficha) | Gerar e baixar PDF de suas próprias participações ativas/concluídas |
| **PASTOR_LOCAL** | Vínculo vigente com a `igrejaId` da ficha | Gerar e baixar PDF de voluntários da sua igreja local |
| **RESPONSAVEL_EQUIPE** | Responsável vigente da `equipeId` da participação | Gerar e baixar PDF de voluntários da sua equipe |
| **COORDENADOR_GERAL** | Autoridade administrativa vigente de Coordenador | Gerar e baixar PDF de qualquer participação aprovada |
| **ADMINISTRADOR** | Autoridade administrativa vigente de Administrador | Gerar e baixar PDF de qualquer participação aprovada |
| *Outros / Sem vínculo* | Nenhuma correspondência de escopo | Acesso negado com `AcessoNaoAutorizadoError` (`permission-denied`) sem vazar dados |

---

## 4. Plano de Implementação
1. **Domínio e Projeção PDF (`functions/src/domain/pdfTermo.ts`):**
   - Interface de dados do termo (`DadosTermoPdf`).
   - Motor de renderização institucional em `pdf-lib` (fontes padrão Helvetica/HelveticaBold, quebra de texto, cabeçalho, corpo jurídico, tabela de assinaturas/testemunhas, rodapé com metadados e hash).
   - Validador de dados e agregados.
2. **Repositório e Storage (`functions/src/repositories/pdfTermo.ts`):**
   - Leitura transacional e composição dos dados persistidos (ficha, participação, termo, pastor local, pastor equipe, coordenador geral).
   - Verificação de escopo e autorização do solicitante.
   - Upload de bytes no bucket privado (`firebase-admin/storage`).
   - Geração de Signed URL com TTL de 15 minutos.
   - Registro em `auditOutbox` (`GERAR_PDF_TERMO`, `ACESSAR_PDF_TERMO`).
3. **Endpoints / Callables (`functions/src/commands/`):**
   - `gerarPdfParticipacao.ts` e `obterUrlDownloadPdf.ts`.
   - Exportação em `functions/src/index.ts`.
4. **Frontend Flutter (`flutter_app/`):**
   - Gateway e serviço: `PdfTermoService` / `FirebasePdfTermoGateway` / `MemoriaPdfTermoGateway`.
   - Botão de download de alta acessibilidade em cada participação ativa na `MinhaFichaScreen`.
   - Botão de download na `ConsultaFichaAutorizadaScreen` para pastores e coordenadores.
   - Disparo de download seguro / abertura de URL privada compatível com PWA/Web e mobile.
5. **Testes Automatizados (Vitest + Flutter Test):**
   - Vitest: geração correta do PDF, integridade das evidências projetadas, rejeição de injeção client-side, validação de escopo e emissão de auditoria.
   - Flutter: renderização dos botões, fluxo de chamada do gateway, feedbacks de carregamento e estados de erro.

# Especificação Técnica: Edição de Perfil do Usuário

**Épico:** Gestão de Pessoas e Identidade  
**História:** Edição de Perfil do Usuário (E-mail, Foto e Telefone)  
**Status:** Ready for Dev  
**Data:** 08/10/2026  
**Autores:** John (PM), Sally (UX), Winston (Arquiteto), Amelia (Dev), Mary (BA)

---

## 1. Contexto e Objetivos (John & Mary)

O usuário autenticado (voluntário, pastor, responsável de equipe ou coordenador) necessita gerenciar suas informações básicas de contato e identidade no Maanaim:
1. **Foto de Perfil:** Permitir upload de fotografia recente para identificação visual nas escalas, crachás digitais e triagem operacional no Maanaim por líderes e pastores autorizados.
2. **Telefone:** Manter o número de telefone de contato/WhatsApp atualizado com máscara padrão brasileira `(XX) XXXXX-XXXX`.
3. **E-mail:** Permitir a atualização do e-mail de acesso via Firebase Auth com o fluxo seguro de **verificação prévia por e-mail** (`verifyBeforeUpdateEmail`), garantindo que o voluntário não perca o acesso por erro de digitação.

---

## 2. Decisões Vinculantes de Arquitetura (Winston)

1. **Storage Rules para Avatares (`storage.rules`):**
   * Caminho canônico: `avatars/{uid}/{filename}`.
   * Leitura: permitida para usuários autenticados (`request.auth != null`), viabilizando a exibição para a liderança nas escalas e consultas de voluntários.
   * Escrita: permitida exclusivamente para o próprio usuário (`request.auth.uid == uid`), com restrições rígidas:
     * `request.resource.size <= 2 * 1024 * 1024` (máximo 2 MB).
     * `request.resource.contentType.matches('image/(jpeg|png|webp)')`.
2. **Fluxo de Atualização de E-mail (Firebase Auth):**
   * Usa `user.verifyBeforeUpdateEmail(novoEmail)`.
   * Se o Firebase exigir reautenticação (`requires-recent-login`), a UI apresenta um modal seguro solicitando a senha atual antes de reenviar.
   * O e-mail permanece o antigo no sistema até que o usuário clique no link de confirmação enviado para a nova caixa postal. A UI deve exibir um aviso claro informando o status pendente.
3. **Telefone e Metadados no Firestore:**
   * O telefone é gravado no documento do usuário (`users/{uid}` ou `fichas/{uid}`) usando a normalização já estabelecida no backend.
   * Disparo de evento de auditoria append-only (`ALTERACAO_PERFIL`) via Cloud Function ou transação autorizada, sem vazamento de PII nos logs abertos.

---

## 3. Especificação de UI/UX (Sally)

### 3.1. Princípios e Design System
* **Mobile-First:** Layout em coluna única no celular (largura máxima de 480px em telas maiores para foco de formulário).
* **Paleta Canônica:**
  * Background: `cinza-50` / `azul muito claro`.
  * Elementos principais / TopBar: `navy-900` (`#0C2940`).
  * Ações primárias: `blue-600` (`#1565C0` / `#0D47A1`).
  * Alvos de toque (Touch Targets): mínimo de 48x48 px.
* **Componentes:**
  * **Header:** Título "Editar Perfil" com botão voltar para a tela anterior.
  * **Avatar Interativo:** Círculo de 100px centralizado com imagem atual ou fallback de iniciais sobre fundo `navy-900`. Badge circular no canto inferior direito com ícone de câmera `Icons.camera_alt` e fundo `blue-600`.
  * **Campo Nome Completo:** Exibido em modo somente leitura (edição de nome é restrita a administradores por regras da ficha cadastral).
  * **Campo E-mail:** `TextFormField` com validação de formato e indicação de e-mail atual.
  * **Campo Telefone:** `TextFormField` com máscara formatadora automática `(XX) XXXXX-XXXX` e teclado numérico `TextInputType.phone`.
  * **Feedback de E-mail Pendente:** Banner/Card informativo com borda âmbar e ícone de aviso quando houver troca de e-mail aguardando confirmação no inbox.
  * **Botão Salvar:** `ElevatedButton` primário de 48px de altura com estado de carregamento (`CircularProgressIndicator`).

---

## 4. Estrutura Técnica de Código (Amelia)

### 4.1. Arquivos Criados / Modificados
1. `storage.rules`:
   * Adicionar regra para pasta `avatars/{uid}/{allPaths=**}` com checagem de tamanho, mime type e autorização de `uid`.
2. `flutter_app/lib/features/perfil/editar_perfil_screen.dart`:
   * Tela principal de edição do perfil com gerenciamento de estado assíncrono.
3. `flutter_app/lib/features/perfil/avatar_picker_widget.dart`:
   * Componente reutilizável com `image_picker` web-friendly (`pickImage(source: ImageSource.gallery)` e `readAsBytes()`).
4. `flutter_app/lib/features/perfil/perfil_service.dart`:
   * Serviço para:
     * Upload de bytes no Firebase Storage (`FirebaseStorage.instance.ref('avatars/$uid/...').putData(...)`).
     * Atualização de `photoURL` no Firebase Auth e Firestore.
     * Atualização de telefone no Firestore.
     * Chamada de `verifyBeforeUpdateEmail(novoEmail)`.
5. `flutter_app/lib/main.dart` / Rotas:
   * Registrar rota `/perfil/editar` e atalho no menu de navegação do AppShell.

---

## 5. Critérios de Aceite (Gherkin - Mary)

### Cenário 1: Upload de foto com sucesso
* **Given** um usuário autenticado na tela de edição de perfil
* **When** ele seleciona uma imagem JPEG/PNG válida menor que 2MB
* **Then** o sistema exibe preview imediato
* **And** ao clicar em "Salvar", faz o upload para `avatars/{uid}/` e atualiza a foto do perfil.

### Cenário 2: Validação de arquivo excessivo
* **Given** um usuário selecionando uma imagem
* **When** o arquivo ultrapassar 2MB
* **Then** o sistema recusa a seleção antes do upload e exibe aviso claro: "A imagem deve ter no máximo 2MB".

### Cenário 3: Alteração de telefone com máscara
* **Given** um usuário editando o telefone
* **When** ele digita os dígitos `11987654321`
* **Then** o campo formata automaticamente como `(11) 98765-4321`
* **And** ao salvar, persiste o telefone atualizado.

### Cenário 4: Alteração de e-mail com link de confirmação
* **Given** um usuário alterando o endereço de e-mail
* **When** ele informa um e-mail válido diferente do atual e confirma
* **Then** o Firebase dispara `verifyBeforeUpdateEmail`
* **And** a tela exibe mensagem informativa orientando a verificar o link enviado para a nova caixa postal.

### Cenário 5: Tratamento de reautenticação necessária
* **Given** um usuário cuja sessão de login é antiga
* **When** o sistema lança `requires-recent-login` ao tentar atualizar o e-mail
* **Then** o sistema solicita a senha atual para reautenticação e repete a operação sem perder os dados preenchidos.

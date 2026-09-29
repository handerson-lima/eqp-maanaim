# Fluxo e critérios de aceitação — autenticação pública

## Limites de dados e segurança

| Área | Regra vinculante |
|---|---|
| Identidade | Firebase Auth é a fonte de identidade e mantém a credencial de e-mail/senha. E-mail não é ID de documento de domínio. |
| Ficha | Após autenticar, o cliente chama uma Cloud Function autenticada para criar/retomar somente o rascunho privado do próprio UID; o comando valida App Check e contrato. |
| Autorização | Papel, vínculo e escopo são fontes separadas e não derivam de criar conta, recuperar senha ou escolher igreja/equipe. |
| Dados administráveis | Igreja e equipe são consultadas de projeções permitidas; o cliente não inclui catálogo constante. |
| Privacidade | Não persistir ou transmitir PII além do necessário; redigir falhas e telemetria. Não auditar senha, token, e-mail ou conteúdo da ficha. |
| Recuperação | Usar o mecanismo de redefinição de senha do Firebase Auth com URL de continuação permitida. A interface confirma de forma neutra para evitar enumeração. |

## Jornada de cadastro

1. A tela inicial expõe o botão **Cadastre-se** com alvo de toque mínimo e rótulo acessível.
2. O formulário coleta e valida e-mail, senha e os campos obrigatórios de ficha; a igreja é selecionada de dados administráveis. A seleção de equipes respeita o contrato da ficha e não é uma lista local.
3. Ao confirmar, o cliente cria a conta e-mail/senha no Firebase Auth. Não grava ficha, papel, vínculo ou escopo diretamente no Firestore.
4. Com sessão criada, o cliente chama a função autenticada de rascunho. A função grava apenas o agregado permitido e retorna estado seguro; falhas permitem retentativa sem duplicar o rascunho.
5. A tela anuncia sucesso, próxima ação e erros por campo sem exibir dados sensíveis. A conta não equivale a aprovação nem ativa participação.

## Jornada de recuperação

1. A tela de login oferece **Esqueci minha senha** com foco e rótulo acessíveis.
2. Usuário informa e-mail; o cliente solicita a redefinição por Firebase Auth sem registrar o valor.
3. A interface informa que, se houver uma conta elegível, as instruções foram enviadas. Para conta existente, Firebase Auth entrega link seguro de definição de nova senha.
4. Após concluir a senha, o usuário retorna ao login. Nenhum papel, vínculo, escopo, auditoria de domínio ou notificação de domínio é modificado.

## Critérios de aceitação

- **Dado** um visitante sem sessão **quando** abre a tela inicial **então** encontra “Cadastre-se”, alcançável por teclado e com alvo de pelo menos 44 px.
- **Dado** campos obrigatórios válidos **quando** visitante conclui o cadastro **então** Firebase Auth cria a identidade e a Cloud Function autenticada cria ou retoma somente seu rascunho privado; **e** nenhum papel, vínculo ou escopo é criado.
- **Dado** um formulário incompleto, senha inválida ou falha segura no serviço **quando** usuário tenta cadastrar **então** recebe orientação acessível e acionável sem expor PII, tokens ou detalhe interno.
- **Dado** um cliente comum **quando** tenta criar ou alterar diretamente ficha, participação, papel, vínculo ou escopo no Firestore **então** as Rules negam a escrita.
- **Dado** um usuário na tela de login **quando** aciona “Esqueci minha senha” e envia e-mail **então** recebe confirmação neutra; **e**, se a conta estiver cadastrada, Firebase Auth envia link seguro de redefinição.
- **Dado** um pastor criado pela carga administrativa **quando** não possui senha definida **então** pode usar a recuperação pela tela de login; **e** a carga não enviou convite automático.
- **Dado** qualquer evento de cadastro ou recuperação **quando** logs, erros, auditoria e notificações são inspecionados **então** não contêm e-mail, senha, token ou conteúdo sensível da ficha.
- **Dado** celular, teclado web e leitor de tela **quando** o fluxo é percorrido **então** ordem de foco, rótulos, mensagens de erro/sucesso e estados são compreensíveis sem depender somente de cor.

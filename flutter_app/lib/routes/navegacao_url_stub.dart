/// Implementação nativa (não-web) da navegação por URL.
///
/// Em testes e builds não-web não há URL de navegador; a rota inicial vem do
/// parâmetro `rotaInicial` e a atualização de URL é um no-op.
String? rotaInicialDoNavegador() => null;

void atualizarRotaNoNavegador(String rota) {}

void registrarMudancaDeRotaNoNavegador(void Function() aoMudar) {}

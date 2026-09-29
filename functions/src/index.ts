import { initializeApp } from 'firebase-admin/app';
initializeApp();
export { criarOuRetomarRascunho } from './commands/criarOuRetomarRascunho.js';
export { alterarAutoridadeAdministrativa } from './commands/gerenciarAutoridadeAdministrativa.js';
export { semearCatalogoInicial } from './commands/semearCatalogoInicial.js';
export { consultarCatalogo } from './commands/consultarCatalogo.js';

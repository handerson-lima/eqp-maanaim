import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';

initializeApp();
setGlobalOptions({
  region: 'us-central1',
  maxInstances: 10,
  cpu: 'gcf_gen1',
  memory: '256MiB',
});
export { criarOuRetomarRascunho } from './commands/criarOuRetomarRascunho.js';
export { alterarAutoridadeAdministrativa } from './commands/gerenciarAutoridadeAdministrativa.js';
export { semearCatalogoInicial } from './commands/semearCatalogoInicial.js';
export { consultarCatalogo } from './commands/consultarCatalogo.js';
export { alternarStatusIgreja } from './commands/alternarStatusIgreja.js';
export { alternarStatusEquipe } from './commands/alternarStatusEquipe.js';
export { salvarPessoa } from './commands/salvarPessoa.js';
export { gerenciarPapeis } from './commands/gerenciarPapeis.js';
export { consultarPessoas } from './commands/consultarPessoas.js';
export { gerenciarVinculo } from './commands/gerenciarVinculo.js';
export { consultarVinculos } from './commands/consultarVinculos.js';
export { publicarTermo } from './commands/publicarTermo.js';
export { consultarTermos } from './commands/consultarTermos.js';
export { obterTermoVigente } from './commands/obterTermoVigente.js';
export { obterMinhaFicha } from './commands/obterMinhaFicha.js';
export { salvarMinhaFicha } from './commands/salvarMinhaFicha.js';
export { obterMinhasParticipacoes } from './commands/obterMinhasParticipacoes.js';
export { salvarParticipacoesRascunho } from './commands/salvarParticipacoesRascunho.js';
export { aceitarTermoVigente } from './commands/aceitarTermoVigente.js';
export { obterHistoricoAceites } from './commands/obterHistoricoAceites.js';
export { enviarFichaAprovacao } from './commands/enviarFichaAprovacao.js';
export { obterFilaPastorLocal } from './commands/obterFilaPastorLocal.js';
export { decidirFichaPastorLocal } from './commands/decidirFichaPastorLocal.js';
export { obterFilaResponsavelEquipe } from './commands/obterFilaResponsavelEquipe.js';
export { decidirParticipacaoResponsavelEquipe } from './commands/decidirParticipacaoResponsavelEquipe.js';
export { obterFilaCoordenador } from './commands/obterFilaCoordenador.js';
export { decidirAtivacaoCoordenador } from './commands/decidirAtivacaoCoordenador.js';
export { obterMinhasNotificacoes } from './commands/obterMinhasNotificacoes.js';
export { obterDetalheSolicitacao } from './commands/obterDetalheSolicitacao.js';
export { notificarEventoAuditOutbox } from './triggers/notificacoes.js';
export { consultarFichaAutorizada } from './commands/consultarFichaAutorizada.js';
export { consultarLinhaDoTempoAutorizada } from './commands/consultarLinhaDoTempoAutorizada.js';
export { solicitarEquipeAdicional } from './commands/solicitarEquipeAdicional.js';
export { cancelarParticipacao } from './commands/cancelarParticipacao.js';
export { cancelarVoluntariado } from './commands/cancelarVoluntariado.js';
export { solicitarReativacao } from './commands/solicitarReativacao.js';
export { expirarCiclosVencidos } from './commands/expirarCiclo.js';
export { expirarCiclosScheduled } from './triggers/expirarCicloScheduled.js';
export { manifestarRenovacao } from './commands/manifestarRenovacao.js';
export { decidirCicloAnualPastor } from './commands/decidirCicloAnualPastor.js';
export { decidirCicloAnualResponsavel } from './commands/decidirCicloAnualResponsavel.js';
export { concluirCicloAnualCoordenador } from './commands/concluirCicloAnualCoordenador.js';
export { obterDashboardRenovacao } from './commands/obterDashboardRenovacao.js';
export { processarAuditOutbox, reconciliarAuditoriaScheduled } from './triggers/auditoria.js';
export { reconciliarAuditoria } from './commands/reconciliarAuditoria.js';
export { consultarAuditoriaAutorizada } from './commands/consultarAuditoriaAutorizada.js';
export { consultarRelatorioOperacional } from './commands/consultarRelatorioOperacional.js';
export { gerarPdfParticipacao } from './commands/gerarPdfParticipacao.js';
export { obterUrlDownloadPdf } from './commands/obterUrlDownloadPdf.js';
export { executarRotinaRetencao } from './commands/executarRotinaRetencao.js';
export { consultarConformidadeRetencao } from './commands/consultarConformidadeRetencao.js';
export { expurgarRascunhosScheduled } from './triggers/expurgarRascunhosScheduled.js';

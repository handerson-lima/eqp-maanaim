import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { executarExpurgoRascunhosAgendado } from './expurgarRascunhosGate.js';

export { semanaIso } from './expurgarRascunhosGate.js';

/**
 * Job agendado semanal de expurgo de rascunhos abandonados (AD-12).
 *
 * O gate e a chave semanal idempotente ficam em `expurgarRascunhosGate.ts`;
 * só executa quando `configuracoes/retencao.expurgoAutomaticoHabilitado === true`.
 */
export const expurgarRascunhosScheduled = onSchedule(
  {
    schedule: 'every week',
    timeZone: 'UTC',
    retryCount: 3,
  },
  async () => {
    const db = getFirestore();
    await executarExpurgoRascunhosAgendado(db, new Date());
  },
);

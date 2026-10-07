import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { executarExpirarCiclosRepo } from '../repositories/expirarCiclo.js';
import { calcularPayloadHashExpirarCiclos } from '../domain/expirarCiclo.js';

/**
 * Job agendado diário que expira participações com vigência vencida (AD-10 / AD-11).
 * Execução idempotente baseada no dia da execução UTC.
 */
export const expirarCiclosScheduled = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'UTC',
    retryCount: 3,
  },
  async () => {
    const db = getFirestore();
    const agora = new Date();
    const dataIso = agora.toISOString().slice(0, 10);
    const commandId = `job_expiracao_${dataIso}`;
    const payloadHash = calcularPayloadHashExpirarCiclos({
      commandId,
      limite: 200,
    });

    await executarExpirarCiclosRepo(db, {
      commandId,
      limite: 200,
      payloadHash,
    });
  },
);

import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { calcularPayloadHashRetencao } from '../domain/retencao.js';
import {
  executarRotinaRetencaoRepo,
  obterConfiguracaoRetencao,
} from '../repositories/retencao.js';

/** Semana ISO (ex.: 2026-W41) para tornar o job semanal idempotente. */
export function semanaIso(data: Date): string {
  const d = new Date(Date.UTC(data.getUTCFullYear(), data.getUTCMonth(), data.getUTCDate()));
  const dia = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dia);
  const inicioAno = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const semana = Math.ceil(((d.getTime() - inicioAno.getTime()) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(semana).padStart(2, '0')}`;
}

/**
 * Job agendado semanal de expurgo de rascunhos abandonados (AD-12).
 *
 * Só executa de fato quando `configuracoes/retencao.expurgoAutomaticoHabilitado === true`
 * (padrão `false`). A chave semanal do comando garante idempotência.
 */
export const expurgarRascunhosScheduled = onSchedule(
  {
    schedule: 'every week',
    timeZone: 'UTC',
    retryCount: 3,
  },
  async () => {
    const db = getFirestore();
    const configuracao = await obterConfiguracaoRetencao(db);
    if (!configuracao.expurgoAutomaticoHabilitado) {
      return;
    }

    const agora = new Date();
    const commandId = `job_retencao_rascunho_${semanaIso(agora)}`;
    const payloadHash = calcularPayloadHashRetencao({
      commandId,
      motivo: 'ROTINA_AGENDADA',
      limite: 200,
    });

    await executarRotinaRetencaoRepo(db, {
      commandId,
      motivo: 'ROTINA_AGENDADA',
      dryRun: false,
      limite: 200,
      atorUid: 'SISTEMA_ROTINA_RETENCAO',
      payloadHash,
    });
  },
);

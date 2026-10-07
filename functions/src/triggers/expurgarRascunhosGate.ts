import type { Firestore } from 'firebase-admin/firestore';
import {
  calcularPayloadHashRetencao,
  type EntradaExecutarRetencao,
} from '../domain/retencao.js';
import {
  executarRotinaRetencaoRepo,
  obterConfiguracaoRetencao,
  type ConfiguracaoRetencao,
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

export interface DependenciasExpurgoAgendado {
  obterConfiguracao?: (db: Firestore) => Promise<ConfiguracaoRetencao>;
  executarRotina?: (db: Firestore, entrada: EntradaExecutarRetencao) => Promise<unknown>;
}

/**
 * Gate testável do job semanal: só executa quando `expurgoAutomaticoHabilitado`
 * é estritamente `true` e sempre com `somenteExpurgo: true` (sem anonimização).
 */
export async function executarExpurgoRascunhosAgendado(
  db: Firestore,
  agora: Date,
  deps: DependenciasExpurgoAgendado = {},
): Promise<{ executado: boolean }> {
  const obterConfiguracao = deps.obterConfiguracao ?? obterConfiguracaoRetencao;
  const executarRotina = deps.executarRotina ?? executarRotinaRetencaoRepo;

  const configuracao = await obterConfiguracao(db);
  if (!configuracao.expurgoAutomaticoHabilitado) {
    return { executado: false };
  }

  const commandId = `job_retencao_rascunho_${semanaIso(agora)}`;
  const payloadHash = calcularPayloadHashRetencao({
    commandId,
    motivo: 'ROTINA_AGENDADA',
    limite: 200,
  });

  await executarRotina(db, {
    commandId,
    motivo: 'ROTINA_AGENDADA',
    dryRun: false,
    limite: 200,
    atorUid: 'SISTEMA_ROTINA_RETENCAO',
    somenteExpurgo: true,
    payloadHash,
  });

  return { executado: true };
}

import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import type { EntradaAuditOutbox } from '../domain/auditoria.js';
import {
  processarEntradaAuditOutboxRepo,
  reconciliarAuditoriaRepo,
} from '../repositories/auditoria.js';

/**
 * Trigger Firestore acionado na criação de cada documento em `auditOutbox/{commandId}` (AD-8).
 * Materializa o registro imutável em `auditoria/{commandId}` e finaliza o recibo em `commands/{commandId}`.
 */
export const processarAuditOutbox = onDocumentCreated(
  'auditOutbox/{commandId}',
  async (event) => {
    if (!event.data) {
      return;
    }
    const commandId = event.params.commandId;
    const dados = event.data.data() as EntradaAuditOutbox;

    const resultado = await processarEntradaAuditOutboxRepo(
      getFirestore(),
      commandId,
      dados,
    );

    if (resultado.sucesso) {
      logger.info('Entrada de auditOutbox materializada com sucesso em auditoria imutável.', {
        commandId,
        jaProcessado: resultado.jaProcessado,
      });
    } else {
      logger.error('Falha no consumo de auditOutbox pelo trigger Firestore:', {
        commandId,
        erro: resultado.erro,
      });
    }
  },
);

/**
 * Job agendado periódico para reconciliação e resiliência operacional (AD-8 e AD-10).
 * Varre outbox e recibos com pendências, reprocessando com idempotência a cada 15 minutos.
 */
export const reconciliarAuditoriaScheduled = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeZone: 'UTC',
    retryCount: 3,
  },
  async () => {
    const db = getFirestore();
    const resultado = await reconciliarAuditoriaRepo(db, { limite: 100 });

    logger.info('Execução periódica de reconciliação de auditoria concluída.', {
      pendentesEncontrados: resultado.pendentesEncontrados,
      reconciliados: resultado.reconciliados,
      falhas: resultado.falhas,
      alertasEmitidos: resultado.alertasEmitidos,
    });
  },
);

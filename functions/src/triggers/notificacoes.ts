import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import {
  mapearEventoAuditoriaParaNotificacao,
  type EventoAuditoriaOutbox,
} from '../domain/notificacao.js';
import { emitirNotificacaoSeguraRepo } from '../repositories/notificacao.js';

/**
 * Processa um evento persistido em `auditOutbox` e, quando ele representa um
 * marco decisório notificável, emite uma notificação segura para o voluntário
 * (AD-10: disparo exclusivamente a partir de evento já comprometido).
 *
 * Idempotente por construção: o documento de notificação tem id determinístico
 * derivado de `commandId` + `destinatarioUid`, então reexecuções do trigger
 * apenas regravam o mesmo documento.
 */
export async function processarEventoAuditOutbox(
  db: Firestore,
  commandId: string,
  evento: EventoAuditoriaOutbox,
): Promise<boolean> {
  const mapeado = mapearEventoAuditoriaParaNotificacao(evento);
  if (!mapeado) {
    return false;
  }

  await emitirNotificacaoSeguraRepo(db, {
    commandId,
    destinatarioUid: mapeado.destinatarioUid,
    tipo: mapeado.tipo,
    estado: mapeado.estado,
  });

  return true;
}

/**
 * Trigger Firestore acionado na criação de cada evento de `auditOutbox`.
 * Falhas são propagadas para ficarem visíveis nos logs do Cloud Functions.
 */
export const notificarEventoAuditOutbox = onDocumentCreated(
  'auditOutbox/{commandId}',
  async (event) => {
    if (!event.data) {
      return;
    }
    const commandId = event.params.commandId;
    const emitida = await processarEventoAuditOutbox(
      getFirestore(),
      commandId,
      event.data.data() as EventoAuditoriaOutbox,
    );
    if (emitida) {
      logger.info('Notificação pós-compromisso emitida a partir de auditOutbox.', {
        commandId,
      });
    }
  },
);

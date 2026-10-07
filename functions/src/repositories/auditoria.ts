import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import {
  montarRegistroAuditoriaImutavel,
  type AlertaOperacional,
  type EntradaAuditOutbox,
  type RegistroAuditoria,
  type ResultadoProcessamentoOutbox,
  type ResultadoReconciliacao,
} from '../domain/auditoria.js';

/**
 * Emite ou atualiza um alerta operacional em `alertasOperacionais/:alertaId` (AD-8/AD-10).
 */
export async function emitirAlertaOperacionalRepo(
  db: Firestore,
  alerta: Omit<AlertaOperacional, 'criadoEm'>,
): Promise<void> {
  const alertaRef = db.collection('alertasOperacionais').doc(alerta.id);
  await alertaRef.set(
    {
      ...alerta,
      criadoEm: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  logger.warn('Alerta operacional emitido na auditoria:', {
    alertaId: alerta.id,
    tipo: alerta.tipo,
    severidade: alerta.severidade,
    commandId: alerta.commandId,
    motivo: alerta.motivo,
  });
}

/**
 * Consumidor idempotente de uma entrada individual de `auditOutbox` (AD-8).
 *
 * 1. Materializa a entrada na coleção imutável `auditoria/:commandId`.
 * 2. Atualiza o recibo `commands/:commandId` para status `COMPLETO`.
 * 3. Marca a entrada de outbox como `processado: true`.
 * 4. Jamais altera o estado ou entidades do domínio de negócio.
 */
export async function processarEntradaAuditOutboxRepo(
  db: Firestore,
  commandId: string,
  dadosPreCarregados?: EntradaAuditOutbox,
): Promise<ResultadoProcessamentoOutbox> {
  const id = String(commandId).trim();
  if (!id) {
    return { sucesso: false, commandId: id, jaProcessado: false, erro: 'COMMAND_ID_INVALIDO' };
  }

  const outboxRef = db.collection('auditOutbox').doc(id);
  const auditoriaRef = db.collection('auditoria').doc(id);
  const commandRef = db.collection('commands').doc(id);

  try {
    let outboxData = dadosPreCarregados;
    if (!outboxData) {
      const snapOutbox = await outboxRef.get();
      if (!snapOutbox.exists) {
        return {
          sucesso: false,
          commandId: id,
          jaProcessado: false,
          erro: 'ENTRADA_OUTBOX_NAO_ENCONTRADA',
        };
      }
      outboxData = snapOutbox.data() as EntradaAuditOutbox;
    }

    // Se já foi processado e auditoria já existe, garante consistência e retorna
    if (outboxData.processado === true) {
      const snapAudit = await auditoriaRef.get();
      if (snapAudit.exists) {
        return { sucesso: true, commandId: id, jaProcessado: true };
      }
    }

    const agora = FieldValue.serverTimestamp();
    const registroAuditoria = montarRegistroAuditoriaImutavel(
      { ...outboxData, commandId: id },
      agora,
    );

    // Execução transacional para assegurar atomicidade entre auditoria, comando e outbox
    await db.runTransaction(async (tx) => {
      const auditDoc = await tx.get(auditoriaRef);
      if (!auditDoc.exists) {
        tx.create(auditoriaRef, registroAuditoria);
      }

      const cmdDoc = await tx.get(commandRef);
      if (cmdDoc.exists) {
        tx.update(commandRef, {
          status: 'COMPLETO',
          auditoriaProcessada: true,
          auditoriaId: id,
          auditoriaProcessadaEm: agora,
        });
      }

      tx.set(
        outboxRef,
        {
          processado: true,
          processadoEm: agora,
          erro: null,
        },
        { merge: true },
      );
    });

    return { sucesso: true, commandId: id, jaProcessado: false };
  } catch (err: unknown) {
    const mensagemErro = err instanceof Error ? err.message : String(err);
    logger.error('Falha ao processar entrada de auditOutbox:', {
      commandId: id,
      erro: mensagemErro,
    });

    // Registra falha na entrada de outbox
    try {
      const snap = await outboxRef.get();
      const tentativasAtuais = (snap.data()?.tentativas as number | undefined) ?? 0;
      const novasTentativas = tentativasAtuais + 1;

      await outboxRef.set(
        {
          tentativas: novasTentativas,
          erro: mensagemErro,
          ultimaTentativaEm: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Emite alerta operacional se falhas persistirem (>= 3 tentativas)
      if (novasTentativas >= 3) {
        await emitirAlertaOperacionalRepo(db, {
          id: `ALERTA_OUTBOX_${id}`,
          tipo: 'OUTBOX_FALHA_PROCESSAMENTO',
          severidade: 'ALTA',
          commandId: id,
          motivo: `Falha persistente no processamento de auditOutbox após ${novasTentativas} tentativas: ${mensagemErro}`,
          detalhes: {
            tentativas: novasTentativas,
            erro: mensagemErro,
          },
          resolvido: false,
        });
      }
    } catch (gravacaoErr) {
      logger.error('Falha secundária ao registrar erro em auditOutbox:', gravacaoErr);
    }

    return { sucesso: false, commandId: id, jaProcessado: false, erro: mensagemErro };
  }
}

/**
 * Consulta pontual de registro imutável em `auditoria/:commandId`.
 */
export async function obterRegistroAuditoriaRepo(
  db: Firestore,
  commandId: string,
): Promise<RegistroAuditoria | null> {
  const id = String(commandId).trim();
  if (!id) return null;

  const doc = await db.collection('auditoria').doc(id).get();
  if (!doc.exists) return null;
  return doc.data() as RegistroAuditoria;
}

/**
 * Job e rotina idempotente de reconciliação e resiliência operacional (AD-8 e AD-10).
 * Varre outbox e recibos pendentes, reprocessa e alerta sobre inconsistências.
 */
export async function reconciliarAuditoriaRepo(
  db: Firestore,
  opcoes: { limite?: number; agoraIso?: string } = {},
): Promise<ResultadoReconciliacao> {
  const limite = Math.min(Math.max(opcoes.limite ?? 50, 1), 200);

  const commandIdsProcessados: string[] = [];
  const commandIdsComFalha: string[] = [];
  let alertasEmitidos = 0;

  // 1. Drenar entradas não processadas em `auditOutbox`
  // Para cobrir documentos com processado == false ou sem o campo processado:
  const snapOutbox = await db.collection('auditOutbox').limit(limite).get();
  const entradasPendentes: Array<{ id: string; data: EntradaAuditOutbox }> = [];

  for (const doc of snapOutbox.docs) {
    const data = doc.data() as EntradaAuditOutbox;
    if (data.processado !== true) {
      entradasPendentes.push({ id: doc.id, data });
    }
  }

  // 2. Reprocessar cada entrada pendente
  for (const item of entradasPendentes) {
    const res = await processarEntradaAuditOutboxRepo(db, item.id, item.data);
    if (res.sucesso) {
      commandIdsProcessados.push(item.id);
    } else {
      commandIdsComFalha.push(item.id);
    }
  }

  // 3. Varredura de recibos em `commands` para detectar comandos órfãos/incompletos
  try {
    const snapCmds = await db
      .collection('commands')
      .where('status', '==', 'PENDENTE')
      .limit(limite)
      .get();

    for (const docCmd of snapCmds.docs) {
      const commandId = docCmd.id;
      // Verifica se possui registro em auditOutbox
      const outboxDoc = await db.collection('auditOutbox').doc(commandId).get();
      if (!outboxDoc.exists) {
        // Alerta operacional crítico: comando em PENDENTE sem entrada correlacionada na outbox!
        await emitirAlertaOperacionalRepo(db, {
          id: `ALERTA_COMANDO_ORFAO_${commandId}`,
          tipo: 'COMANDO_ORFAO_SEM_OUTBOX',
          severidade: 'CRITICA',
          commandId,
          motivo: `Recibo de comando ${commandId} está com status PENDENTE sem entrada correspondente na fila auditOutbox.`,
          detalhes: {
            dadosComando: docCmd.data(),
          },
          resolvido: false,
        });
        alertasEmitidos++;
      } else {
        // Se possui outbox, tenta processar
        const res = await processarEntradaAuditOutboxRepo(
          db,
          commandId,
          outboxDoc.data() as EntradaAuditOutbox,
        );
        if (res.sucesso && !commandIdsProcessados.includes(commandId)) {
          commandIdsProcessados.push(commandId);
        } else if (!res.sucesso && !commandIdsComFalha.includes(commandId)) {
          commandIdsComFalha.push(commandId);
        }
      }
    }
  } catch (errCmd) {
    logger.warn('Aviso durante varredura de commands na reconciliação:', errCmd);
  }

  return {
    pendentesEncontrados: entradasPendentes.length,
    reconciliados: commandIdsProcessados.length,
    falhas: commandIdsComFalha.length,
    alertasEmitidos,
    commandIdsProcessados,
    commandIdsComFalha,
  };
}

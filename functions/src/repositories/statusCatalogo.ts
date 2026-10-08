import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  EntidadeInexistenteError,
  SemAutoridadeError,
  hashAlternarStatus,
  type EntradaAlternarStatusEquipe,
  type EntradaAlternarStatusIgreja,
  type ResultadoAlternarStatus,
} from '../domain/catalogo.js';

const ACAO_RECIBO_STATUS_IGREJA = 'ALTERNAR_STATUS_IGREJA';
const ACAO_RECIBO_STATUS_EQUIPE = 'ALTERNAR_STATUS_EQUIPE';
const ACAO_AUDITORIA_STATUS_IGREJA = 'IGREJA_STATUS_ALTERADO';
const ACAO_AUDITORIA_STATUS_EQUIPE = 'EQUIPE_STATUS_ALTERADO';

export type ContextoAlterarStatus = {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
};

/**
 * Alterna logicamente o status de uma igreja (ativo: true/false).
 * Transacional, idempotente por commandId e auditado em auditOutbox.
 */
export async function alternarStatusIgrejaRepo(
  db: Firestore,
  contexto: ContextoAlterarStatus,
  entrada: EntradaAlternarStatusIgreja,
): Promise<ResultadoAlternarStatus> {
  const payloadHash = hashAlternarStatus('IGREJA', entrada.igrejaId, entrada.ativo);
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const igrejaRef = db.collection('igrejas').doc(entrada.igrejaId);

  return db.runTransaction(async (tx) => {
    const atorRef = db
      .collection('autoridadesAdministrativas')
      .doc(contexto.atorUid);
    const [atorSnap, reciboSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      if (
        recibo.action !== ACAO_RECIBO_STATUS_IGREJA ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        repetido: true,
        id: entrada.igrejaId,
        ativo: entrada.ativo,
      };
    }

    const igrejaSnap = await tx.get(igrejaRef);
    if (!igrejaSnap.exists) {
      throw new EntidadeInexistenteError('IGREJA', entrada.igrejaId);
    }
    const igrejaDados = igrejaSnap.data() ?? {};
    const ativoAnterior = igrejaDados.ativo === true;

    tx.update(igrejaRef, {
      ativo: entrada.ativo,
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO_STATUS_IGREJA,
      estado: 'COMPLETO',
      payloadHash,
      entidadeId: entrada.igrejaId,
      ativo: entrada.ativo,
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_AUDITORIA_STATUS_IGREJA,
      entidadeId: entrada.igrejaId,
      antes: { ativo: ativoAnterior },
      depois: { ativo: entrada.ativo },
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      repetido: false,
      id: entrada.igrejaId,
      ativo: entrada.ativo,
    };
  });
}

/**
 * Alterna logicamente o status de uma equipe (ativo: true/false).
 * Transacional, idempotente por commandId e auditado em auditOutbox.
 */
export async function alternarStatusEquipeRepo(
  db: Firestore,
  contexto: ContextoAlterarStatus,
  entrada: EntradaAlternarStatusEquipe,
): Promise<ResultadoAlternarStatus> {
  const payloadHash = hashAlternarStatus('EQUIPE', entrada.equipeId, entrada.ativo);
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const equipeRef = db.collection('equipes').doc(entrada.equipeId);

  return db.runTransaction(async (tx) => {
    const atorRef = db
      .collection('autoridadesAdministrativas')
      .doc(contexto.atorUid);
    const [atorSnap, reciboSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      if (
        recibo.action !== ACAO_RECIBO_STATUS_EQUIPE ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        repetido: true,
        id: entrada.equipeId,
        ativo: entrada.ativo,
      };
    }

    const equipeSnap = await tx.get(equipeRef);
    if (!equipeSnap.exists) {
      throw new EntidadeInexistenteError('EQUIPE', entrada.equipeId);
    }
    const equipeDados = equipeSnap.data() ?? {};
    const ativoAnterior = equipeDados.ativo === true;

    tx.update(equipeRef, {
      ativo: entrada.ativo,
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO_STATUS_EQUIPE,
      estado: 'COMPLETO',
      payloadHash,
      entidadeId: entrada.equipeId,
      ativo: entrada.ativo,
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_AUDITORIA_STATUS_EQUIPE,
      entidadeId: entrada.equipeId,
      antes: { ativo: ativoAnterior },
      depois: { ativo: entrada.ativo },
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      repetido: false,
      id: entrada.equipeId,
      ativo: entrada.ativo,
    };
  });
}

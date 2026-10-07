import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  MotivoObrigatorioLiderancaError,
  ParticipacaoJaTerminalError,
  ParticipacaoNaoEncontradaError,
  type EntradaCancelarParticipacao,
  type ResultadoCancelarParticipacao,
} from '../domain/cancelarParticipacao.js';
import {
  FichaJaTerminalError,
  FichaNaoEncontradaError,
  type EntradaCancelarVoluntariado,
  type ResultadoCancelarVoluntariado,
} from '../domain/cancelarVoluntariado.js';
import { MENSAGEM_CANONICA_DECISAO_NEGATIVA } from '../domain/mensagens.js';
import { ESTADOS_TERMINAIS_PARTICIPACAO } from '../domain/participacao.js';
import {
  PAPEL_ADMINISTRADOR,
  PAPEL_COORDENADOR,
  podeAdministrar,
  possuiPapel,
} from '../domain/autoridadeAdministrativa.js';

export interface ContextoCancelamento {
  commandId: string;
  correlationId?: string;
  uid: string;
}

/** Teto de leitura das participações do voluntário na transação (AD-9). */
const LIMITE_PARTICIPACOES_VOLUNTARIO = 100;

/** Estados terminais de ciclo que não devem ser reescritos. */
const ESTADOS_TERMINAIS_CICLO = ['CANCELADO', 'REJEITADO', 'EXPIRADO'];

/** Estados terminais de ficha que não admitem novo cancelamento. */
const ESTADOS_TERMINAIS_FICHA = ['CANCELADA', 'REJEITADA'];

function iso(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return String(valor);
}

/**
 * Avalia se o usuário autenticado possui autoridade de Coordenador Geral.
 *
 * A única fonte de verdade é o agregado `autoridadesAdministrativas`; a coleção
 * `pessoas` não é consultada como fallback para não manter uma fonte revogável
 * paralela (ver `decisaoCoordenador.avaliarAutoridadeCoordenador`).
 */
async function verificarSeCoordenador(
  db: Firestore,
  tx: Transaction,
  uid: string,
): Promise<boolean> {
  const autoridadeSnap = await tx.get(db.collection('autoridadesAdministrativas').doc(uid));
  if (!autoridadeSnap.exists) return false;
  const data = autoridadeSnap.data();
  return (
    podeAdministrar(data) ||
    possuiPapel(data, PAPEL_COORDENADOR) ||
    possuiPapel(data, PAPEL_ADMINISTRADOR)
  );
}

/**
 * Avalia se o usuário autenticado é o Pastor Local vigente da igreja informada.
 */
async function verificarSePastorLocal(
  db: Firestore,
  tx: Transaction,
  uid: string,
  igrejaId?: string,
): Promise<boolean> {
  if (!igrejaId) return false;

  const igrejaSnap = await tx.get(db.collection('igrejas').doc(igrejaId));
  if (igrejaSnap.exists && igrejaSnap.data()?.pastorLocalVigentePessoaId === uid) {
    return true;
  }

  const vinculosSnap = await tx.get(
    db
      .collection('vinculosPastorIgreja')
      .where('pessoaId', '==', uid)
      .where('igrejaId', '==', igrejaId)
      .where('estado', '==', 'VIGENTE'),
  );

  return !vinculosSnap.empty;
}

/**
 * Avalia se o usuário autenticado é o Responsável de Equipe vigente da equipe informada.
 */
async function verificarSeResponsavelEquipe(
  db: Firestore,
  tx: Transaction,
  uid: string,
  equipeId?: string,
): Promise<boolean> {
  if (!equipeId) return false;

  const equipeSnap = await tx.get(db.collection('equipes').doc(equipeId));
  if (equipeSnap.exists && equipeSnap.data()?.responsavelVigentePessoaId === uid) {
    return true;
  }

  const vinculosSnap = await tx.get(
    db
      .collection('vinculosPastorEquipe')
      .where('pessoaId', '==', uid)
      .where('entidadeId', '==', equipeId)
      .where('estado', '==', 'VIGENTE'),
  );

  return !vinculosSnap.empty;
}

/**
 * Avalia se o usuário é Responsável de Equipe vigente de qualquer equipe, para
 * rejeitar sumariamente o cancelamento integral da ficha por esse papel.
 */
async function ehResponsavelEquipeAlguma(
  db: Firestore,
  tx: Transaction,
  uid: string,
): Promise<boolean> {
  const equipesSnap = await tx.get(
    db.collection('equipes').where('responsavelVigentePessoaId', '==', uid),
  );
  if (!equipesSnap.empty) return true;

  const vinculosSnap = await tx.get(
    db
      .collection('vinculosPastorEquipe')
      .where('pessoaId', '==', uid)
      .where('tipo', '==', 'EQUIPE')
      .where('estado', '==', 'VIGENTE'),
  );
  return !vinculosSnap.empty;
}

/**
 * Transação atômica que cancela uma participação individual.
 *
 * Invariantes (AD-1, AD-2, AD-4, AD-11, AD-12):
 * - Idempotente via commands/{commandId}.
 * - Autorizado para: Titular, Pastor Local da igreja da ficha, Responsável da equipe, Coordenador.
 * - Outras participações ativas da ficha permanecem intocadas.
 * - Redução canônica (AD-11): Ficha permanece ATIVA se tiver ao menos outra participação ATIVA;
 *   caso contrário, transiciona para INATIVA.
 * - Sigilo pastoral: Mensagem canônica neutra para o voluntário caso deliberado por líder.
 * - Evidência append-only em evidenciasDecisao e auditoria sem PII em auditOutbox.
 *
 * Todas as leituras da transação (`tx.get`) acontecem antes de qualquer escrita,
 * e as checagens de autoridade também usam o snapshot da transação (AD-2).
 */
export async function executarCancelarParticipacaoRepo(
  db: Firestore,
  contexto: ContextoCancelamento,
  entrada: EntradaCancelarParticipacao,
): Promise<ResultadoCancelarParticipacao> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const partRef = db.collection('participacoes').doc(entrada.participacaoId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new AutoridadeInsuficienteError();
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        participacaoId: entrada.participacaoId,
        estado: 'CANCELADA',
        proximaAcao: String(res?.proximaAcao ?? ''),
        fichaId: String(res?.fichaId ?? ''),
        fichaEstado: String(res?.fichaEstado ?? ''),
        canceladoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura da Participação
    const partSnap = await tx.get(partRef);
    if (!partSnap.exists) {
      throw new ParticipacaoNaoEncontradaError();
    }
    const partData = partSnap.data() ?? {};

    if (ESTADOS_TERMINAIS_PARTICIPACAO.includes(String(partData.estado))) {
      throw new ParticipacaoJaTerminalError();
    }

    if (
      entrada.expectedVersion !== undefined &&
      partData.versao !== undefined &&
      Number(partData.versao) !== entrada.expectedVersion
    ) {
      throw new ConflitoVersaoError();
    }

    const fichaId = String(partData.fichaId ?? '');
    const equipeId = String(partData.equipeId ?? '');
    const cicloAtualId = String(partData.cicloAtualId ?? '');

    // 3. Leitura da Ficha
    const fichaRef = db.collection('fichas').doc(fichaId);
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};
    const igrejaId = String(fichaData.igrejaId ?? '');

    // 4. Determinação de Autoridade em Runtime (dentro do snapshot da transação)
    let papelAtor: 'VOLUNTARIO' | 'PASTOR_LOCAL' | 'RESPONSAVEL_EQUIPE' | 'COORDENADOR' | null =
      null;

    const ehTitular = contexto.uid === fichaId || contexto.uid === partData.voluntarioUid;
    if (ehTitular) {
      papelAtor = 'VOLUNTARIO';
    } else if (await verificarSeCoordenador(db, tx, contexto.uid)) {
      papelAtor = 'COORDENADOR';
    } else if (await verificarSePastorLocal(db, tx, contexto.uid, igrejaId)) {
      papelAtor = 'PASTOR_LOCAL';
    } else if (await verificarSeResponsavelEquipe(db, tx, contexto.uid, equipeId)) {
      papelAtor = 'RESPONSAVEL_EQUIPE';
    }

    if (!papelAtor) {
      throw new AutoridadeInsuficienteError();
    }

    if (papelAtor !== 'VOLUNTARIO' && (!entrada.motivo || !entrada.motivo.trim())) {
      throw new MotivoObrigatorioLiderancaError();
    }

    // 5. Leitura do ciclo atual associado (antes de qualquer escrita)
    let cicloRef: DocumentReference | null = null;
    let cicloData: Record<string, unknown> | null = null;
    if (cicloAtualId) {
      const ref = db.collection('ciclos').doc(cicloAtualId);
      const cicloSnap = await tx.get(ref);
      if (cicloSnap.exists) {
        cicloRef = ref;
        cicloData = cicloSnap.data() ?? {};
      }
    }

    // 6. Leitura das demais participações da ficha (antes de qualquer escrita)
    const todasParticipacoesSnap = await tx.get(
      db
        .collection('participacoes')
        .where('fichaId', '==', fichaId)
        .limit(LIMITE_PARTICIPACOES_VOLUNTARIO),
    );

    // 7. Determinação da Mensagem e Próxima Ação Canônica
    const proximaAcao =
      papelAtor === 'VOLUNTARIO'
        ? 'Participação cancelada pelo voluntário'
        : MENSAGEM_CANONICA_DECISAO_NEGATIVA;

    // 8. Atualização da Participação Alvo
    const novaVersao = Number(partData.versao ?? 1) + 1;
    tx.update(partRef, {
      estado: 'CANCELADA',
      proximaAcao,
      canceladoPorUid: contexto.uid,
      canceladoPorPapel: papelAtor,
      versao: novaVersao,
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    // 9. Encerramento do ciclo atual associado, se houver
    if (cicloRef && cicloData) {
      if (!ESTADOS_TERMINAIS_CICLO.includes(String(cicloData.estado ?? ''))) {
        tx.update(cicloRef, {
          estado: 'CANCELADO',
          atualizadoEm: FieldValue.serverTimestamp(),
        });
      }
    }

    // 10. Redução Canônica da Ficha (AD-11)
    let temOutraAtiva = false;
    for (const doc of todasParticipacoesSnap.docs) {
      if (doc.id === entrada.participacaoId) continue;
      const d = doc.data() ?? {};
      if (d.estado === 'ATIVA') {
        temOutraAtiva = true;
        break;
      }
    }

    let novoEstadoFicha = String(fichaData.estado ?? 'ATIVA');
    if (fichaData.estado === 'ATIVA' && !temOutraAtiva) {
      novoEstadoFicha = 'INATIVA';
      tx.update(fichaRef, {
        estado: 'INATIVA',
        proximaAcao:
          papelAtor === 'VOLUNTARIO'
            ? 'Sem participações ativas vigentes'
            : MENSAGEM_CANONICA_DECISAO_NEGATIVA,
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }

    // 11. Registro de Evidência de Decisão
    tx.set(evidenciaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      tipo: 'CANCELAR_PARTICIPACAO',
      participacaoId: entrada.participacaoId,
      fichaId,
      equipeId,
      atorUid: contexto.uid,
      papelAtor,
      motivoInterno: entrada.motivo?.trim() ?? null,
      mensagemExibida: proximaAcao,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 12. Auditoria Append-Only (ator + antes/depois; sem PII - AD-12)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      atorUid: contexto.uid,
      tipo: 'PARTICIPACAO_CANCELADA',
      participacaoId: entrada.participacaoId,
      fichaId,
      equipeId,
      papelAtor,
      antes: { estado: String(partData.estado ?? '') },
      depois: { estado: 'CANCELADA' },
      novoEstadoFicha,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 13. Recibo de Idempotência
    const resultado: ResultadoCancelarParticipacao = {
      sucesso: true,
      repetido: false,
      participacaoId: entrada.participacaoId,
      estado: 'CANCELADA',
      proximaAcao,
      fichaId,
      fichaEstado: novoEstadoFicha,
      canceladoEm: new Date().toISOString(),
    };

    tx.set(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.uid,
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return resultado;
  });
}

/**
 * Transação atômica que cancela toda a ficha e todas as participações não terminais.
 *
 * Invariantes (AD-1, AD-2, AD-4, AD-11, AD-12):
 * - Idempotente via commands/{commandId}.
 * - Autorizado para: Titular, Pastor Local da igreja da ficha, Coordenador Geral.
 * - Bloqueio estrito para: Responsável de Equipe (rejeitado com AutoridadeInsuficienteError).
 * - Todas as participações não terminais tornam-se CANCELADA.
 * - A ficha transiciona para CANCELADA.
 * - Sigilo pastoral: Mensagem canônica neutra para o voluntário caso cancelado por líder.
 *
 * Todas as leituras da transação (`tx.get`) acontecem antes de qualquer escrita.
 */
export async function executarCancelarVoluntariadoRepo(
  db: Firestore,
  contexto: ContextoCancelamento,
  entrada: EntradaCancelarVoluntariado,
): Promise<ResultadoCancelarVoluntariado> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(entrada.fichaId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new AutoridadeInsuficienteError();
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        fichaId: entrada.fichaId,
        estado: 'CANCELADA',
        participacoesAfetadas: Array.isArray(res?.participacoesAfetadas)
          ? (res.participacoesAfetadas as string[])
          : [],
        canceladoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura da Ficha
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};

    if (ESTADOS_TERMINAIS_FICHA.includes(String(fichaData.estado ?? ''))) {
      throw new FichaJaTerminalError();
    }

    if (
      entrada.expectedVersion !== undefined &&
      fichaData.versao !== undefined &&
      Number(fichaData.versao) !== entrada.expectedVersion
    ) {
      throw new ConflitoVersaoError();
    }

    const igrejaId = String(fichaData.igrejaId ?? '');

    // 3. Determinação de Autoridade em Runtime (dentro do snapshot da transação)
    let papelAtor: 'VOLUNTARIO' | 'PASTOR_LOCAL' | 'COORDENADOR' | null = null;

    const ehTitular = contexto.uid === entrada.fichaId;
    if (ehTitular) {
      papelAtor = 'VOLUNTARIO';
    } else if (await verificarSeCoordenador(db, tx, contexto.uid)) {
      papelAtor = 'COORDENADOR';
    } else if (await verificarSePastorLocal(db, tx, contexto.uid, igrejaId)) {
      papelAtor = 'PASTOR_LOCAL';
    } else if (await ehResponsavelEquipeAlguma(db, tx, contexto.uid)) {
      // Responsável de equipe não possui autoridade para cancelar a ficha toda.
      throw new AutoridadeInsuficienteError(
        'Responsável de equipe não tem autoridade para cancelar toda a ficha.',
      );
    }

    if (!papelAtor) {
      throw new AutoridadeInsuficienteError(
        'Usuário não possui autoridade para cancelar a ficha de voluntariado.',
      );
    }

    if (papelAtor !== 'VOLUNTARIO' && (!entrada.motivo || !entrada.motivo.trim())) {
      throw new MotivoObrigatorioLiderancaError();
    }

    // 4. Determinação da Mensagem Canônica
    const proximaAcao =
      papelAtor === 'VOLUNTARIO'
        ? 'Voluntariado encerrado a pedido do titular'
        : MENSAGEM_CANONICA_DECISAO_NEGATIVA;

    // 5. Leitura de todas as participações da ficha (antes de qualquer escrita)
    const participacoesSnap = await tx.get(
      db
        .collection('participacoes')
        .where('fichaId', '==', entrada.fichaId)
        .limit(LIMITE_PARTICIPACOES_VOLUNTARIO),
    );

    const participacoesAfetadas: string[] = [];
    const ciclosEncontrados: Array<{
      ref: DocumentReference;
      data: Record<string, unknown>;
    }> = [];

    for (const doc of participacoesSnap.docs) {
      const pData = doc.data() ?? {};
      if (ESTADOS_TERMINAIS_PARTICIPACAO.includes(String(pData.estado))) continue;
      participacoesAfetadas.push(doc.id);

      const cicloId = String(pData.cicloAtualId ?? '');
      if (cicloId) {
        const cRef = db.collection('ciclos').doc(cicloId);
        const cSnap = await tx.get(cRef);
        if (cSnap.exists) {
          ciclosEncontrados.push({ ref: cRef, data: cSnap.data() ?? {} });
        }
      }
    }

    // 6. Escritas: participações não terminais
    for (const doc of participacoesSnap.docs) {
      const pData = doc.data() ?? {};
      if (ESTADOS_TERMINAIS_PARTICIPACAO.includes(String(pData.estado))) continue;
      const novaVersao = Number(pData.versao ?? 1) + 1;
      tx.update(doc.ref, {
        estado: 'CANCELADA',
        proximaAcao,
        canceladoPorUid: contexto.uid,
        canceladoPorPapel: papelAtor,
        versao: novaVersao,
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }

    // 7. Escritas: ciclos associados não terminais
    for (const ciclo of ciclosEncontrados) {
      if (!ESTADOS_TERMINAIS_CICLO.includes(String(ciclo.data.estado ?? ''))) {
        tx.update(ciclo.ref, {
          estado: 'CANCELADO',
          atualizadoEm: FieldValue.serverTimestamp(),
        });
      }
    }

    // 8. Atualização da Ficha Permanente para CANCELADA
    tx.update(fichaRef, {
      estado: 'CANCELADA',
      proximaAcao,
      canceladoPorUid: contexto.uid,
      canceladoPorPapel: papelAtor,
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    // 9. Registro de Evidência de Decisão
    tx.set(evidenciaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      tipo: 'CANCELAR_VOLUNTARIADO',
      fichaId: entrada.fichaId,
      atorUid: contexto.uid,
      papelAtor,
      motivoInterno: entrada.motivo?.trim() ?? null,
      mensagemExibida: proximaAcao,
      participacoesAfetadas,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 10. Auditoria Append-Only (ator + antes/depois; sem PII - AD-12)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      atorUid: contexto.uid,
      tipo: 'VOLUNTARIADO_CANCELADO',
      fichaId: entrada.fichaId,
      papelAtor,
      antes: { estado: String(fichaData.estado ?? '') },
      depois: { estado: 'CANCELADA' },
      quantidadeParticipacoesCanceladas: participacoesAfetadas.length,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 11. Recibo de Idempotência
    const resultado: ResultadoCancelarVoluntariado = {
      sucesso: true,
      repetido: false,
      fichaId: entrada.fichaId,
      estado: 'CANCELADA',
      participacoesAfetadas,
      canceladoEm: new Date().toISOString(),
    };

    tx.set(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.uid,
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return resultado;
  });
}

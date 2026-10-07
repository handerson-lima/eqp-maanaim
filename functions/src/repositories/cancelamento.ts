import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
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

const ESTADOS_TERMINAIS = ['CANCELADA', 'REJEITADA'];

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
 */
async function verificarSeCoordenador(
  db: Firestore,
  uid: string,
): Promise<boolean> {
  const autoridadeSnap = await db.collection('autoridadesAdministrativas').doc(uid).get();
  if (autoridadeSnap.exists) {
    const data = autoridadeSnap.data();
    if (podeAdministrar(data) || possuiPapel(data, PAPEL_COORDENADOR) || possuiPapel(data, PAPEL_ADMINISTRADOR)) {
      return true;
    }
  }

  // Consulta complementar em pessoas
  const pessoaSnap = await db.collection('pessoas').doc(uid).get();
  if (pessoaSnap.exists) {
    const pData = pessoaSnap.data() ?? {};
    if (pData.coordenador === true || pData.administrador === true) {
      return true;
    }
    const papeis = Array.isArray(pData.papeis) ? pData.papeis : [];
    if (papeis.includes('COORDENADOR') || papeis.includes('ADMINISTRADOR')) {
      return true;
    }
  }

  return false;
}

/**
 * Avalia se o usuário autenticado é o Pastor Local vigente da igreja informada.
 */
async function verificarSePastorLocal(
  db: Firestore,
  uid: string,
  igrejaId?: string,
): Promise<boolean> {
  if (!igrejaId) return false;

  const igrejaSnap = await db.collection('igrejas').doc(igrejaId).get();
  if (igrejaSnap.exists) {
    const igData = igrejaSnap.data() ?? {};
    if (igData.pastorLocalVigentePessoaId === uid) {
      return true;
    }
  }

  const vinculosSnap = await db
    .collection('vinculosPastorEquipe')
    .where('pessoaId', '==', uid)
    .where('entidadeId', '==', igrejaId)
    .where('estado', '==', 'VIGENTE')
    .get();

  return !vinculosSnap.empty;
}

/**
 * Avalia se o usuário autenticado é o Responsável de Equipe vigente da equipe informada.
 */
async function verificarSeResponsavelEquipe(
  db: Firestore,
  uid: string,
  equipeId?: string,
): Promise<boolean> {
  if (!equipeId) return false;

  const equipeSnap = await db.collection('equipes').doc(equipeId).get();
  if (equipeSnap.exists) {
    const eqData = equipeSnap.data() ?? {};
    if (eqData.responsavelVigentePessoaId === uid) {
      return true;
    }
  }

  const vinculosSnap = await db
    .collection('vinculosPastorEquipe')
    .where('pessoaId', '==', uid)
    .where('entidadeId', '==', equipeId)
    .where('estado', '==', 'VIGENTE')
    .get();

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

    if (ESTADOS_TERMINAIS.includes(String(partData.estado))) {
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

    // 3. Leitura da Ficha
    const fichaRef = db.collection('fichas').doc(fichaId);
    const fichaSnap = await tx.get(fichaRef);
    const fichaData = fichaSnap.exists ? fichaSnap.data() ?? {} : {};
    const igrejaId = String(fichaData.igrejaId ?? '');

    // 4. Determinação de Autoridade em Runtime
    let papelAtor: 'VOLUNTARIO' | 'PASTOR_LOCAL' | 'RESPONSAVEL_EQUIPE' | 'COORDENADOR' | null = null;

    const ehTitular = contexto.uid === fichaId || contexto.uid === partData.voluntarioUid;
    if (ehTitular) {
      papelAtor = 'VOLUNTARIO';
    } else {
      const ehCoordenador = await verificarSeCoordenador(db, contexto.uid);
      if (ehCoordenador) {
        papelAtor = 'COORDENADOR';
      } else {
        const ehPastor = await verificarSePastorLocal(db, contexto.uid, igrejaId);
        if (ehPastor) {
          papelAtor = 'PASTOR_LOCAL';
        } else {
          const ehResponsavel = await verificarSeResponsavelEquipe(db, contexto.uid, equipeId);
          if (ehResponsavel) {
            papelAtor = 'RESPONSAVEL_EQUIPE';
          }
        }
      }
    }

    if (!papelAtor) {
      throw new AutoridadeInsuficienteError();
    }

    if (papelAtor !== 'VOLUNTARIO' && (!entrada.motivo || !entrada.motivo.trim())) {
      throw new MotivoObrigatorioLiderancaError();
    }

    // 5. Determinação da Mensagem e Próxima Ação Canônica
    const proximaAcao =
      papelAtor === 'VOLUNTARIO'
        ? 'Participação cancelada pelo voluntário'
        : MENSAGEM_CANONICA_DECISAO_NEGATIVA;

    // 6. Atualização da Participação Alvo
    const novaVersao = Number(partData.versao ?? 1) + 1;
    tx.update(partRef, {
      estado: 'CANCELADA',
      proximaAcao,
      canceladoPorUid: contexto.uid,
      canceladoPorPapel: papelAtor,
      versao: novaVersao,
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    // 7. Encerramento do ciclo atual associado, se houver
    const cicloAtualId = String(partData.cicloAtualId ?? '');
    if (cicloAtualId) {
      const cicloRef = db.collection('ciclos').doc(cicloAtualId);
      const cicloSnap = await tx.get(cicloRef);
      if (cicloSnap.exists) {
        const cicloData = cicloSnap.data() ?? {};
        if (!ESTADOS_TERMINAIS.includes(String(cicloData.estado))) {
          tx.update(cicloRef, {
            estado: 'CANCELADO',
            atualizadoEm: FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // 8. Redução Canônica da Ficha (AD-11)
    const todasParticipacoesSnap = await tx.get(
      db.collection('participacoes').where('fichaId', '==', fichaId),
    );

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

    // 9. Registro de Evidência de Decisão
    tx.set(evidenciaRef, {
      commandId: contexto.commandId,
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

    // 10. Auditoria Append-Only (Sem PII - AD-12)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      tipo: 'PARTICIPACAO_CANCELADA',
      participacaoId: entrada.participacaoId,
      fichaId,
      equipeId,
      papelAtor,
      novoEstadoFicha,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 11. Recibo de Idempotência
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

    if (fichaData.estado === 'CANCELADA') {
      throw new FichaJaTerminalError();
    }

    const igrejaId = String(fichaData.igrejaId ?? '');

    // 3. Determinação de Autoridade em Runtime
    let papelAtor: 'VOLUNTARIO' | 'PASTOR_LOCAL' | 'COORDENADOR' | null = null;

    const ehTitular = contexto.uid === entrada.fichaId;
    if (ehTitular) {
      papelAtor = 'VOLUNTARIO';
    } else {
      const ehCoordenador = await verificarSeCoordenador(db, contexto.uid);
      if (ehCoordenador) {
        papelAtor = 'COORDENADOR';
      } else {
        const ehPastor = await verificarSePastorLocal(db, contexto.uid, igrejaId);
        if (ehPastor) {
          papelAtor = 'PASTOR_LOCAL';
        } else {
          // Se for responsável de equipe, explicitamente NÃO possui autoridade para cancelar a ficha toda!
          const vinculoEquipeSnap = await db
            .collection('vinculosPastorEquipe')
            .where('pessoaId', '==', contexto.uid)
            .where('tipo', '==', 'EQUIPE')
            .where('estado', '==', 'VIGENTE')
            .get();

          if (!vinculoEquipeSnap.empty) {
            throw new AutoridadeInsuficienteError(
              'Responsável de equipe não tem autoridade para cancelar toda a ficha.',
            );
          }
        }
      }
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

    // 5. Busca e Atualização de Todas as Participações não terminais da Ficha
    const participacoesSnap = await tx.get(
      db.collection('participacoes').where('fichaId', '==', entrada.fichaId),
    );

    const participacoesAfetadas: string[] = [];

    for (const doc of participacoesSnap.docs) {
      const pData = doc.data() ?? {};
      if (!ESTADOS_TERMINAIS.includes(String(pData.estado))) {
        participacoesAfetadas.push(doc.id);
        const novaVersao = Number(pData.versao ?? 1) + 1;
        tx.update(doc.ref, {
          estado: 'CANCELADA',
          proximaAcao,
          canceladoPorUid: contexto.uid,
          canceladoPorPapel: papelAtor,
          versao: novaVersao,
          atualizadoEm: FieldValue.serverTimestamp(),
        });

        // Cancela ciclo associado
        const cicloId = String(pData.cicloAtualId ?? '');
        if (cicloId) {
          const cRef = db.collection('ciclos').doc(cicloId);
          const cSnap = await tx.get(cRef);
          if (cSnap.exists && !ESTADOS_TERMINAIS.includes(String(cSnap.data()?.estado))) {
            tx.update(cRef, {
              estado: 'CANCELADO',
              atualizadoEm: FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    // 6. Atualização da Ficha Permanente para CANCELADA
    tx.update(fichaRef, {
      estado: 'CANCELADA',
      proximaAcao,
      canceladoPorUid: contexto.uid,
      canceladoPorPapel: papelAtor,
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    // 7. Registro de Evidência de Decisão
    tx.set(evidenciaRef, {
      commandId: contexto.commandId,
      tipo: 'CANCELAR_VOLUNTARIADO',
      fichaId: entrada.fichaId,
      atorUid: contexto.uid,
      papelAtor,
      motivoInterno: entrada.motivo?.trim() ?? null,
      mensagemExibida: proximaAcao,
      participacoesAfetadas,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 8. Auditoria Append-Only (Sem PII - AD-12)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      tipo: 'VOLUNTARIADO_CANCELADO',
      fichaId: entrada.fichaId,
      papelAtor,
      quantidadeParticipacoesCanceladas: participacoesAfetadas.length,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 9. Recibo de Idempotência
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

import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  FichaNaoEncontradaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  normalizarEstadoParticipacao,
  type EntradaSalvarParticipacoesRascunho,
  type ParticipacaoRascunho,
} from '../domain/participacao.js';
import { classificarVigencia, type ConfiguracaoJanelaVigencia } from '../domain/vigencia.js';
import { obterConfiguracaoJanelaVigencia } from './configuracaoVigencia.js';

/** Teto de leitura das participações do voluntário (AD-9). */
const LIMITE_PARTICIPACOES_VOLUNTARIO = 100;

export interface ContextoParticipacao {
  commandId: string;
  uid: string;
}

export interface ResultadoSalvarParticipacoes {
  repetido: boolean;
  participacoes: ParticipacaoRascunho[];
}

function serializarTimestamp(valor: unknown): string | null {
  if (!valor) return null;
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof valor === 'string') return valor;
  return null;
}

function montarParticipacao(
  id: string,
  dados: Record<string, unknown>,
  configVigencia?: ConfiguracaoJanelaVigencia,
): ParticipacaoRascunho {
  const estado = normalizarEstadoParticipacao(dados.estado);
  const ehNegativa = estado === 'REJEITADA';
  const proximaAcao = ehNegativa
    ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA
    : String(dados.proximaAcao ?? (estado === 'RASCUNHO' ? 'Aguardando envio da ficha' : 'Em análise'));

  const vigenciaInicio = serializarTimestamp(dados.vigenciaInicio);
  const vigenciaFim = serializarTimestamp(dados.vigenciaFim);
  const alertaInfo =
    estado === 'ATIVA' ? classificarVigencia(Date.now(), vigenciaFim, configVigencia) : null;

  return {
    id,
    fichaId: String(dados.fichaId ?? ''),
    equipeId: String(dados.equipeId ?? ''),
    nomeEquipe: String(dados.nomeEquipe ?? ''),
    estado,
    versao: Number(dados.versao ?? 1),
    ciclo: String(dados.ciclo ?? 'INICIAL'),
    proximaAcao,
    vigenciaInicio,
    vigenciaFim,
    situacaoVigencia: alertaInfo?.situacao ?? (estado === 'EXPIRADA' ? 'EXPIRADA' : null),
    diasParaVencimento: alertaInfo?.diasRestantes ?? null,
    alertaVigencia: alertaInfo?.alerta ?? null,
    emAlertaRenovacao: alertaInfo?.emAlertaRenovacao ?? false,
    cicloAtualId: dados.cicloAtualId ? String(dados.cicloAtualId) : null,
    intencaoRenovacao: dados.intencaoRenovacao ? String(dados.intencaoRenovacao) : null,
    cicloRenovacaoId: dados.cicloRenovacaoId ? String(dados.cicloRenovacaoId) : null,
    programadoEncerramentoEm: serializarTimestamp(dados.programadoEncerramentoEm),
    criadoEm: serializarTimestamp(dados.criadoEm),
    atualizadoEm: serializarTimestamp(dados.atualizadoEm),
  };
}

/**
 * Consulta as participações cadastradas para o voluntário autenticado.
 */
export async function obterMinhasParticipacoesRepo(
  db: Firestore,
  uid: string,
): Promise<ParticipacaoRascunho[]> {
  const snapshot = await db
    .collection('participacoes')
    .where('fichaId', '==', uid)
    .limit(LIMITE_PARTICIPACOES_VOLUNTARIO)
    .get();

  const configVigencia = await obterConfiguracaoJanelaVigencia(db);

  return snapshot.docs
    .map((doc) => montarParticipacao(doc.id, doc.data(), configVigencia))
    .sort((a, b) => a.nomeEquipe.localeCompare(b.nomeEquipe));
}

/**
 * Reconcilia transacionalmente as participações em RASCUNHO do voluntário com a lista de equipes selecionadas.
 * - Valida se a ficha permanente existe.
 * - Valida se todas as equipes selecionadas existem e estão ativas.
 * - Garante idempotência via recibo em `commands`.
 * - Grava evento em `auditOutbox`.
 * - Não afeta participações fora do estado RASCUNHO (AD-4).
 */
export async function salvarParticipacoesRascunhoRepo(
  db: Firestore,
  contexto: ContextoParticipacao,
  entrada: EntradaSalvarParticipacoesRascunho,
): Promise<ResultadoSalvarParticipacoes> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(contexto.uid);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em `commands`
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid !== contexto.uid) {
        throw new Error('Operação indisponível para o usuário informado.');
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const snap = await tx.get(
        db.collection('participacoes').where('fichaId', '==', contexto.uid),
      );
      const participacoes = snap.docs
        .map((doc) => montarParticipacao(doc.id, doc.data()))
        .sort((a, b) => a.nomeEquipe.localeCompare(b.nomeEquipe));
      return {
        repetido: true,
        participacoes,
      };
    }

    // 2. Ficha permanente deve existir
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }

    // 3. Validação de cada equipe informada
    const equipesDocs: Array<{ id: string; nome: string }> = [];
    for (const equipeId of entrada.equipeIds) {
      const equipeRef = db.collection('equipes').doc(equipeId);
      const equipeSnap = await tx.get(equipeRef);
      if (!equipeSnap.exists || equipeSnap.data()?.ativo !== true) {
        throw new EquipeInvalidaError();
      }
      equipesDocs.push({
        id: equipeId,
        nome: String(equipeSnap.data()?.nome ?? ''),
      });
    }

    // 4. Ler participações existentes
    const participacoesSnap = await tx.get(
      db.collection('participacoes').where('fichaId', '==', contexto.uid),
    );

    const existentes = participacoesSnap.docs.map((doc) => ({
      docRef: doc.ref,
      id: doc.id,
      data: doc.data(),
    }));

    const resultadoFinal: ParticipacaoRascunho[] = [];
    const idsMantidosOuCriados: string[] = [];

    // Remover apenas as que estão em RASCUNHO e não estão na nova lista de equipeIds
    for (const p of existentes) {
      const estado = String(p.data.estado ?? '');
      const equipeId = String(p.data.equipeId ?? '');
      if (estado === 'RASCUNHO') {
        if (!entrada.equipeIds.includes(equipeId)) {
          tx.delete(p.docRef);
        } else {
          idsMantidosOuCriados.push(p.id);
          resultadoFinal.push(montarParticipacao(p.id, p.data));
        }
      } else {
        // Preserva decisões, históricos e participações não-rascunho
        resultadoFinal.push(montarParticipacao(p.id, p.data));
      }
    }

    // Criar as novas participações para equipeIds que ainda não têm documento em RASCUNHO
    for (const eq of equipesDocs) {
      const jaExiste = existentes.some(
        (p) =>
          String(p.data.equipeId ?? '') === eq.id &&
          String(p.data.estado ?? '') === 'RASCUNHO',
      );
      if (!jaExiste) {
        const novaRef = db.collection('participacoes').doc();
        const novaData = {
          fichaId: contexto.uid,
          equipeId: eq.id,
          nomeEquipe: eq.nome,
          estado: 'RASCUNHO',
          ciclo: 'INICIAL',
          proximaAcao: 'Aguardando envio da ficha',
          criadoEm: FieldValue.serverTimestamp(),
          atualizadoEm: FieldValue.serverTimestamp(),
        };
        tx.set(novaRef, novaData);
        idsMantidosOuCriados.push(novaRef.id);
        resultadoFinal.push(montarParticipacao(novaRef.id, novaData));
      }
    }

    resultadoFinal.sort((a, b) => a.nomeEquipe.localeCompare(b.nomeEquipe));

    // 5. Registrar recibo em commands
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.commandId,
      uid: contexto.uid,
      action: 'SALVAR_PARTICIPACOES_RASCUNHO',
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      equipeIds: entrada.equipeIds,
      participacoesIds: idsMantidosOuCriados,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 6. Registrar evento em auditOutbox
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.commandId,
      actorUid: contexto.uid,
      action: 'PARTICIPACOES_RASCUNHO_SALVAS',
      fichaId: contexto.uid,
      equipeIds: entrada.equipeIds,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      repetido: false,
      participacoes: resultadoFinal,
    };
  });
}

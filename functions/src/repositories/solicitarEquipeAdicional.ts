import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  EquipeJaSolicitadaError,
  FichaNaoAtivaError,
  FichaNaoEncontradaError,
  PermissaoNegadaError,
  TermoInvalidoError,
  type EntradaSolicitarEquipeAdicional,
  type ResultadoSolicitarEquipeAdicional,
} from '../domain/solicitarEquipeAdicional.js';
import {
  ESTADOS_PARTICIPACAO,
  ESTADOS_TERMINAIS_PARTICIPACAO,
} from '../domain/participacao.js';
import { TERMO_ID_PADRAO } from '../domain/termos.js';

export interface ContextoSolicitarEquipe {
  commandId: string;
  correlationId?: string;
  uid: string;
}

/** Teto de leitura das participações do voluntário na transação (AD-9). */
const LIMITE_PARTICIPACOES_VOLUNTARIO = 100;

/**
 * Estados que impedem nova solicitação, derivados do catálogo canônico
 * (`ESTADOS_PARTICIPACAO`) para não divergir quando novos estados forem criados.
 */
const ESTADOS_NAO_TERMINAIS_PARTICIPACAO: readonly string[] = (
  ESTADOS_PARTICIPACAO as readonly string[]
).filter((estado) => !ESTADOS_TERMINAIS_PARTICIPACAO.includes(estado));

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
 * Transação atômica que permite a um voluntário com ficha ATIVA solicitar adesão
 * a uma nova equipe administrável do catálogo.
 *
 * Invariantes (AD-4, AD-11, Spine e PRD Seção 24):
 * 1. Participações já ativas permanecem integralmente ativas e inalteradas.
 * 2. O estado geral da ficha permanece ATIVA.
 * 3. Criação de nova participação e novo ciclo de aprovação independentes.
 * 4. A nova participação ingressa em AGUARDANDO_RESPONSAVEL_EQUIPE.
 * 5. Rejeita equipes inativas, inexistentes ou duplicadas não-terminais.
 * 6. Idempotência em commands e evento de auditoria em auditOutbox no mesmo commit lógico.
 */
export async function solicitarEquipeAdicionalRepo(
  db: Firestore,
  contexto: ContextoSolicitarEquipe,
  entrada: EntradaSolicitarEquipeAdicional,
): Promise<ResultadoSolicitarEquipeAdicional> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(contexto.uid);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Verificação de Idempotência
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new PermissaoNegadaError();
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        participacaoId: String(res?.participacaoId ?? ''),
        cicloId: String(res?.cicloId ?? ''),
        equipeId: String(res?.equipeId ?? entrada.equipeId),
        nomeEquipe: String(res?.nomeEquipe ?? ''),
        estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        proximaAcao: String(res?.proximaAcao ?? 'Aguardando avaliação do Responsável de Equipe'),
        criadoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e Validação da Ficha Permanente
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};

    if (fichaData.estado !== 'ATIVA') {
      throw new FichaNaoAtivaError();
    }

    // Validação do termo vigente aceito
    const termoAceito = fichaData.termoAceito as Record<string, unknown> | undefined;
    if (!termoAceito || !termoAceito.versaoId) {
      throw new TermoInvalidoError('Ficha sem termo de voluntariado registrado.');
    }

    const termoId = String(termoAceito.termoId || TERMO_ID_PADRAO);
    const termoSnap = await tx.get(db.collection('termos').doc(termoId));
    if (!termoSnap.exists || termoSnap.data()?.ativo !== true) {
      throw new TermoInvalidoError('Termo de voluntariado inativo ou não encontrado.');
    }
    const termoData = termoSnap.data() ?? {};
    if (termoData.versaoVigenteId !== termoAceito.versaoId) {
      throw new TermoInvalidoError('O termo aceito não corresponde à versão vigente.');
    }

    // 3. Leitura e Validação da Equipe Solicitada
    const equipeRef = db.collection('equipes').doc(entrada.equipeId);
    const equipeSnap = await tx.get(equipeRef);
    if (!equipeSnap.exists || equipeSnap.data()?.ativo !== true) {
      throw new EquipeInvalidaError();
    }
    const equipeData = equipeSnap.data() ?? {};
    const nomeEquipe = String(equipeData.nome ?? entrada.equipeId);

    // 4. Validação de Duplicidade nas Participações do Voluntário
    const participacoesSnap = await tx.get(
      db
        .collection('participacoes')
        .where('fichaId', '==', contexto.uid)
        .limit(LIMITE_PARTICIPACOES_VOLUNTARIO),
    );

    const participacoesDocs = participacoesSnap.docs ?? [];
    for (const doc of participacoesDocs) {
      const p = doc.data() ?? {};
      if (String(p.equipeId ?? '') === entrada.equipeId) {
        const estadoAtual = String(p.estado ?? '');
        if ((ESTADOS_NAO_TERMINAIS_PARTICIPACAO as readonly string[]).includes(estadoAtual)) {
          throw new EquipeJaSolicitadaError();
        }
      }
    }

    // 5. Criação Atômica de Nova Participação e Ciclo Independente
    const novaPartRef = db.collection('participacoes').doc();
    const participacaoId = novaPartRef.id;
    const anoAtual = new Date().getUTCFullYear();
    const cicloId = `ciclo_${participacaoId}_${anoAtual}`;
    const cicloRef = db.collection('ciclos').doc(cicloId);

    const agora = FieldValue.serverTimestamp();
    const proximaAcao = 'Aguardando avaliação do Responsável de Equipe';

    // Criação do Ciclo
    tx.set(cicloRef, {
      id: cicloId,
      participacaoId,
      fichaId: contexto.uid,
      equipeId: entrada.equipeId,
      nomeEquipe,
      voluntarioUid: contexto.uid,
      anoVigencia: anoAtual,
      tipo: 'NOVA_EQUIPE',
      estado: 'EM_APROVACAO',
      criadoEm: agora,
      atualizadoEm: agora,
    });

    // Criação da Participação
    tx.set(novaPartRef, {
      fichaId: contexto.uid,
      equipeId: entrada.equipeId,
      nomeEquipe,
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao,
      cicloAtualId: cicloId,
      versao: 1,
      criadoEm: agora,
      atualizadoEm: agora,
    });

    const resultadoOperacao = {
      sucesso: true,
      repetido: false,
      participacaoId,
      cicloId,
      equipeId: entrada.equipeId,
      nomeEquipe,
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE' as const,
      proximaAcao,
    };

    // 6. Recibo Idempotente em commands
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      correlationId: entrada.correlationId ?? contexto.commandId,
      uid: contexto.uid,
      action: 'SOLICITAR_EQUIPE_ADICIONAL',
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      equipeId: entrada.equipeId,
      participacaoId,
      cicloId,
      resultado: resultadoOperacao,
      criadoEm: agora,
    });

    // 7. Registro Append-Only em auditOutbox
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: entrada.correlationId ?? contexto.commandId,
      actorUid: contexto.uid,
      action: 'SOLICITAR_EQUIPE_ADICIONAL',
      fichaId: contexto.uid,
      participacaoId,
      equipeId: entrada.equipeId,
      cicloId,
      criadoEm: agora,
    });

    return {
      ...resultadoOperacao,
      criadoEm: new Date().toISOString(),
    };
  });
}

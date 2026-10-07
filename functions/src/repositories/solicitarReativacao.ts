import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  EquipeJaEmAndamentoError,
  FichaNaoElegivelParaReativacaoError,
  FichaNaoEncontradaError,
  ParticipacaoNaoEncontradaError,
  ParticipacaoNaoTerminalError,
  PermissaoNegadaError,
  TermoInvalidoError,
  type EntradaSolicitarReativacao,
  type ResultadoSolicitarReativacao,
} from '../domain/solicitarReativacao.js';
import { ESTADOS_PARTICIPACAO } from '../domain/participacao.js';
import { TERMO_ID_PADRAO } from '../domain/termos.js';

export interface ContextoSolicitarReativacao {
  commandId: string;
  correlationId?: string;
  uid: string;
}

const LIMITE_PARTICIPACOES_VOLUNTARIO = 100;

export const ESTADOS_TERMINAIS_PARTICIPACAO = [
  'REJEITADA',
  'CANCELADA',
  'EXPIRADA',
  'INATIVA',
];

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
 * Transação atômica que processa a solicitação de reativação pelo próprio voluntário.
 *
 * Invariantes (AD-1, AD-4, AD-10, AD-11, AD-12):
 * 1. Não reativa magicamente a participação anterior: preserva seu documento e histórico imutáveis (append-only).
 * 2. Cria nova participação (com participacaoAnteriorId) e novo ciclo (tipo: 'REATIVACAO').
 * 3. A nova participação ingressa em AGUARDANDO_PASTOR_LOCAL para iniciar a cadeia completa.
 * 4. Ficha inativa/cancelada transiciona para AGUARDANDO_PASTOR_LOCAL; se já ATIVA (por outra equipe), permanece ATIVA.
 * 5. Rejeita solicitações se houver ciclo não terminal em andamento na mesma equipe.
 * 6. Grava evidências sem PII em evidenciasDecisao e auditoria em auditOutbox no mesmo commit atômico.
 */
export async function solicitarReativacaoRepo(
  db: Firestore,
  contexto: ContextoSolicitarReativacao,
  entrada: EntradaSolicitarReativacao,
): Promise<ResultadoSolicitarReativacao> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(contexto.uid);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);
  const filaRef = db.collection('filaPendencias').doc(contexto.uid);

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
        participacaoAnteriorId: res?.participacaoAnteriorId
          ? String(res.participacaoAnteriorId)
          : undefined,
        cicloId: String(res?.cicloId ?? ''),
        equipeId: String(res?.equipeId ?? entrada.equipeId),
        nomeEquipe: String(res?.nomeEquipe ?? ''),
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        proximaAcao: String(res?.proximaAcao ?? 'Aguardando avaliação do Pastor Local'),
        criadoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e Validação da Ficha
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};

    // Validação de Termo Vigente
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

    // 3. Validação da Participação Anterior (se indicada)
    let participacaoAnteriorSnap;
    if (entrada.participacaoId) {
      const partAntigaRef = db.collection('participacoes').doc(entrada.participacaoId);
      participacaoAnteriorSnap = await tx.get(partAntigaRef);
      if (!participacaoAnteriorSnap.exists) {
        throw new ParticipacaoNaoEncontradaError();
      }
      const pAntigaData = participacaoAnteriorSnap.data() ?? {};
      if (pAntigaData.fichaId !== contexto.uid) {
        throw new PermissaoNegadaError();
      }
      const estadoAntigo = String(pAntigaData.estado ?? '');
      if (!ESTADOS_TERMINAIS_PARTICIPACAO.includes(estadoAntigo)) {
        throw new ParticipacaoNaoTerminalError();
      }
    } else {
      // Se não indicou participação específica, a ficha deve estar em estado terminal
      const estadoFicha = String(fichaData.estado ?? '');
      if (!['CANCELADA', 'INATIVA', 'EXPIRADA'].includes(estadoFicha)) {
        throw new FichaNaoElegivelParaReativacaoError();
      }
    }

    // 4. Validação da Equipe Solicitada
    const equipeRef = db.collection('equipes').doc(entrada.equipeId);
    const equipeSnap = await tx.get(equipeRef);
    if (!equipeSnap.exists || equipeSnap.data()?.ativo !== true) {
      throw new EquipeInvalidaError();
    }
    const equipeData = equipeSnap.data() ?? {};
    const nomeEquipe = String(equipeData.nome ?? entrada.equipeId);

    // 5. Validação de Ausência de Ciclo Não Terminal em Andamento
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
          throw new EquipeJaEmAndamentoError();
        }
      }
    }

    // 6. Criação Atômica de Nova Participação e Novo Ciclo (Append-only)
    const agora = FieldValue.serverTimestamp();
    const novaPartRef = db.collection('participacoes').doc();
    const participacaoId = novaPartRef.id;
    const anoAtual = new Date().getUTCFullYear();
    const cicloId = `ciclo_${participacaoId}_${anoAtual}`;
    const cicloRef = db.collection('ciclos').doc(cicloId);
    const proximaAcao = 'Aguardando avaliação do Pastor Local';

    // Criação do Ciclo
    tx.set(cicloRef, {
      id: cicloId,
      participacaoId,
      participacaoAnteriorId: entrada.participacaoId ?? null,
      fichaId: contexto.uid,
      equipeId: entrada.equipeId,
      nomeEquipe,
      voluntarioUid: contexto.uid,
      anoVigencia: anoAtual,
      tipo: 'REATIVACAO',
      estado: 'EM_APROVACAO',
      justificativa: entrada.justificativa ?? null,
      criadoEm: agora,
      atualizadoEm: agora,
    });

    // Criação da Nova Participação
    tx.set(novaPartRef, {
      fichaId: contexto.uid,
      equipeId: entrada.equipeId,
      nomeEquipe,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      ciclo: 'REATIVACAO',
      proximaAcao,
      cicloAtualId: cicloId,
      participacaoAnteriorId: entrada.participacaoId ?? null,
      versao: 1,
      criadoEm: agora,
      atualizadoEm: agora,
    });

    // Atualização da Ficha (AD-11)
    const estadoFichaAtual = String(fichaData.estado ?? '');
    const versaoFichaAtual = Number(fichaData.versao ?? 1);
    const novoEstadoFicha =
      estadoFichaAtual === 'ATIVA' ? 'ATIVA' : 'AGUARDANDO_PASTOR_LOCAL';

    tx.update(fichaRef, {
      estado: novoEstadoFicha,
      proximaAcao:
        novoEstadoFicha === 'ATIVA'
          ? 'Voluntariado ativo (reativação pendente de aprovação)'
          : proximaAcao,
      versao: versaoFichaAtual + 1,
      atualizadoEm: agora,
    });

    // Atualização da Projeção de Pendências do Pastor Local
    const nomeVoluntario =
      String(
        (fichaData.dadosPessoais as Record<string, unknown> | undefined)?.nomeCompleto ??
          fichaData.nomeCompleto ??
          'Voluntário',
      );
    const igrejaId = String(fichaData.igrejaId ?? '');

    tx.set(
      filaRef,
      {
        fichaId: contexto.uid,
        voluntarioUid: contexto.uid,
        voluntarioNome: nomeVoluntario,
        igrejaId,
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        proximaAcao,
        ano: anoAtual,
        equipes: [
          {
            equipeId: entrada.equipeId,
            nomeEquipe,
            reativacao: true,
          },
        ],
        enviadoEm: agora,
      },
      { merge: true },
    );

    const resultadoOperacao = {
      sucesso: true,
      repetido: false,
      participacaoId,
      participacaoAnteriorId: entrada.participacaoId,
      cicloId,
      equipeId: entrada.equipeId,
      nomeEquipe,
      estado: 'AGUARDANDO_PASTOR_LOCAL' as const,
      proximaAcao,
    };

    // 7. Registro de Evidência Append-Only
    tx.set(evidenciaRef, {
      commandId: contexto.commandId,
      fichaId: contexto.uid,
      participacaoId,
      participacaoAnteriorId: entrada.participacaoId ?? null,
      equipeId: entrada.equipeId,
      etapa: 'SOLICITACAO_REATIVACAO',
      decisao: 'SOLICITADO',
      atorUid: contexto.uid,
      papel: 'VOLUNTARIO',
      justificativa: entrada.justificativa ?? null,
      timestamp: agora,
    });

    // 8. Registro em auditOutbox
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: entrada.correlationId ?? contexto.commandId,
      actorUid: contexto.uid,
      action: 'SOLICITAR_REATIVACAO',
      fichaId: contexto.uid,
      participacaoId,
      participacaoAnteriorId: entrada.participacaoId ?? null,
      equipeId: entrada.equipeId,
      cicloId,
      criadoEm: agora,
    });

    // 9. Recibo Idempotente em commands
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      correlationId: entrada.correlationId ?? contexto.commandId,
      uid: contexto.uid,
      action: 'SOLICITAR_REATIVACAO',
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      equipeId: entrada.equipeId,
      participacaoId,
      participacaoAnteriorId: entrada.participacaoId ?? null,
      cicloId,
      resultado: resultadoOperacao,
      criadoEm: agora,
    });

    return {
      ...resultadoOperacao,
      criadoEm: new Date().toISOString(),
    };
  });
}

import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  classificarVigencia,
  ComandoDivergenteError,
  FichaNaoEncontradaError,
  JanelaRenovacaoFechadaError,
  ParticipacaoNaoElegivelError,
  ParticipacaoNaoEncontradaError,
  PermissaoNegadaError,
  type DetalheResultadoRenovacaoItem,
  type EntradaManifestarRenovacao,
  type ResultadoManifestarRenovacao,
} from '../domain/manifestarRenovacao.js';
import { obterConfiguracaoJanelaVigencia } from './configuracaoVigencia.js';

export interface ContextoManifestarRenovacao {
  commandId: string;
  correlationId?: string;
  uid: string;
}

function iso(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return String(valor);
}

function timestampParaDate(valor: unknown): Date | null {
  if (!valor) return null;
  if (valor instanceof Timestamp) return valor.toDate();
  if (valor instanceof Date) return valor;
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate();
  }
  if (typeof valor === 'string' || typeof valor === 'number') {
    const d = new Date(valor);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * Processamento transacional da manifestação de renovação por equipe (Story 5.2).
 * Respeita AD-7, AD-8, AD-10, AD-11 e AD-12.
 */
export async function executarManifestarRenovacaoRepo(
  db: Firestore,
  contexto: ContextoManifestarRenovacao,
  entrada: EntradaManifestarRenovacao,
): Promise<ResultadoManifestarRenovacao> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const configVigencia = await obterConfiguracaoJanelaVigencia(db);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência em nível de comando
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new PermissaoNegadaError();
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = (dadosRecibo.resultado ?? {}) as Record<string, unknown>;
      return {
        sucesso: true,
        repetido: true,
        commandId: contexto.commandId,
        itens: (res.itens ?? []) as DetalheResultadoRenovacaoItem[],
        processadoEm: iso(dadosRecibo.criadoEm ?? res.processadoEm),
      };
    }

    const agoraDate = new Date();
    const agoraTs = Timestamp.fromDate(agoraDate);

    // 2. Leitura da ficha para validação de posse e igreja
    const fichaRef = db.collection('fichas').doc(contexto.uid);
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};
    const igrejaId = String(fichaData.igrejaId ?? '');
    const nomeVoluntario = String(
      (fichaData.dadosPessoais as Record<string, unknown> | undefined)?.nomeCompleto ??
        fichaData.nomeCompleto ??
        'Voluntário',
    );

    // 3. Leituras de todas as participações envolvidas e seus ciclos potenciais
    const participacoesParaAtualizar: Array<{
      item: (typeof entrada.manifestacoes)[0];
      partRef: DocumentReference;
      partData: Record<string, unknown>;
      anoVigencia: number;
      cicloId: string;
      cicloRef: DocumentReference;
      cicloSnapExists: boolean;
      cicloData: Record<string, unknown>;
    }> = [];

    for (const item of entrada.manifestacoes) {
      const partRef = db.collection('participacoes').doc(item.participacaoId);
      const partSnap = await tx.get(partRef);
      if (!partSnap.exists) {
        throw new ParticipacaoNaoEncontradaError(`Participação ${item.participacaoId} não encontrada.`);
      }

      const partData = partSnap.data() ?? {};

      // Invariante de Posse (AD-9)
      if (String(partData.fichaId ?? '') !== contexto.uid) {
        throw new PermissaoNegadaError(`A participação ${item.participacaoId} não pertence ao voluntário autenticado.`);
      }

      // Invariante de Elegibilidade (AD-11: deve estar ATIVA)
      if (partData.estado !== 'ATIVA') {
        throw new ParticipacaoNaoElegivelError(
          `Participação ${item.participacaoId} está em estado '${partData.estado}', não elegível para renovação.`,
        );
      }

      // Invariante de Janela Temporal (Story 5.1 / AD-7)
      const vigenciaFimDate = timestampParaDate(partData.vigenciaFim);
      const classificacao = classificarVigencia(agoraDate, vigenciaFimDate, configVigencia);

      if (!classificacao.janelaRenovacaoAberta) {
        throw new JanelaRenovacaoFechadaError(
          `A janela de renovação para a equipe '${partData.nomeEquipe ?? partData.equipeId}' não está aberta.`,
        );
      }

      // Determinação determinística do ano de vigência pretendido
      const anoVigencia = vigenciaFimDate
        ? vigenciaFimDate.getUTCFullYear()
        : agoraDate.getUTCFullYear() + 1;

      // Chave determinística de ciclo (AD-11)
      const cicloId = `ciclo_${item.participacaoId}_${anoVigencia}`;
      const cicloRef = db.collection('ciclos').doc(cicloId);
      const cicloSnap = await tx.get(cicloRef);

      participacoesParaAtualizar.push({
        item,
        partRef,
        partData,
        anoVigencia,
        cicloId,
        cicloRef,
        cicloSnapExists: cicloSnap.exists,
        cicloData: cicloSnap.exists ? (cicloSnap.data() ?? {}) : {},
      });
    }

    // 4. Execução de Mutações
    const itensResultado: DetalheResultadoRenovacaoItem[] = [];
    const equipesAguardandoPastor: Array<{ equipeId: string; nomeEquipe: string }> = [];

    for (const info of participacoesParaAtualizar) {
      const { item, partRef, partData, anoVigencia, cicloId, cicloRef, cicloSnapExists } = info;
      const equipeId = String(partData.equipeId ?? '');
      const nomeEquipe = String(partData.nomeEquipe ?? equipeId);
      const versaoPart = Number(partData.versao ?? 1);

      if (item.decisao === 'CONTINUAR') {
        // Criar ou atualizar o ciclo determinístico
        if (!cicloSnapExists) {
          tx.set(cicloRef, {
            id: cicloId,
            participacaoId: item.participacaoId,
            fichaId: contexto.uid,
            equipeId,
            nomeEquipe,
            voluntarioUid: contexto.uid,
            anoVigencia,
            tipo: 'RENOVACAO_ANUAL',
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            justificativa: item.justificativa ?? null,
            criadoEm: agoraTs,
            atualizadoEm: agoraTs,
          });
        } else {
          tx.update(cicloRef, {
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            justificativa: item.justificativa ?? null,
            atualizadoEm: agoraTs,
          });
        }

        const proximaAcao = 'Aguardando avaliação do Pastor Local (Ciclo Anual)';

        tx.update(partRef, {
          cicloRenovacaoId: cicloId,
          intencaoRenovacao: 'CONTINUAR',
          proximaAcao,
          versao: versaoPart + 1,
          atualizadoEm: agoraTs,
        });

        equipesAguardandoPastor.push({ equipeId, nomeEquipe });

        itensResultado.push({
          participacaoId: item.participacaoId,
          equipeId,
          nomeEquipe,
          decisao: 'CONTINUAR',
          cicloId,
          anoVigencia,
          estadoCiclo: 'AGUARDANDO_PASTOR_LOCAL',
          proximaAcao,
        });
      } else {
        // Decisão NAO_CONTINUAR
        if (cicloSnapExists) {
          tx.update(cicloRef, {
            estado: 'CANCELADO',
            atualizadoEm: agoraTs,
          });
        }

        const proximaAcao = 'Encerramento programado ao término da vigência';

        tx.update(partRef, {
          intencaoRenovacao: 'NAO_CONTINUAR',
          programadoEncerramentoEm: partData.vigenciaFim ?? null,
          proximaAcao,
          versao: versaoPart + 1,
          atualizadoEm: agoraTs,
        });

        itensResultado.push({
          participacaoId: item.participacaoId,
          equipeId,
          nomeEquipe,
          decisao: 'NAO_CONTINUAR',
          cicloId: null,
          anoVigencia: null,
          estadoCiclo: null,
          proximaAcao,
        });
      }

      // Evento append-only da Ficha
      const subCommandId = `${contexto.commandId}_${item.participacaoId}`;
      const eventoRef = db
        .collection('fichas')
        .doc(contexto.uid)
        .collection('eventos')
        .doc(subCommandId);

      tx.set(eventoRef, {
        commandId: subCommandId,
        tipo: 'MANIFESTACAO_RENOVACAO',
        participacaoId: item.participacaoId,
        equipeId,
        nomeEquipe,
        decisao: item.decisao,
        data: agoraTs,
      });

      // Evidência Imutável (AD-8 / AD-12)
      const evidenciaRef = db.collection('evidenciasDecisao').doc(subCommandId);
      tx.set(evidenciaRef, {
        commandId: subCommandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'MANIFESTACAO_RENOVACAO',
        fichaId: contexto.uid,
        participacaoId: item.participacaoId,
        equipeId,
        decisao: item.decisao,
        justificativa: item.justificativa ?? null,
        criadoEm: agoraTs,
      });
    }

    // 5. Atualização da fila de pendências do Pastor Local se houver 'CONTINUAR'
    if (equipesAguardandoPastor.length > 0) {
      const filaRef = db.collection('filaPendencias').doc(contexto.uid);
      tx.set(
        filaRef,
        {
          fichaId: contexto.uid,
          voluntarioUid: contexto.uid,
          voluntarioNome: nomeVoluntario,
          igrejaId,
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          proximaAcao: 'Aguardando avaliação do Pastor Local (Ciclo Anual)',
          ano: agoraDate.getUTCFullYear(),
          equipesRenovacao: equipesAguardandoPastor,
          atualizadoEm: agoraTs,
        },
        { merge: true },
      );
    }

    // 6. Registro no auditOutbox (AD-8)
    const auditRef = db.collection('auditOutbox').doc(contexto.commandId);
    tx.set(auditRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      tipo: 'MANIFESTACAO_RENOVACAO',
      entidade: 'fichas',
      entidadeId: contexto.uid,
      atorUid: contexto.uid,
      payloadHash: entrada.payloadHash,
      itensCount: entrada.manifestacoes.length,
      criadoEm: agoraTs,
      processado: false,
    });

    const resultadoOperacao: ResultadoManifestarRenovacao = {
      sucesso: true,
      repetido: false,
      commandId: contexto.commandId,
      itens: itensResultado,
      processadoEm: agoraDate.toISOString(),
    };

    // 7. Recibo do comando (AD-10)
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      uid: contexto.uid,
      tipo: 'manifestarRenovacao',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado: resultadoOperacao,
      criadoEm: agoraTs,
    });

    return resultadoOperacao;
  });
}

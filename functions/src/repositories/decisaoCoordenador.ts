import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  FichaNaoAguardandoCoordenadorError,
  FichaNaoEncontradaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  SemAutoridadeCoordenadorError,
  type EntradaDecidirAtivacaoCoordenador,
  type ItemFilaCoordenador,
  type ParticipacaoFilaCoordenador,
  type ResultadoDecidirAtivacaoCoordenador,
  type ResultadoFilaCoordenador,
} from '../domain/decisaoCoordenador.js';
import {
  PAPEL_ADMINISTRADOR,
  PAPEL_COORDENADOR,
  podeAdministrar,
  possuiPapel,
} from '../domain/autoridadeAdministrativa.js';
import { calcularVigenciaAnual } from '../domain/vigencia.js';

export interface ContextoDecisaoCoordenador {
  commandId: string;
  correlationId?: string;
  coordenadorUid: string;
}

/** Teto de leitura da fila e das participações por ficha (AD-9). */
const LIMITE_FILA_COORDENADOR = 100;
const LIMITE_PARTICIPACOES_FICHA = 100;

const ESTADOS_PENDENTES = [
  'RASCUNHO',
  'AGUARDANDO_PASTOR_LOCAL',
  'AGUARDANDO_RESPONSAVEL_EQUIPE',
  'AGUARDANDO_COORDENADOR',
];

export interface AutoridadeCoordenador {
  autorizado: boolean;
  nome: string;
  papel: string;
  autoridadeVersao: number;
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

function mascararCpf(cpfRaw: unknown): string {
  const cpf = String(cpfRaw ?? '').replace(/\D/g, '');
  if (cpf.length === 11) {
    return `${cpf.slice(0, 3)}.***.***-${cpf.slice(9)}`;
  }
  return '***.***.***-**';
}

/**
 * Avalia a autoridade do Coordenador Geral a partir do agregado canônico
 * `autoridadesAdministrativas` (AD-1, AD-2, AD-9). `coordenadores` e
 * `pessoas` deixam de ser fontes de autorização para não manter uma segunda
 * fonte de verdade revogável fora do agregado canônico.
 */
export function avaliarAutoridadeCoordenador(
  autoridadeData: unknown,
  pessoaNome: string,
): AutoridadeCoordenador {
  const administrador = podeAdministrar(autoridadeData);
  const coordenador = possuiPapel(autoridadeData, PAPEL_COORDENADOR);
  if (!administrador && !coordenador) {
    return {
      autorizado: false,
      nome: 'Desconhecido',
      papel: '',
      autoridadeVersao: 0,
    };
  }
  const dados = (autoridadeData ?? {}) as Record<string, unknown>;
  return {
    autorizado: true,
    nome: pessoaNome,
    papel: administrador ? PAPEL_ADMINISTRADOR : PAPEL_COORDENADOR,
    autoridadeVersao: Number(dados.versao ?? dados.revisao ?? 0),
  };
}

async function lerAutoridadeCoordenador(
  db: Firestore,
  uid: string,
  getDoc: (ref: DocumentReference) => Promise<DocumentSnapshot>,
): Promise<AutoridadeCoordenador> {
  const [autoridadeSnap, pessoaSnap] = await Promise.all([
    getDoc(db.collection('autoridadesAdministrativas').doc(uid)),
    getDoc(db.collection('pessoas').doc(uid)),
  ]);
  const nome = pessoaSnap.exists
    ? String(pessoaSnap.data()?.nomeCompleto ?? 'Coordenador Geral')
    : 'Coordenador Geral';
  return avaliarAutoridadeCoordenador(
    autoridadeSnap.exists ? autoridadeSnap.data() : undefined,
    nome,
  );
}

export function validarAutoridadeCoordenador(
  db: Firestore,
  uid: string,
): Promise<AutoridadeCoordenador> {
  return lerAutoridadeCoordenador(db, uid, (ref) => ref.get());
}

/**
 * Reavaliação dentro da transação (AD-2: vínculo/papel vigente no instante da
 * transação), fechando a janela TOCTOU entre o pré-check e o commit.
 */
function validarAutoridadeCoordenadorTx(
  db: Firestore,
  tx: Transaction,
  uid: string,
): Promise<AutoridadeCoordenador> {
  return lerAutoridadeCoordenador(db, uid, (ref) => tx.get(ref));
}

/**
 * Redução canônica do estado da Ficha (AD-11): `ATIVA` se houver ao menos uma
 * participação ativa; senão, permanece pendente se ainda existir participação
 * não terminal; senão `REJEITADA`.
 */
export function reduzirEstadoFicha(estados: string[]): {
  estado: string;
  proximaAcao: string;
} {
  if (estados.some((e) => e === 'ATIVA')) {
    return { estado: 'ATIVA', proximaAcao: 'Voluntariado ativo' };
  }
  if (estados.some((e) => ESTADOS_PENDENTES.includes(e))) {
    return {
      estado: 'AGUARDANDO_COORDENADOR',
      proximaAcao: 'Aguardando conclusão do Coordenador',
    };
  }
  return {
    estado: 'REJEITADA',
    proximaAcao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  };
}

/**
 * Consulta a fila de solicitações elegíveis à etapa de coordenação. Só lista
 * fichas cujo estado consolidado é `AGUARDANDO_COORDENADOR`, garantindo que
 * todas as pendências das equipes já foram resolvidas (Story 3.2).
 */
export async function obterFilaCoordenadorRepo(
  db: Firestore,
  coordenadorUid: string,
): Promise<ResultadoFilaCoordenador> {
  const autoridade = await validarAutoridadeCoordenador(db, coordenadorUid);
  if (!autoridade.autorizado) {
    throw new SemAutoridadeCoordenadorError();
  }

  const participacoesSnap = await db
    .collection('participacoes')
    .where('estado', '==', 'AGUARDANDO_COORDENADOR')
    .limit(LIMITE_FILA_COORDENADOR)
    .get();

  if (participacoesSnap.empty) {
    return { pendencias: [] };
  }

  const fichaIdsSet = new Set<string>();
  for (const doc of participacoesSnap.docs) {
    const fichaId = String(doc.data()?.fichaId ?? '');
    if (fichaId) fichaIdsSet.add(fichaId);
  }

  const pendencias: ItemFilaCoordenador[] = [];
  const igrejasCache = new Map<string, string>();
  const equipesCache = new Map<string, string>();

  for (const fichaId of fichaIdsSet) {
    const fichaDoc = await db.collection('fichas').doc(fichaId).get();
    if (!fichaDoc.exists) continue;

    const fData = fichaDoc.data() ?? {};
    const estadoFichaAtual = String(fData.estado ?? '');
    // A elegibilidade da fila é determinada pelo estado da participação; uma
    // ficha ATIVA pode ter equipes adicionais aguardando o Coordenador (Story 4.2).
    if (estadoFichaAtual !== 'AGUARDANDO_COORDENADOR' && estadoFichaAtual !== 'ATIVA') {
      continue;
    }

    const igrejaId = String(fData.igrejaId ?? '');

    let nomeIgreja = igrejasCache.get(igrejaId);
    if (!nomeIgreja && igrejaId) {
      const igDoc = await db.collection('igrejas').doc(igrejaId).get();
      nomeIgreja = igDoc.exists ? String(igDoc.data()?.nome ?? igrejaId) : igrejaId;
      igrejasCache.set(igrejaId, nomeIgreja);
    }

    const todasPartSnap = await db
      .collection('participacoes')
      .where('fichaId', '==', fichaId)
      .limit(LIMITE_PARTICIPACOES_FICHA)
      .get();

    const participacoes: ParticipacaoFilaCoordenador[] = [];
    for (const pDoc of todasPartSnap.docs) {
      const p = pDoc.data() ?? {};
      const equipeId = String(p.equipeId ?? '');

      let nomeEquipe = String(p.nomeEquipe ?? '');
      if (!nomeEquipe && equipeId) {
        nomeEquipe = equipesCache.get(equipeId) ?? '';
        if (!nomeEquipe) {
          const eqDoc = await db.collection('equipes').doc(equipeId).get();
          nomeEquipe = eqDoc.exists ? String(eqDoc.data()?.nome ?? equipeId) : equipeId;
          equipesCache.set(equipeId, nomeEquipe);
        }
      }

      const decResp = p.decisaoResponsavel as Record<string, unknown> | undefined;

      participacoes.push({
        participacaoId: pDoc.id,
        equipeId,
        nomeEquipe: nomeEquipe || equipeId,
        estado: String(p.estado ?? ''),
        proximaAcao: String(p.proximaAcao ?? ''),
        responsavelNome: decResp?.responsavelNome ? String(decResp.responsavelNome) : undefined,
        responsavelDecididoEm: decResp?.decididoEm ? iso(decResp.decididoEm) : undefined,
        justificativaResponsavel: decResp?.justificativa ? String(decResp.justificativa) : undefined,
        elegivelAtivacao: p.estado === 'AGUARDANDO_COORDENADOR',
      });
    }

    const decPastor = fData.decisaoPastorLocal as Record<string, unknown> | undefined;

    pendencias.push({
      fichaId,
      voluntarioUid: String(fData.ownerUid ?? fichaId),
      voluntarioNome: String(fData.nomeCompleto ?? 'Voluntário'),
      profissao: String(fData.profissao ?? ''),
      cpfMascarado: mascararCpf(fData.cpf),
      igrejaId,
      nomeIgreja: nomeIgreja || igrejaId,
      versaoFicha: Number(fData.versao ?? 1),
      enviadoEm: iso(fData.atualizadoEm ?? fData.criadoEm),
      pastorLocalNome: decPastor?.pastorNome ? String(decPastor.pastorNome) : undefined,
      pastorLocalDecididoEm: decPastor?.decididoEm ? iso(decPastor.decididoEm) : undefined,
      participacoes,
    });
  }

  pendencias.sort((a, b) => a.voluntarioNome.localeCompare(b.voluntarioNome, 'pt-BR'));

  return { pendencias };
}

/**
 * Transição atômica para homologação, confirmação de reunião de pastores
 * e ativação do ciclo anual de voluntariado pelo Coordenador Geral.
 */
export async function decidirAtivacaoCoordenadorRepo(
  db: Firestore,
  contexto: ContextoDecisaoCoordenador,
  entrada: EntradaDecidirAtivacaoCoordenador,
): Promise<ResultadoDecidirAtivacaoCoordenador> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(entrada.fichaId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em commands
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.coordenadorUid) {
        throw new SemAutoridadeCoordenadorError(
          'Operação indisponível para o usuário informado.',
        );
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        fichaId: entrada.fichaId,
        decisao: entrada.decisao,
        estadoFicha: String(res?.estadoFicha ?? 'ATIVA'),
        versaoFicha: Number(res?.versaoFicha ?? 1),
        participacoesAtivadas: (res?.participacoesAtivadas as string[]) ?? [],
        participacoesRejeitadas: (res?.participacoesRejeitadas as string[]) ?? [],
        vigenciaInicio: res?.vigenciaInicio as string | undefined,
        vigenciaFim: res?.vigenciaFim as string | undefined,
        decididoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação da Ficha
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};

    const versaoAtualFicha = Number(fichaData.versao ?? 1);
    if (versaoAtualFicha !== entrada.expectedVersion) {
      throw new ConflitoVersaoError();
    }

    // 3. Leitura das participações da Ficha
    const participacoesSnap = await tx.get(
      db
        .collection('participacoes')
        .where('fichaId', '==', entrada.fichaId)
        .limit(LIMITE_PARTICIPACOES_FICHA),
    );

    const participacoesElegiveis = participacoesSnap.docs.filter(
      (doc) => doc.data()?.estado === 'AGUARDANDO_COORDENADOR',
    );

    if (participacoesElegiveis.length === 0) {
      throw new FichaNaoAguardandoCoordenadorError();
    }

    // 4. Autoridade canônica revalidada no instante da transação (AD-2)
    const autoridade = await validarAutoridadeCoordenadorTx(
      db,
      tx,
      contexto.coordenadorUid,
    );
    if (!autoridade.autorizado) {
      throw new SemAutoridadeCoordenadorError();
    }
    const coordenadorNome = autoridade.nome;

    const agora = FieldValue.serverTimestamp();
    const agoraDate = new Date();
    const agoraIso = agoraDate.toISOString();
    const novaVersaoFicha = versaoAtualFicha + 1;

    const participacoesAtivadas: string[] = [];
    const participacoesRejeitadas: string[] = [];
    let vigenciaInicio: string | undefined;
    let vigenciaFim: string | undefined;
    let vigenciaInicioTs: Timestamp | undefined;
    let vigenciaFimTs: Timestamp | undefined;

    const estadosResultantes = participacoesSnap.docs.map((partDoc) => {
      if (!participacoesElegiveis.some((e) => e.id === partDoc.id)) {
        return String(partDoc.data()?.estado ?? '');
      }
      return entrada.decisao === 'APROVADO' ? 'ATIVA' : 'REJEITADA';
    });

    // Pré-leitura dos ciclos elegíveis (antes de qualquer escrita) para encerrá-los
    // em caso de decisão desfavorável, evitando ciclo não terminal órfão.
    const ciclosElegiveis = new Map<string, DocumentSnapshot>();
    if (entrada.decisao !== 'APROVADO') {
      for (const partDoc of participacoesElegiveis) {
        const cicloId = String(partDoc.data()?.cicloAtualId ?? '');
        if (cicloId) {
          ciclosElegiveis.set(
            partDoc.id,
            await tx.get(db.collection('ciclos').doc(cicloId)),
          );
        }
      }
    }

    if (entrada.decisao === 'APROVADO') {
      // Vigência de exatamente um ano a partir da aprovação final (AD-7/AD-11)
      const vigencia = calcularVigenciaAnual(agoraDate);
      const dataFim = vigencia.vigenciaFim;
      vigenciaInicio = vigencia.vigenciaInicio.toISOString();
      vigenciaFim = vigencia.vigenciaFim.toISOString();
      vigenciaInicioTs = Timestamp.fromDate(vigencia.vigenciaInicio);
      vigenciaFimTs = Timestamp.fromDate(dataFim);
      const anoVigencia = vigencia.anoVigencia;

      for (const partDoc of participacoesElegiveis) {
        const partData = partDoc.data() ?? {};
        const partId = partDoc.id;
        const versaoPart = Number(partData.versao ?? 1);
        participacoesAtivadas.push(partId);

        // Reutiliza a chave determinística persistida na participação para não
        // deixar o ciclo EM_APROVACAO órfão quando a aprovação cruza o ano (Story 4.2).
        const cicloId = String(partData.cicloAtualId ?? '') || `ciclo_${partId}_${anoVigencia}`;
        const cicloRef = db.collection('ciclos').doc(cicloId);

        tx.set(cicloRef, {
          id: cicloId,
          participacaoId: partId,
          fichaId: entrada.fichaId,
          equipeId: partData.equipeId,
          voluntarioUid: fichaData.ownerUid ?? entrada.fichaId,
          anoVigencia,
          vigenciaInicio: vigenciaInicioTs,
          vigenciaFim: vigenciaFimTs,
          estado: 'ATIVO',
          coordenadorUid: contexto.coordenadorUid,
          coordenadorNome,
          confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
          observacao: entrada.observacao ?? null,
          criadoEm: agora,
          atualizadoEm: agora,
        });

        tx.update(partDoc.ref, {
          estado: 'ATIVA',
          proximaAcao: 'Voluntariado ativo',
          versao: versaoPart + 1,
          cicloAtualId: cicloId,
          vigenciaInicio: vigenciaInicioTs,
          vigenciaFim: vigenciaFimTs,
          decisaoCoordenador: {
            decisao: 'APROVADO',
            coordenadorUid: contexto.coordenadorUid,
            coordenadorNome,
            papel: autoridade.papel,
            confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
            observacao: entrada.observacao ?? null,
            decididoEm: agora,
          },
          atualizadoEm: agora,
        });
      }

      // Evidência imutável de homologação e confirmação de reunião
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        fichaId: entrada.fichaId,
        participacoesAtivadas,
        etapa: 'COORDENADOR_GERAL',
        decisao: 'APROVADO',
        atorUid: contexto.coordenadorUid,
        atorNome: coordenadorNome,
        papel: autoridade.papel,
        autoridadeVersao: autoridade.autoridadeVersao,
        vinculoId: null,
        confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
        observacao: entrada.observacao ?? null,
        vigenciaInicio,
        vigenciaFim,
        timestamp: agora,
      });
    } else {
      // Decisão DESFAVORAVEL
      for (const partDoc of participacoesElegiveis) {
        const partData = partDoc.data() ?? {};
        const partId = partDoc.id;
        const versaoPart = Number(partData.versao ?? 1);
        participacoesRejeitadas.push(partId);

        tx.update(partDoc.ref, {
          estado: 'REJEITADA',
          proximaAcao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
          mensagemVoluntario: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
          justificativaInterna: entrada.observacao,
          versao: versaoPart + 1,
          decisaoCoordenador: {
            decisao: 'DESFAVORAVEL',
            coordenadorUid: contexto.coordenadorUid,
            coordenadorNome,
            papel: autoridade.papel,
            justificativa: entrada.observacao,
            decididoEm: agora,
          },
          atualizadoEm: agora,
        });

        const cicloRejeitadoSnap = ciclosElegiveis.get(partId);
        if (cicloRejeitadoSnap?.exists) {
          const estadoCicloAtual = String(cicloRejeitadoSnap.data()?.estado ?? '');
          if (estadoCicloAtual !== 'CANCELADA' && estadoCicloAtual !== 'REJEITADA') {
            tx.update(cicloRejeitadoSnap.ref, {
              estado: 'REJEITADA',
              atualizadoEm: agora,
            });
          }
        }
      }

      // Evidência imutável com justificativa interna
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        fichaId: entrada.fichaId,
        participacoesRejeitadas,
        etapa: 'COORDENADOR_GERAL',
        decisao: 'DESFAVORAVEL',
        atorUid: contexto.coordenadorUid,
        atorNome: coordenadorNome,
        papel: autoridade.papel,
        autoridadeVersao: autoridade.autoridadeVersao,
        vinculoId: null,
        confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
        justificativaInterna: entrada.observacao,
        timestamp: agora,
      });
    }

    // 5. Redução canônica da Ficha (AD-11) considerando todas as participações
    const reducao = reduzirEstadoFicha(estadosResultantes);
    const estadoFicha = reducao.estado;
    const proximaAcaoFicha = reducao.proximaAcao;

    const atualizacaoFicha: Record<string, unknown> = {
      estado: estadoFicha,
      proximaAcao: proximaAcaoFicha,
      versao: novaVersaoFicha,
      atualizadoEm: agora,
    };
    if (estadoFicha === 'ATIVA' && vigenciaInicioTs && vigenciaFimTs) {
      atualizacaoFicha.vigenciaInicio = vigenciaInicioTs;
      atualizacaoFicha.vigenciaFim = vigenciaFimTs;
    }
    if (estadoFicha === 'REJEITADA') {
      atualizacaoFicha.mensagemVoluntario = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;
    }
    tx.update(fichaRef, atualizacaoFicha);

    // 6. Recibo Idempotente
    const resultadoOperacao = {
      sucesso: true,
      repetido: false,
      fichaId: entrada.fichaId,
      decisao: entrada.decisao,
      estadoFicha,
      versaoFicha: novaVersaoFicha,
      participacoesAtivadas,
      participacoesRejeitadas,
      vigenciaInicio,
      vigenciaFim,
    };

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.coordenadorUid,
      acao: 'DECIDIR_ATIVACAO_COORDENADOR',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado: resultadoOperacao,
      criadoEm: agora,
    });

    // 7. Auditoria append-only rigorosamente SEM PII (AD-12)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      actorUid: contexto.coordenadorUid,
      action: 'DECISAO_COORDENADOR',
      fichaId: entrada.fichaId,
      decisao: entrada.decisao,
      novoEstadoFicha: estadoFicha,
      participacoesAtivadas,
      participacoesRejeitadas,
      confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
      criadoEm: agora,
    });

    return {
      sucesso: true,
      repetido: false,
      fichaId: entrada.fichaId,
      decisao: entrada.decisao,
      estadoFicha,
      versaoFicha: novaVersaoFicha,
      participacoesAtivadas,
      participacoesRejeitadas,
      vigenciaInicio,
      vigenciaFim,
      decididoEm: agoraIso,
    };
  });
}

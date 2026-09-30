import {
  FieldValue,
  Timestamp,
  type Firestore,
  type QuerySnapshot,
} from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ACOES_VINCULO,
  ComandoDivergenteError,
  EntidadeInexistenteError,
  PessoaInexistenteError,
  SemAutoridadeError,
  camposVigente,
  papelDoTipo,
  planejarVinculo,
  type AcaoVinculo,
  type EntidadeVinculoResumo,
  type EntradaVinculo,
  type EventoHistoricoVinculo,
  type ResumoVinculos,
  type TipoEntidade,
  type VigenteAtual,
} from '../domain/vinculos.js';
import { normalizarNome } from '../domain/importacaoPastores.js';

/** Origem auditável das mutações administrativas da Story 1.4. */
export const ORIGEM_VINCULOS = 'administracao-vinculos-responsaveis';

const ACAO_RECIBO = 'GERENCIAR_VINCULO';

export type ContextoVinculo = {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
  /** Tempo do servidor, usado para recusar data efetiva futura. */
  agoraMs: number;
};

export type ResultadoGerenciarVinculo = {
  tipoEntidade: TipoEntidade;
  entidadeId: string;
  vinculoId: string | null;
  pessoaId: string | null;
  versaoVinculo: number;
  repetido: boolean;
};

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor : '';
}

/** Converte Timestamp/Date/número em ms; nulo quando o legado não tiver valor. */
function millis(valor: unknown): number | null {
  if (valor === null || valor === undefined) return null;
  if (typeof valor === 'number') return valor;
  if (valor instanceof Date) return valor.getTime();
  if (typeof (valor as { toMillis?: unknown }).toMillis === 'function') {
    return (valor as { toMillis: () => number }).toMillis();
  }
  return null;
}

function iso(valor: unknown): string | null {
  const ms = millis(valor);
  return ms === null ? null : new Date(ms).toISOString();
}

function acaoAuditoria(acao: AcaoVinculo): string {
  if (acao === 'ATRIBUIR') return 'VINCULO_ATRIBUIDO';
  if (acao === 'SUBSTITUIR') return 'VINCULO_SUBSTITUIDO';
  return 'VINCULO_ENCERRADO';
}

/**
 * Única fronteira de escrita dos vínculos de responsabilidade. A transação roda
 * sobre o documento canônico da igreja/equipe: valida a autoridade vigente,
 * lê o vínculo atual (inclusive o legado da importação), grava o par vigente e
 * `versaoVinculo`, e cria recibo + auditoria no mesmo commit, sem PII.
 */
export async function gerenciarVinculo(
  db: Firestore,
  contexto: ContextoVinculo,
  entrada: EntradaVinculo,
): Promise<ResultadoGerenciarVinculo> {
  const campos = camposVigente(entrada.tipoEntidade);
  const entidadeRef = db.collection(campos.colecao).doc(entrada.entidadeId);
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  // Valida a autoridade antes de qualquer leitura do alvo: um chamador sem
  // papel não pode distinguir entidade/pessoa existente de inexistente.
  const atorPrevio = await db
    .collection('autoridadesAdministrativas')
    .doc(contexto.atorUid)
    .get();
  if (!podeAdministrar(atorPrevio.data())) throw new SemAutoridadeError();

  return db.runTransaction(async (tx) => {
    const atorRef = db
      .collection('autoridadesAdministrativas')
      .doc(contexto.atorUid);
    const [atorSnap, reciboSnap, entidadeSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
      tx.get(entidadeRef),
    ]);
    // A autoridade é revalidada dentro da transação para não permitir corrida
    // entre a leitura e a escrita.
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      if (
        recibo.action !== ACAO_RECIBO ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== entrada.payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        tipoEntidade: entrada.tipoEntidade,
        entidadeId: entrada.entidadeId,
        vinculoId: typeof recibo.vinculoId === 'string' ? recibo.vinculoId : null,
        pessoaId: typeof recibo.pessoaId === 'string' ? recibo.pessoaId : null,
        versaoVinculo: Number(recibo.versaoVinculo ?? 0),
        repetido: true,
      };
    }

    if (!entidadeSnap.exists) throw new EntidadeInexistenteError();
    const dados = entidadeSnap.data() ?? {};
    // Igreja/equipe inativa não recebe nem perde vínculo.
    if (dados.ativo !== true) throw new EntidadeInexistenteError();

    if (entrada.pessoaId) {
      const pessoaSnap = await tx.get(
        db.collection('pessoas').doc(entrada.pessoaId),
      );
      if (!pessoaSnap.exists) throw new PessoaInexistenteError();
    }

    const versao = Number(dados.versaoVinculo ?? 0);
    const pessoaVigenteId = texto(dados[campos.pessoa]) || null;
    const vinculoVigenteId = texto(dados[campos.vinculo]) || null;

    // Lê o vínculo vigente pelo ponteiro canônico; se o documento não existir
    // (legado sem timestamp), ainda assim o ponteiro é tratado como vigente.
    let vigente: VigenteAtual | null = null;
    if (vinculoVigenteId) {
      const vinculoSnap = await tx.get(
        db.collection(campos.colecaoVinculos).doc(vinculoVigenteId),
      );
      if (vinculoSnap.exists) {
        const v = vinculoSnap.data() ?? {};
        vigente = {
          vinculoId: vinculoVigenteId,
          pessoaId: texto(v.pessoaId) || pessoaVigenteId || '',
          inicioVigenciaMs: millis(v.inicioVigencia),
        };
      } else if (pessoaVigenteId) {
        vigente = {
          vinculoId: vinculoVigenteId,
          pessoaId: pessoaVigenteId,
          inicioVigenciaMs: null,
        };
      }
    } else if (pessoaVigenteId) {
      vigente = { vinculoId: '', pessoaId: pessoaVigenteId, inicioVigenciaMs: null };
    }

    const plano = planejarVinculo(
      entrada,
      { ativo: true, vigente, versaoVinculo: versao },
      contexto.agoraMs,
    );

    if (plano.encerrarVinculoId) {
      tx.update(db.collection(campos.colecaoVinculos).doc(plano.encerrarVinculoId), {
        estado: 'ENCERRADO',
        fimVigencia: Timestamp.fromMillis(plano.fimVigenciaMs ?? entrada.dataEfetivaMs),
        encerradoPorUid: contexto.atorUid,
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }

    const novoVinculoRef = db.collection(campos.colecaoVinculos).doc();
    let vinculoId: string | null = plano.encerrarVinculoId || null;
    let pessoaFinal: string | null = null;
    if (plano.criar) {
      vinculoId = novoVinculoRef.id;
      pessoaFinal = plano.criar.pessoaId;
      tx.create(novoVinculoRef, {
        entidadeId: entrada.entidadeId,
        tipoEntidade: entrada.tipoEntidade,
        pessoaId: plano.criar.pessoaId,
        papel: papelDoTipo(entrada.tipoEntidade),
        estado: 'VIGENTE',
        acao: entrada.acao,
        inicioVigencia: Timestamp.fromMillis(plano.criar.inicioVigenciaMs),
        fimVigencia: null,
        justificativa: entrada.justificativa,
        atorUid: contexto.atorUid,
        origem: contexto.origem,
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        criadoEm: FieldValue.serverTimestamp(),
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }

    const atualizacao: Record<string, unknown> = {
      versaoVinculo: versao + 1,
      atualizadoEm: FieldValue.serverTimestamp(),
    };
    if (plano.criar) {
      atualizacao[campos.pessoa] = plano.criar.pessoaId;
      atualizacao[campos.vinculo] = vinculoId;
    } else {
      atualizacao[campos.pessoa] = FieldValue.delete();
      atualizacao[campos.vinculo] = FieldValue.delete();
    }
    tx.set(entidadeRef, atualizacao, { merge: true });

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO,
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      tipoEntidade: entrada.tipoEntidade,
      entidadeId: entrada.entidadeId,
      acao: entrada.acao,
      vinculoId,
      pessoaId: pessoaFinal,
      versaoVinculo: versao + 1,
      criadoEm: FieldValue.serverTimestamp(),
    });
    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: acaoAuditoria(entrada.acao),
      tipoEntidade: entrada.tipoEntidade,
      entidadeId: entrada.entidadeId,
      papel: papelDoTipo(entrada.tipoEntidade),
      vinculoId,
      pessoaId: pessoaFinal,
      dataEfetiva: Timestamp.fromMillis(entrada.dataEfetivaMs),
      justificativa: entrada.justificativa,
      antes: {
        pessoaId: vigente?.pessoaId ?? null,
        vinculoId: vigente?.vinculoId || null,
      },
      depois: { pessoaId: pessoaFinal, vinculoId },
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      tipoEntidade: entrada.tipoEntidade,
      entidadeId: entrada.entidadeId,
      vinculoId,
      pessoaId: pessoaFinal,
      versaoVinculo: versao + 1,
      repetido: false,
    };
  });
}

type VinculoDoc = {
  id: string;
  dados: Record<string, unknown>;
};

function agruparPorEntidade(
  docs: VinculoDoc[],
  campoLegado: string,
): Map<string, VinculoDoc[]> {
  const mapa = new Map<string, VinculoDoc[]>();
  for (const doc of docs) {
    // Vínculos novos usam `entidadeId`; os legados da importação gravam
    // `igrejaId`/`equipeId` no schema original.
    const entidadeId =
      texto(doc.dados.entidadeId) || texto(doc.dados[campoLegado]);
    if (!entidadeId) continue;
    const grupo = mapa.get(entidadeId) ?? [];
    grupo.push(doc);
    mapa.set(entidadeId, grupo);
  }
  return mapa;
}

function historico(
  docs: VinculoDoc[],
  nomes: Map<string, string>,
  tipoEntidade: TipoEntidade,
): EventoHistoricoVinculo[] {
  const itens: EventoHistoricoVinculo[] = docs.map((doc) => {
    const atorUid = texto(doc.dados.atorUid);
    const estado = doc.dados.estado === 'ENCERRADO' ? 'ENCERRADO' : 'VIGENTE';
    return {
      acao: (ACOES_VINCULO as readonly string[]).includes(
        texto(doc.dados.acao),
      )
        ? (texto(doc.dados.acao) as AcaoVinculo)
        : 'ATRIBUIR',
      papel: papelDoTipo(tipoEntidade),
      estado,
      atorUid,
      atorNome: nomes.get(atorUid) ?? '',
      inicioVigencia: iso(doc.dados.inicioVigencia) ?? '',
      fimVigencia: iso(doc.dados.fimVigencia),
      justificativa:
        typeof doc.dados.justificativa === 'string' && doc.dados.justificativa
          ? doc.dados.justificativa
          : null,
      encerradoPorUid:
        estado === 'ENCERRADO' ? texto(doc.dados.encerradoPorUid) || null : null,
    };
  });
  return itens.sort((a, b) => {
    if (a.inicioVigencia === b.inicioVigencia) return 0;
    return a.inicioVigencia < b.inicioVigencia ? 1 : -1;
  });
}

function resumir(
  id: string,
  tipoEntidade: TipoEntidade,
  dados: Record<string, unknown>,
  vinculos: VinculoDoc[],
  nomes: Map<string, string>,
): EntidadeVinculoResumo {
  const campos = camposVigente(tipoEntidade);
  const pessoaVigenteId = texto(dados[campos.pessoa]) || null;
  const vinculoVigenteId = texto(dados[campos.vinculo]) || null;
  const vigente = vinculos.find(
    (doc) =>
      doc.id === vinculoVigenteId && doc.dados.estado !== 'ENCERRADO',
  );
  const pessoaId = vigente ? texto(vigente.dados.pessoaId) || pessoaVigenteId : pessoaVigenteId;
  const responsavel =
    pessoaId === null
      ? null
      : { pessoaId, nome: nomes.get(pessoaId) ?? '' };
  const nome = texto(dados.nome);
  const codigo = texto(dados.codigo) || null;
  return {
    id,
    tipoEntidade,
    rotulo:
      tipoEntidade === 'IGREJA'
        ? `${nome} - ${codigo ?? ''}`.trim()
        : nome,
    codigo,
    ativo: dados.ativo === true,
    versaoVinculo: Number(dados.versaoVinculo ?? 0),
    responsavel,
    historico: historico(vinculos, nomes, tipoEntidade),
  };
}

function corresponde(
  item: { rotulo: string; codigo: string | null },
  termo: string,
): boolean {
  const alvo = normalizarNome(termo);
  if (!alvo) return true;
  if (normalizarNome(item.rotulo).includes(alvo)) return true;
  return (item.codigo ?? '').includes(termo.trim());
}

function ordenar<T extends { rotulo: string }>(itens: T[]): T[] {
  return [...itens].sort((a, b) =>
    a.rotulo.localeCompare(b.rotulo, 'pt-BR', { sensitivity: 'base' }),
  );
}

/**
 * Consulta autorizada e read-only de vínculos e responsáveis vigentes. Devolve
 * apenas IDs opacos, nomes de exibição e a linha do tempo; nunca e-mail ou CPF.
 */
export async function lerVinculos(
  db: Firestore,
  termo = '',
): Promise<ResumoVinculos> {
  const [
    igrejasSnap,
    equipesSnap,
    pessoasSnap,
    vinculosIgrejaSnap,
    vinculosEquipeSnap,
  ] = await Promise.all([
    db.collection('igrejas').get(),
    db.collection('equipes').get(),
    // Seleciona apenas o nome de exibição para montar o mapa de nomes.
    db.collection('pessoas').select('nomeCompleto').get(),
    db.collection('vinculosPastorIgreja').get(),
    db.collection('vinculosPastorEquipe').get(),
  ]);

  const nomes = new Map<string, string>();
  for (const doc of pessoasSnap.docs) {
    const nome = texto(doc.data().nomeCompleto);
    if (nome) nomes.set(doc.id, nome);
  }

  const paraDocs = (snap: QuerySnapshot): VinculoDoc[] =>
    snap.docs.map((doc) => ({ id: doc.id, dados: doc.data() }));
  const porIgreja = agruparPorEntidade(paraDocs(vinculosIgrejaSnap), 'igrejaId');
  const porEquipe = agruparPorEntidade(paraDocs(vinculosEquipeSnap), 'equipeId');

  const igrejas = ordenar(
    igrejasSnap.docs.map((doc) =>
      resumir(doc.id, 'IGREJA', doc.data(), porIgreja.get(doc.id) ?? [], nomes),
    ),
  );
  const equipes = ordenar(
    equipesSnap.docs.map((doc) =>
      resumir(doc.id, 'EQUIPE', doc.data(), porEquipe.get(doc.id) ?? [], nomes),
    ),
  );

  return {
    igrejas: igrejas.filter((item) => corresponde(item, termo)),
    equipes: equipes.filter((item) => corresponde(item, termo)),
  };
}

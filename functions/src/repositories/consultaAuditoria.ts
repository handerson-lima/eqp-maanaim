import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import {
  AcessoConsultaNegadoError,
  codificarCursorAuditoria,
  mascararCpfSeguro,
  type FiltrosConsultaAuditoria,
  type FiltrosRelatorioOperacional,
  type ItemAuditoriaAutorizado,
  type MetricasRelatorioOperacional,
  type ResultadoConsultaAuditoria,
  type ResultadoRelatorioOperacional,
  type VoluntarioItemRelatorio,
} from '../domain/consultaAuditoria.js';
import { sanitizarDadoAuditoria } from '../domain/auditoria.js';
import { avaliarAutoridadeCoordenador } from './decisaoCoordenador.js';

interface EscopoAtorAuditoria {
  papel: 'GLOBAL' | 'PASTOR_LOCAL' | 'RESPONSAVEL_EQUIPE';
  igrejasIds: string[];
  equipesIds: string[];
}

function serializarTimestamp(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof valor === 'string') return valor;
  return new Date().toISOString();
}

function timestampParaMs(valor: unknown): number {
  if (!valor) return Date.now();
  if (valor instanceof Timestamp) return valor.toMillis();
  if (valor instanceof Date) return valor.getTime();
  if (typeof (valor as { toMillis?: unknown }).toMillis === 'function') {
    return (valor as { toMillis: () => number }).toMillis();
  }
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().getTime();
  }
  if (typeof valor === 'string') {
    const parsed = Date.parse(valor);
    return isNaN(parsed) ? Date.now() : parsed;
  }
  return Date.now();
}

/**
 * Avalia em tempo de execução os vínculos vigentes e privilégios do ator (AD-9).
 */
export async function resolverEscopoAtorAuditoria(
  db: Firestore,
  atorUid: string,
): Promise<EscopoAtorAuditoria> {
  // 1. Verificar autoridade administrativa global (Coordenador Geral ou Administrador)
  const autoridadeDoc = await db.collection('autoridadesAdministrativas').doc(atorUid).get();
  if (autoridadeDoc.exists) {
    const authData = autoridadeDoc.data() ?? {};
    const avaliacao = avaliarAutoridadeCoordenador(authData, 'Usuario');
    const papelStr = String(authData.papel ?? '').toUpperCase();
    const papeisArray = Array.isArray(authData.papeis)
      ? authData.papeis.map((p: unknown) => String(p).toUpperCase())
      : [];
    const ehAtivo = authData.ativa === true || authData.ativo === true;

    if (
      avaliacao.autorizado ||
      (ehAtivo &&
        (papelStr === 'ADMINISTRADOR' ||
          papelStr === 'COORDENADOR' ||
          papelStr === 'COORDENADOR_GERAL' ||
          papeisArray.includes('ADMINISTRADOR') ||
          papeisArray.includes('COORDENADOR')))
    ) {
      return {
        papel: 'GLOBAL',
        igrejasIds: [],
        equipesIds: [],
      };
    }
  }

  // 2. Verificar se é Pastor Local com vínculo pastoral vigente
  const igrejasSet = new Set<string>();
  const igrejasDirectSnap = await db
    .collection('igrejas')
    .where('pastorLocalVigentePessoaId', '==', atorUid)
    .get();

  for (const doc of igrejasDirectSnap.docs) {
    if (doc.data()?.ativo !== false) {
      igrejasSet.add(doc.id);
    }
  }

  const vinculosPastorSnap = await db
    .collection('vinculosPastorIgreja')
    .where('pessoaId', '==', atorUid)
    .where('estado', '==', 'VIGENTE')
    .get();

  for (const doc of vinculosPastorSnap.docs) {
    const v = doc.data() ?? {};
    const igId = String(v.entidadeId ?? '').trim();
    if (igId) {
      igrejasSet.add(igId);
    }
  }

  // 3. Verificar se é Responsável de Equipe com responsabilidade vigente
  const equipesSet = new Set<string>();
  const equipesDirectSnap = await db
    .collection('equipes')
    .where('responsavelVigentePessoaId', '==', atorUid)
    .get();

  for (const doc of equipesDirectSnap.docs) {
    if (doc.data()?.ativo !== false) {
      equipesSet.add(doc.id);
    }
  }

  const vinculosEquipeSnap = await db
    .collection('vinculosPastorEquipe')
    .where('pessoaId', '==', atorUid)
    .where('estado', '==', 'VIGENTE')
    .get();

  for (const doc of vinculosEquipeSnap.docs) {
    const eqId = String(doc.data()?.entidadeId ?? '').trim();
    if (eqId) {
      equipesSet.add(eqId);
    }
  }

  // Determinar papel com base nos vínculos vigentes
  if (igrejasSet.size > 0 && equipesSet.size === 0) {
    return {
      papel: 'PASTOR_LOCAL',
      igrejasIds: Array.from(igrejasSet),
      equipesIds: [],
    };
  }

  if (equipesSet.size > 0 && igrejasSet.size === 0) {
    return {
      papel: 'RESPONSAVEL_EQUIPE',
      igrejasIds: [],
      equipesIds: Array.from(equipesSet),
    };
  }

  if (igrejasSet.size > 0 && equipesSet.size > 0) {
    // Caso com ambos os vínculos, concede escopo pastoral com equipes acumuladas
    return {
      papel: 'PASTOR_LOCAL',
      igrejasIds: Array.from(igrejasSet),
      equipesIds: Array.from(equipesSet),
    };
  }

  // Ator não possui papel administrativo, pastoral ou de equipe
  throw new AcessoConsultaNegadoError(
    'Apenas pastores, responsáveis de equipes e coordenação possuem acesso a relatórios e auditoria.',
  );
}

/**
 * Consulta autorizada de auditoria imutável com isolamento por escopo e cursor determinístico (AD-8, AD-9, AD-12).
 */
export async function consultarAuditoriaAutorizadaRepo(
  db: Firestore,
  atorUid: string,
  filtros: FiltrosConsultaAuditoria,
  limite: number,
  cursorDecodificado: { timestampMs: number; commandId: string } | null,
  correlationId?: string,
): Promise<ResultadoConsultaAuditoria> {
  const escopo = await resolverEscopoAtorAuditoria(db, atorUid);

  // Validação de Escopo e Prevenção de IDOR (AD-9)
  if (escopo.papel === 'PASTOR_LOCAL') {
    if (filtros.igrejaId && !escopo.igrejasIds.includes(filtros.igrejaId)) {
      // Tentativa de acessar igreja fora do escopo: retorna resultado vazio neutro
      return { itens: [], proximoCursor: null, temMais: false, totalRetornado: 0 };
    }
  }

  if (escopo.papel === 'RESPONSAVEL_EQUIPE') {
    if (filtros.equipeId && !escopo.equipesIds.includes(filtros.equipeId)) {
      // Tentativa de acessar equipe fora do escopo: retorna resultado vazio neutro
      return { itens: [], proximoCursor: null, temMais: false, totalRetornado: 0 };
    }
  }

  // Buscar itens da coleção 'auditoria'
  const snap = await db.collection('auditoria').get();

  // Registrar auditoria probatória da consulta global se efetuada por Coordenador/Admin (AD-8, AD-12)
  if (escopo.papel === 'GLOBAL') {
    const cmdIdAudit = `AUDIT_QUERY_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const corrId = correlationId ?? cmdIdAudit;
    try {
      await db.collection('auditoria').doc(cmdIdAudit).set({
        id: cmdIdAudit,
        commandId: cmdIdAudit,
        correlationId: corrId,
        atorUid,
        acao: 'CONSULTA_AUDITORIA_GLOBAL',
        entidades: [{ tipo: 'SISTEMA', id: 'AUDITORIA' }],
        antes: null,
        depois: null,
        metadados: {
          filtros: sanitizarDadoAuditoria(filtros),
          limite,
          cursor: filtros.cursor ?? null,
        },
        timestampOriginal: FieldValue.serverTimestamp(),
        materializadoEm: FieldValue.serverTimestamp(),
        versaoSchema: 1,
        sanitizado: true,
      });
    } catch (auditErr) {
      logger.warn('Não foi possível gravar auditoria da consulta global:', auditErr);
    }
  }
  const todosItens: Array<{
    item: ItemAuditoriaAutorizado;
    timestampMs: number;
    commandId: string;
    igrejasItem: string[];
    equipesItem: string[];
  }> = [];

  for (const doc of snap.docs) {
    const data = doc.data() ?? {};
    const commandId = String(data.commandId ?? doc.id).trim();
    const tsOriginal = data.timestampOriginal ?? data.materializadoEm;
    const tsMs = timestampParaMs(tsOriginal);
    const tsIso = serializarTimestamp(tsOriginal);

    const entidades = Array.isArray(data.entidades)
      ? data.entidades.map((e: { tipo?: unknown; id?: unknown }) => ({
          tipo: String(e?.tipo ?? '').toUpperCase(),
          id: String(e?.id ?? ''),
        }))
      : [];

    const igrejasItem = entidades
      .filter((e: { tipo: string }) => e.tipo === 'IGREJA')
      .map((e: { id: string }) => e.id);
    const equipesItem = entidades
      .filter((e: { tipo: string }) => e.tipo === 'EQUIPE')
      .map((e: { id: string }) => e.id);

    // Também examina metadados/depois/antes para referências a igrejas/equipes se entidades estiverem vazias
    if (data.metadados && typeof data.metadados === 'object') {
      const meta = data.metadados as Record<string, unknown>;
      if (meta.igrejaId && typeof meta.igrejaId === 'string') igrejasItem.push(meta.igrejaId);
      if (meta.equipeId && typeof meta.equipeId === 'string') equipesItem.push(meta.equipeId);
    }

    const item: ItemAuditoriaAutorizado = {
      id: commandId,
      commandId,
      correlationId: String(data.correlationId ?? commandId),
      atorUid: String(data.atorUid ?? 'SISTEMA'),
      acao: String(data.acao ?? ''),
      entidades,
      antes: (sanitizarDadoAuditoria(data.antes) as Record<string, unknown>) ?? null,
      depois: (sanitizarDadoAuditoria(data.depois) as Record<string, unknown>) ?? null,
      metadados: (sanitizarDadoAuditoria(data.metadados) as Record<string, unknown>) ?? null,
      timestamp: tsIso,
      sanitizado: Boolean(data.sanitizado ?? true),
    };

    todosItens.push({
      item,
      timestampMs: tsMs,
      commandId,
      igrejasItem,
      equipesItem,
    });
  }

  // Filtragem rigorosa por escopo do ator
  let filtrados = todosItens.filter((entry) => {
    if (escopo.papel === 'GLOBAL') {
      return true;
    }

    if (escopo.papel === 'PASTOR_LOCAL') {
      // O evento deve pertencer a uma das igrejas do pastor
      const bateIgreja = entry.igrejasItem.some((ig) => escopo.igrejasIds.includes(ig));
      return bateIgreja;
    }

    if (escopo.papel === 'RESPONSAVEL_EQUIPE') {
      // O evento deve pertencer a uma das equipes sob responsabilidade
      const bateEquipe = entry.equipesItem.some((eq) => escopo.equipesIds.includes(eq));
      return bateEquipe;
    }

    return false;
  });

  // Filtragem por parâmetros do usuário
  if (filtros.igrejaId) {
    filtrados = filtrados.filter((e) => e.igrejasItem.includes(filtros.igrejaId!));
  }

  if (filtros.equipeId) {
    filtrados = filtrados.filter((e) => e.equipesItem.includes(filtros.equipeId!));
  }

  if (filtros.acao) {
    filtrados = filtrados.filter((e) => e.item.acao.toUpperCase() === filtros.acao);
  }

  if (filtros.voluntarioId) {
    filtrados = filtrados.filter((e) => {
      const temEntidade = e.item.entidades.some(
        (ent) => ent.tipo === 'VOLUNTARIO' && ent.id === filtros.voluntarioId,
      );
      const bateAtor = e.item.atorUid === filtros.voluntarioId;
      return temEntidade || bateAtor;
    });
  }

  if (filtros.periodoInicio) {
    const inicioMs = Date.parse(filtros.periodoInicio);
    filtrados = filtrados.filter((e) => e.timestampMs >= inicioMs);
  }

  if (filtros.periodoFim) {
    const fimMs = Date.parse(filtros.periodoFim);
    filtrados = filtrados.filter((e) => e.timestampMs <= fimMs);
  }

  // Ordenação estável descendente por timestampMs e desempate por commandId (AD-8/AD-9)
  filtrados.sort((a, b) => {
    if (b.timestampMs !== a.timestampMs) {
      return b.timestampMs - a.timestampMs;
    }
    return b.commandId.localeCompare(a.commandId);
  });

  // Aplicação do cursor para paginação
  let itensAposCursor = filtrados;
  if (cursorDecodificado) {
    const { timestampMs: curTs, commandId: curCmdId } = cursorDecodificado;
    itensAposCursor = filtrados.filter((e) => {
      if (e.timestampMs < curTs) return true;
      if (e.timestampMs === curTs) {
        return e.commandId.localeCompare(curCmdId) < 0;
      }
      return false;
    });
  }

  // Slice limitado
  const pagina = itensAposCursor.slice(0, limite);
  const temMais = itensAposCursor.length > limite;

  let proximoCursor: string | null = null;
  if (temMais && pagina.length > 0) {
    const ultimo = pagina[pagina.length - 1];
    proximoCursor = codificarCursorAuditoria(ultimo.timestampMs, ultimo.commandId);
  }

  return {
    itens: pagina.map((p) => p.item),
    proximoCursor,
    temMais,
    totalRetornado: pagina.length,
  };
}

/**
 * Consulta autorizada de relatórios operacionais consolidados (AD-8, AD-9, AD-12).
 */
export async function consultarRelatorioOperacionalRepo(
  db: Firestore,
  atorUid: string,
  filtros: FiltrosRelatorioOperacional = {},
  correlationId?: string,
): Promise<ResultadoRelatorioOperacional> {
  const escopo = await resolverEscopoAtorAuditoria(db, atorUid);

  // Isolamento de escopo por papel
  if (escopo.papel === 'PASTOR_LOCAL') {
    if (filtros.igrejaId && !escopo.igrejasIds.includes(filtros.igrejaId)) {
      return {
        metricas: {
          totalVoluntarios: 0,
          totalFichasAtivas: 0,
          totalParticipacoesAtivas: 0,
          totalAguardandoAprovacao: 0,
          totalCanceladasOuInativas: 0,
          distribuicaoPorEquipe: {},
          distribuicaoPorIgreja: {},
          distribuicaoPorEstado: {},
        },
        voluntarios: [],
        geradoEm: new Date().toISOString(),
        escopoAtor: 'PASTOR_LOCAL',
      };
    }
  }

  if (escopo.papel === 'RESPONSAVEL_EQUIPE') {
    if (filtros.equipeId && !escopo.equipesIds.includes(filtros.equipeId)) {
      return {
        metricas: {
          totalVoluntarios: 0,
          totalFichasAtivas: 0,
          totalParticipacoesAtivas: 0,
          totalAguardandoAprovacao: 0,
          totalCanceladasOuInativas: 0,
          distribuicaoPorEquipe: {},
          distribuicaoPorIgreja: {},
          distribuicaoPorEstado: {},
        },
        voluntarios: [],
        geradoEm: new Date().toISOString(),
        escopoAtor: 'RESPONSAVEL_EQUIPE',
      };
    }
  }

  // Registrar auditoria probatória de relatório se Coordenador/Admin (AD-8, AD-12)
  if (escopo.papel === 'GLOBAL') {
    const cmdIdAudit = `REPORT_QUERY_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const corrId = correlationId ?? cmdIdAudit;
    try {
      await db.collection('auditoria').doc(cmdIdAudit).set({
        id: cmdIdAudit,
        commandId: cmdIdAudit,
        correlationId: corrId,
        atorUid,
        acao: 'CONSULTA_RELATORIO_OPERACIONAL',
        entidades: [{ tipo: 'SISTEMA', id: 'RELATORIOS' }],
        antes: null,
        depois: null,
        metadados: { filtros: sanitizarDadoAuditoria(filtros) },
        timestampOriginal: FieldValue.serverTimestamp(),
        materializadoEm: FieldValue.serverTimestamp(),
        versaoSchema: 1,
        sanitizado: true,
      });
    } catch (auditErr) {
      logger.warn('Não foi possível registrar auditoria da consulta de relatório:', auditErr);
    }
  }

  // Carregar catálogo de igrejas e equipes para resolução de nomes
  const mapasNomesIgrejas = new Map<string, string>();
  const snapIgrejas = await db.collection('igrejas').get();
  for (const doc of snapIgrejas.docs) {
    mapasNomesIgrejas.set(doc.id, String(doc.data()?.nome ?? doc.id));
  }

  const mapasNomesEquipes = new Map<string, string>();
  const snapEquipes = await db.collection('equipes').get();
  for (const doc of snapEquipes.docs) {
    mapasNomesEquipes.set(doc.id, String(doc.data()?.nome ?? doc.id));
  }

  // Carregar fichas
  const snapFichas = await db.collection('fichas').get();
  const fichasPermitidas: Array<{
    id: string;
    data: Record<string, unknown>;
  }> = [];

  for (const doc of snapFichas.docs) {
    const d = doc.data() ?? {};
    const igId = String(d.igrejaId ?? '');

    if (escopo.papel === 'PASTOR_LOCAL') {
      if (!escopo.igrejasIds.includes(igId)) continue;
    }

    if (filtros.igrejaId && igId !== filtros.igrejaId) continue;
    if (filtros.estado && String(d.estado ?? '').toUpperCase() !== filtros.estado.toUpperCase()) continue;

    fichasPermitidas.push({ id: doc.id, data: d });
  }

  // Carregar participações
  const snapParticipacoes = await db.collection('participacoes').get();
  const participacoesPorFicha = new Map<string, Array<Record<string, unknown>>>();

  for (const doc of snapParticipacoes.docs) {
    const part = doc.data() ?? {};
    const fichaId = String(part.fichaId ?? doc.id.split('_')[0] ?? '');
    const eqId = String(part.equipeId ?? '');

    if (escopo.papel === 'RESPONSAVEL_EQUIPE') {
      if (!escopo.equipesIds.includes(eqId)) continue;
    }

    if (filtros.equipeId && eqId !== filtros.equipeId) continue;

    if (!participacoesPorFicha.has(fichaId)) {
      participacoesPorFicha.set(fichaId, []);
    }
    participacoesPorFicha.get(fichaId)!.push({ ...part, id: doc.id });
  }

  // Para Responsável de Equipe, manter apenas fichas que possuem participações em suas equipes
  let fichasFiltradas = fichasPermitidas;
  if (escopo.papel === 'RESPONSAVEL_EQUIPE' || filtros.equipeId) {
    fichasFiltradas = fichasPermitidas.filter((f) => participacoesPorFicha.has(f.id));
  }

  // Calcular métricas
  let totalParticipacoesAtivas = 0;
  let totalAguardandoAprovacao = 0;
  let totalCanceladasOuInativas = 0;
  const distEquipe: Record<string, number> = {};
  const distIgreja: Record<string, number> = {};
  const distEstado: Record<string, number> = {};

  const listaVoluntarios: VoluntarioItemRelatorio[] = [];

  for (const f of fichasFiltradas) {
    const estadoFicha = String(f.data.estado ?? 'RASCUNHO').toUpperCase();
    const igId = String(f.data.igrejaId ?? 'SEM_IGREJA');
    const igNome = mapasNomesIgrejas.get(igId) ?? igId;

    distEstado[estadoFicha] = (distEstado[estadoFicha] ?? 0) + 1;
    distIgreja[igNome] = (distIgreja[igNome] ?? 0) + 1;

    if (estadoFicha.startsWith('AGUARDANDO')) {
      totalAguardandoAprovacao++;
    } else if (estadoFicha === 'CANCELADA' || estadoFicha === 'INATIVA' || estadoFicha === 'EXPIRADA') {
      totalCanceladasOuInativas++;
    }

    const parts = participacoesPorFicha.get(f.id) ?? [];
    const equipesResumo: VoluntarioItemRelatorio['equipes'] = [];

    for (const p of parts) {
      const eqId = String(p.equipeId ?? '');
      const eqNome = mapasNomesEquipes.get(eqId) ?? eqId;
      const stPart = String(p.estado ?? 'RASCUNHO').toUpperCase();
      const ano = typeof p.anoVigencia === 'number' ? p.anoVigencia : undefined;

      if (stPart === 'ATIVA') {
        totalParticipacoesAtivas++;
      }
      distEquipe[eqNome] = (distEquipe[eqNome] ?? 0) + 1;

      equipesResumo.push({
        equipeId: eqId,
        equipeNome: eqNome,
        estado: stPart,
        anoVigencia: ano,
      });
    }

    listaVoluntarios.push({
      fichaId: f.id,
      nomeCompleto: String(f.data.nomeCompleto ?? 'Voluntário'),
      cpfMascarado: mascararCpfSeguro(f.data.cpf),
      igrejaId: igId,
      igrejaNome: igNome,
      estadoFicha,
      equipes: equipesResumo,
    });
  }

  const metricas: MetricasRelatorioOperacional = {
    totalVoluntarios: listaVoluntarios.length,
    totalFichasAtivas: listaVoluntarios.filter((v) => v.estadoFicha === 'ATIVA').length,
    totalParticipacoesAtivas,
    totalAguardandoAprovacao,
    totalCanceladasOuInativas,
    distribuicaoPorEquipe: distEquipe,
    distribuicaoPorIgreja: distIgreja,
    distribuicaoPorEstado: distEstado,
  };

  return {
    metricas,
    voluntarios: listaVoluntarios,
    geradoEm: new Date().toISOString(),
    escopoAtor: escopo.papel,
  };
}

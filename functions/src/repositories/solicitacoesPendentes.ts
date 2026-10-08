import {
  type Firestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';

export interface SolicitacaoPendenteItem {
  participacaoId: string;
  fichaId: string;
  equipeId: string;
  equipeNome: string;
  estado: string;
  proximaAcao: string;
  enviadoEm: string;
  nomeVoluntario: string;
  profissao: string;
  cpfMascarado: string;
  cpfDigitos: string;
  igrejaId: string;
  igrejaNome: string;
  igrejaCodigo: string;
  pastorAprovou?: boolean;
  responsavelAprovou?: boolean;
}

export interface ResultadoSolicitacoesPendentesGlobal {
  solicitacoes: SolicitacaoPendenteItem[];
  totalGeral: number;
  geradoEm: string;
}

function iso(valor: unknown): string {
  if (!valor) return '';
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

const ESTADOS_PENDENTES_VALIDOS = [
  'AGUARDANDO_PASTOR_LOCAL',
  'AGUARDANDO_RESPONSAVEL_EQUIPE',
  'AGUARDANDO_COORDENADOR',
];

/**
 * Consulta todas as solicitações de participação pendentes no sistema,
 * exclusiva para administradores gerais.
 */
export async function consultarSolicitacoesPendentesGlobalRepo(
  db: Firestore,
  solicitanteUid: string,
): Promise<ResultadoSolicitacoesPendentesGlobal> {
  const autoridadeDoc = await db
    .collection('autoridadesAdministrativas')
    .doc(solicitanteUid)
    .get();

  if (!podeAdministrar(autoridadeDoc.data())) {
    throw new Error('SEM_AUTORIDADE_ADMINISTRATIVA');
  }

  // 1. Busca todas as participações em estados pendentes
  const participacoesSnap = await db
    .collection('participacoes')
    .where('estado', 'in', ESTADOS_PENDENTES_VALIDOS)
    .limit(500)
    .get();

  if (participacoesSnap.empty) {
    return {
      solicitacoes: [],
      totalGeral: 0,
      geradoEm: new Date().toISOString(),
    };
  }

  // 2. Coleta IDs únicos de fichas, equipes e igrejas para carregamento em lote/cache
  const fichaIds = new Set<string>();
  const equipeIds = new Set<string>();

  for (const doc of participacoesSnap.docs) {
    const d = doc.data();
    if (d.fichaId) fichaIds.add(String(d.fichaId));
    if (d.equipeId) equipeIds.add(String(d.equipeId));
  }

  const [fichasSnaps, equipesSnaps, igrejasSnaps] = await Promise.all([
    Promise.all([...fichaIds].map((id) => db.collection('fichas').doc(id).get())),
    Promise.all([...equipeIds].map((id) => db.collection('equipes').doc(id).get())),
    db.collection('igrejas').get(),
  ]);

  const fichasMap = new Map<string, Record<string, unknown>>();
  for (const doc of fichasSnaps) {
    if (doc.exists) fichasMap.set(doc.id, doc.data() ?? {});
  }

  const equipesMap = new Map<string, string>();
  for (const doc of equipesSnaps) {
    if (doc.exists) {
      equipesMap.set(doc.id, String(doc.data()?.nome ?? doc.id));
    }
  }

  const igrejasMap = new Map<string, { nome: string; codigo: string }>();
  for (const doc of igrejasSnaps.docs) {
    const d = doc.data() ?? {};
    igrejasMap.set(doc.id, {
      nome: String(d.nome ?? doc.id),
      codigo: String(d.codigo ?? ''),
    });
  }

  // 3. Monta e enriquece a lista de solicitações
  const solicitacoes: SolicitacaoPendenteItem[] = [];

  for (const doc of participacoesSnap.docs) {
    const p = doc.data() ?? {};
    const fichaId = String(p.fichaId ?? '');
    const equipeId = String(p.equipeId ?? '');
    const ficha = fichasMap.get(fichaId) ?? {};
    const igrejaId = String(ficha.igrejaId ?? p.igrejaId ?? '');
    const igrejaInfo = igrejasMap.get(igrejaId) ?? { nome: igrejaId, codigo: '' };

    const cpfOriginal = String(ficha.cpf ?? '').replace(/\D/g, '');
    const decPastor = p.decisaoPastor as Record<string, unknown> | undefined;
    const decResp = p.decisaoResponsavel as Record<string, unknown> | undefined;

    solicitacoes.push({
      participacaoId: doc.id,
      fichaId,
      equipeId,
      equipeNome: equipesMap.get(equipeId) ?? String(p.nomeEquipe ?? equipeId),
      estado: String(p.estado ?? 'AGUARDANDO_PASTOR_LOCAL'),
      proximaAcao: String(p.proximaAcao ?? 'Em análise'),
      enviadoEm: iso(p.enviadoEm || ficha.enviadoEm || p.criadoEm),
      nomeVoluntario: String(ficha.nomeCompleto ?? 'Voluntário').trim(),
      profissao: String(ficha.profissao ?? '').trim(),
      cpfMascarado: mascararCpf(cpfOriginal),
      cpfDigitos: cpfOriginal,
      igrejaId,
      igrejaNome: igrejaInfo.nome,
      igrejaCodigo: igrejaInfo.codigo,
      pastorAprovou: decPastor?.estado === 'APROVADO',
      responsavelAprovou: decResp?.estado === 'APROVADO',
    });
  }

  // Ordena por data de envio (mais antigas primeiro para priorização na fila)
  solicitacoes.sort((a, b) => a.enviadoEm.localeCompare(b.enviadoEm));

  return {
    solicitacoes,
    totalGeral: solicitacoes.length,
    geradoEm: new Date().toISOString(),
  };
}

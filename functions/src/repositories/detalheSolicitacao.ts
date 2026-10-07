import { type Firestore } from 'firebase-admin/firestore';
import {
  PAPEL_COORDENADOR,
  podeAdministrar,
  possuiPapel,
} from '../domain/autoridadeAdministrativa.js';
import {
  SemVinculoVigenteError,
  SolicitacaoNaoEncontradaError,
  type DetalheSolicitacao,
  type PapelAcessoDetalhe,
  type ParticipacaoDetalhe,
} from '../domain/detalheSolicitacao.js';

/** Teto de leitura das participações do detalhe (AD-9). */
const LIMITE_PARTICIPACOES_DETALHE = 100;

/**
 * Valida que o vínculo referenciado está VIGENTE e pertence ao usuário.
 * Ausência de referência de vínculo é aceita apenas para compatibilidade com
 * registros legados; se houver referência, ela precisa resolver para VIGENTE.
 */
async function vinculoVigenteValido(
  db: Firestore,
  colecao: 'vinculosPastorIgreja' | 'vinculosPastorEquipe',
  vinculoId: string,
  uid: string,
): Promise<boolean> {
  if (!vinculoId) {
    return true;
  }
  const snap = await db.collection(colecao).doc(vinculoId).get();
  if (!snap.exists) {
    return false;
  }
  const dados = snap.data() ?? {};
  return dados.estado === 'VIGENTE' && String(dados.pessoaId ?? '') === uid;
}

function decisaoDaParticipacao(dados: Record<string, unknown>): string | null {
  const candidatos = [
    dados.decisaoPastoral,
    dados.decisaoPastorLocal,
    dados.decisaoResponsavel,
    dados.decisaoCoordenador,
  ];
  for (const candidato of candidatos) {
    if (candidato && typeof candidato === 'object') {
      const decisao = (candidato as Record<string, unknown>).decisao;
      if (typeof decisao === 'string' && decisao.trim()) {
        return decisao;
      }
    }
  }
  return null;
}

/**
 * Reautoriza, no momento da consulta, o acesso a uma solicitação e retorna a
 * projeção interna autorizada. O escopo é estritamente territorial (igreja) ou
 * funcional (equipe) e é bloqueado assim que o vínculo expira/é substituído.
 */
export async function obterDetalheSolicitacaoRepo(
  db: Firestore,
  uid: string,
  fichaId: string,
): Promise<DetalheSolicitacao> {
  const fichaSnap = await db.collection('fichas').doc(fichaId).get();
  if (!fichaSnap.exists) {
    throw new SolicitacaoNaoEncontradaError();
  }

  const ficha = fichaSnap.data() ?? {};
  const voluntarioUid = String(ficha.ownerUid ?? fichaSnap.id);
  const igrejaId = String(ficha.igrejaId ?? '').trim();

  const participacoesSnap = await db
    .collection('participacoes')
    .where('fichaId', '==', fichaId)
    .limit(LIMITE_PARTICIPACOES_DETALHE)
    .get();
  const participacoesDocs = participacoesSnap.docs;

  let papel: PapelAcessoDetalhe | null = null;
  let vinculoId = '';

  // 1. O próprio voluntário sempre pode ver a sua solicitação.
  if (voluntarioUid === uid) {
    papel = 'VOLUNTARIO';
  }

  // 2. Pastor Local vigente da igreja da ficha.
  if (!papel && igrejaId) {
    const igrejaSnap = await db.collection('igrejas').doc(igrejaId).get();
    const igreja = igrejaSnap.data() ?? {};
    if (
      igrejaSnap.exists &&
      igreja.ativo !== false &&
      igreja.pastorLocalVigentePessoaId === uid
    ) {
      const candidato = String(igreja.pastorLocalVigenteVinculoId ?? '');
      if (await vinculoVigenteValido(db, 'vinculosPastorIgreja', candidato, uid)) {
        papel = 'PASTOR_LOCAL';
        vinculoId = candidato;
      }
    }
  }

  // 3. Responsável vigente de alguma equipe solicitada na ficha.
  if (!papel) {
    for (const doc of participacoesDocs) {
      const equipeId = String(doc.data()?.equipeId ?? '');
      if (!equipeId) continue;
      const equipeSnap = await db.collection('equipes').doc(equipeId).get();
      const equipe = equipeSnap.data() ?? {};
      if (equipe.responsavelVigentePessoaId === uid) {
        const candidato = String(equipe.responsavelVigenteVinculoId ?? '');
        if (await vinculoVigenteValido(db, 'vinculosPastorEquipe', candidato, uid)) {
          papel = 'RESPONSAVEL_EQUIPE';
          vinculoId = candidato;
          break;
        }
      }
    }
  }

  // 4. Coordenador Geral / Administrador (agregado canônico de autoridade).
  if (!papel) {
    const autoridadeSnap = await db
      .collection('autoridadesAdministrativas')
      .doc(uid)
      .get();
    const autoridade = autoridadeSnap.data();
    if (
      autoridadeSnap.exists &&
      (podeAdministrar(autoridade) || possuiPapel(autoridade, PAPEL_COORDENADOR))
    ) {
      papel = 'COORDENADOR';
    }
  }

  if (!papel) {
    throw new SemVinculoVigenteError();
  }

  const participacoes: ParticipacaoDetalhe[] = participacoesDocs
    .map((doc) => {
      const d = doc.data() ?? {};
      return {
        id: doc.id,
        equipeId: String(d.equipeId ?? ''),
        nomeEquipe: String(d.nomeEquipe ?? ''),
        estado: String(d.estado ?? 'RASCUNHO'),
        ciclo: String(d.ciclo ?? 'INICIAL'),
        proximaAcao: String(d.proximaAcao ?? ''),
        decisao: decisaoDaParticipacao(d),
      };
    })
    .sort((a, b) => a.nomeEquipe.localeCompare(b.nomeEquipe));

  return {
    fichaId,
    voluntarioUid,
    voluntarioNome: String(ficha.nomeCompleto ?? ''),
    igrejaId,
    estadoFicha: String(ficha.estado ?? 'RASCUNHO'),
    versao: Number(ficha.versao ?? 1),
    papelSolicitante: papel,
    vinculoId,
    reautorizadoEm: new Date().toISOString(),
    participacoes,
  };
}

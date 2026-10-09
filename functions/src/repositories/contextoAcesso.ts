import type { Firestore } from 'firebase-admin/firestore';
import {
  PAPEL_COORDENADOR,
  podeAdministrar,
  possuiPapel,
} from '../domain/autoridadeAdministrativa.js';
import {
  ContextoAcessoDTO,
  EscopoEquipeDTO,
  EscopoIgrejaDTO,
  derivarCapacidades,
} from '../domain/contextoAcesso.js';

export async function obterContextoAcessoRepo(
  db: Firestore,
  uid: string,
  email?: string,
): Promise<ContextoAcessoDTO> {
  // 1. Autoridade administrativa e de coordenação
  let ehAdmin = false;
  let ehCoord = false;

  const autoridadeDoc = await db.collection('autoridadesAdministrativas').doc(uid).get();
  if (autoridadeDoc.exists) {
    const dados = autoridadeDoc.data();
    if (podeAdministrar(dados)) {
      ehAdmin = true;
    }
    if (possuiPapel(dados, PAPEL_COORDENADOR)) {
      ehCoord = true;
    }
  }

  // 2. Igrejas sob responsabilidade pastoral vigente
  const igrejasMap = new Map<string, EscopoIgrejaDTO>();

  const igrejasDirectSnap = await db
    .collection('igrejas')
    .where('pastorLocalVigentePessoaId', '==', uid)
    .get();

  for (const doc of igrejasDirectSnap.docs) {
    const d = doc.data() ?? {};
    if (d.ativo !== false) {
      igrejasMap.set(doc.id, {
        id: doc.id,
        nome: String(d.nome ?? doc.id),
        codigo: d.codigo ? String(d.codigo) : undefined,
      });
    }
  }

  // Vínculos históricos complementam o catálogo apenas quando consistentes com
  // o responsável canônico vigente (reconciliação e deduplicação por id).
  const vinculosPastorSnap = await db
    .collection('vinculosPastorIgreja')
    .where('pessoaId', '==', uid)
    .where('estado', '==', 'VIGENTE')
    .get();

  const idsIgrejasVinculo = [
    ...new Set(
      vinculosPastorSnap.docs
        .map((doc) => String((doc.data() ?? {}).entidadeId ?? ''))
        .filter((id) => id && !igrejasMap.has(id)),
    ),
  ];

  if (idsIgrejasVinculo.length > 0) {
    const igrejasVinculo = await db.getAll(
      ...idsIgrejasVinculo.map((id) => db.collection('igrejas').doc(id)),
    );
    for (const igDoc of igrejasVinculo) {
      const d = igDoc.data() ?? {};
      const pastorCanonico = d.pastorLocalVigentePessoaId;
      if (
        typeof pastorCanonico === 'string' &&
        pastorCanonico !== '' &&
        pastorCanonico !== uid
      ) {
        continue;
      }
      if (igDoc.exists && d.ativo !== false) {
        igrejasMap.set(igDoc.id, {
          id: igDoc.id,
          nome: String(d.nome ?? igDoc.id),
          codigo: d.codigo ? String(d.codigo) : undefined,
        });
      }
    }
  }

  // 3. Equipes sob responsabilidade de equipe vigente
  const equipesMap = new Map<string, EscopoEquipeDTO>();

  const equipesDirectSnap = await db
    .collection('equipes')
    .where('responsavelVigentePessoaId', '==', uid)
    .get();

  for (const doc of equipesDirectSnap.docs) {
    const d = doc.data() ?? {};
    if (d.ativo !== false) {
      equipesMap.set(doc.id, {
        id: doc.id,
        nome: String(d.nome ?? doc.id),
      });
    }
  }

  const vinculosRespSnap = await db
    .collection('vinculosResponsavelEquipe')
    .where('pessoaId', '==', uid)
    .where('estado', '==', 'VIGENTE')
    .get();

  const idsEquipesVinculo = [
    ...new Set(
      vinculosRespSnap.docs
        .map((doc) => String((doc.data() ?? {}).entidadeId ?? ''))
        .filter((id) => id && !equipesMap.has(id)),
    ),
  ];

  if (idsEquipesVinculo.length > 0) {
    const equipesVinculo = await db.getAll(
      ...idsEquipesVinculo.map((id) => db.collection('equipes').doc(id)),
    );
    for (const eqDoc of equipesVinculo) {
      const d = eqDoc.data() ?? {};
      const responsavelCanonico = d.responsavelVigentePessoaId;
      if (
        typeof responsavelCanonico === 'string' &&
        responsavelCanonico !== '' &&
        responsavelCanonico !== uid
      ) {
        continue;
      }
      if (eqDoc.exists && d.ativo !== false) {
        equipesMap.set(eqDoc.id, {
          id: eqDoc.id,
          nome: String(d.nome ?? eqDoc.id),
        });
      }
    }
  }

  // 4. Estado da ficha permanente (se houver)
  let estadoFicha: string | null = null;
  const fichaDoc = await db.collection('fichas').doc(uid).get();
  if (fichaDoc.exists) {
    estadoFicha = fichaDoc.data()?.estado ? String(fichaDoc.data()?.estado) : null;
  }

  const listaIgrejas = Array.from(igrejasMap.values());
  const listaEquipes = Array.from(equipesMap.values());

  const capacidades = derivarCapacidades({
    ehAdmin,
    ehCoord,
    temIgrejas: listaIgrejas.length > 0,
    temEquipes: listaEquipes.length > 0,
  });

  return {
    uid,
    email,
    capacidades,
    ehAdministrador: ehAdmin,
    ehCoordenador: ehCoord,
    ehPastorLocal: listaIgrejas.length > 0,
    ehResponsavelEquipe: listaEquipes.length > 0,
    ehVoluntario: true,
    igrejas: listaIgrejas,
    equipes: listaEquipes,
    estadoFicha,
  };
}

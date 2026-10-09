import type { Firestore } from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
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
    if (dados?.coordenadorGeral === true && dados?.ativo !== false) {
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

  const vinculosPastorSnap = await db
    .collection('vinculosPastorIgreja')
    .where('pessoaId', '==', uid)
    .where('estado', '==', 'VIGENTE')
    .get();

  for (const doc of vinculosPastorSnap.docs) {
    const v = doc.data() ?? {};
    const igId = String(v.entidadeId ?? '');
    if (igId && !igrejasMap.has(igId)) {
      const igDoc = await db.collection('igrejas').doc(igId).get();
      if (igDoc.exists && igDoc.data()?.ativo !== false) {
        const d = igDoc.data() ?? {};
        igrejasMap.set(igId, {
          id: igId,
          nome: String(d.nome ?? igId),
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

  for (const doc of vinculosRespSnap.docs) {
    const v = doc.data() ?? {};
    const eqId = String(v.entidadeId ?? '');
    if (eqId && !equipesMap.has(eqId)) {
      const eqDoc = await db.collection('equipes').doc(eqId).get();
      if (eqDoc.exists && eqDoc.data()?.ativo !== false) {
        const d = eqDoc.data() ?? {};
        equipesMap.set(eqId, {
          id: eqId,
          nome: String(d.nome ?? eqId),
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
    temFichaOuUsuario: true,
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

import { FieldValue, type Firestore, type QuerySnapshot } from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  DatasetInvalidoError,
  SemAutoridadeError,
  chaveEquipe,
  equipesAusentes,
  hashDataset,
  idEquipeSeed,
  idIgrejaSeed,
  igrejasAusentes,
  pesquisarEquipes,
  pesquisarIgrejas,
  rotuloIgreja,
  validarDataset,
  type ContextoSeedCatalogo,
  type EquipeCatalogo,
  type IgrejaCatalogo,
  type ResultadoSemeadura,
  type ResumoCatalogo,
} from '../domain/catalogo.js';
import { DATASET_CATALOGO } from '../domain/seedCatalogo.js';

const ACAO_RECIBO = 'SEMEAR_CATALOGO_INICIAL';
const ACAO_AUDITORIA = 'CATALOGO_SEMEADO';

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor : '';
}

function mapearIgreja(id: string, dados: Record<string, unknown>): IgrejaCatalogo {
  return {
    id,
    codigo: String(dados.codigo ?? ''),
    nome: texto(dados.nome),
    ativo: dados.ativo === true,
  };
}

function mapearEquipe(id: string, dados: Record<string, unknown>): EquipeCatalogo {
  const nome = texto(dados.nome);
  return {
    id,
    nome,
    nomeNormalizado: chaveEquipe(nome),
    ativo: dados.ativo === true,
  };
}

/**
 * Seed idempotente e transacional do catálogo inicial. A autoridade canônica é
 * validada dentro da transação; só o ausente é criado e nenhum registro
 * existente é sobrescrito. Recibo e auditoria são gravados no mesmo commit.
 */
export async function semearCatalogo(
  db: Firestore,
  contexto: ContextoSeedCatalogo,
): Promise<ResultadoSemeadura> {
  const dataset = DATASET_CATALOGO;
  // Guarda de runtime: um dataset editado ou inválido falha antes de qualquer
  // mutação em vez de semear silenciosamente zero registros.
  const problemas = validarDataset(dataset);
  if (problemas.length > 0) throw new DatasetInvalidoError(problemas);
  const payloadHash = hashDataset(dataset);
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return db.runTransaction(async (tx) => {
    const atorRef = db
      .collection('autoridadesAdministrativas')
      .doc(contexto.atorUid);
    const [atorSnap, reciboSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      // Replay só é aceito quando o conteúdo, a ação e o autor coincidem; um
      // comando divergente é recusado sem reexecutar a mutação.
      if (
        recibo.action !== ACAO_RECIBO ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        repetido: true,
        datasetVersao: dataset.versao,
        igrejasCriadas: Number(recibo.igrejasCriadas ?? 0),
        equipesCriadas: Number(recibo.equipesCriadas ?? 0),
        totalIgrejas: dataset.igrejas.length,
        totalEquipes: dataset.equipes.length,
      };
    }

    const [igrejasSnap, equipesSnap] = await Promise.all([
      tx.get(db.collection('igrejas')),
      tx.get(db.collection('equipes')),
    ]);
    const igrejasExistentes = igrejasSnap.docs.map((doc) =>
      mapearIgreja(doc.id, doc.data()),
    );
    const equipesExistentes = equipesSnap.docs.map((doc) =>
      mapearEquipe(doc.id, doc.data()),
    );

    const criarIgrejas = igrejasAusentes(dataset, igrejasExistentes);
    const criarEquipes = equipesAusentes(dataset, equipesExistentes);

    for (const igreja of criarIgrejas) {
      const ref = db.collection('igrejas').doc(idIgrejaSeed(igreja.codigo));
      tx.create(ref, {
        codigo: igreja.codigo,
        nome: igreja.nome,
        ativo: true,
        origem: contexto.origem,
        datasetVersao: dataset.versao,
        criadoEm: FieldValue.serverTimestamp(),
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }
    for (const equipe of criarEquipes) {
      const ref = db.collection('equipes').doc(idEquipeSeed(equipe.nome));
      tx.create(ref, {
        nome: equipe.nome,
        nomeNormalizado: chaveEquipe(equipe.nome),
        ativo: true,
        origem: contexto.origem,
        datasetVersao: dataset.versao,
        criadoEm: FieldValue.serverTimestamp(),
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO,
      estado: 'COMPLETO',
      payloadHash,
      datasetVersao: dataset.versao,
      igrejasCriadas: criarIgrejas.length,
      equipesCriadas: criarEquipes.length,
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });
    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_AUDITORIA,
      datasetVersao: dataset.versao,
      antes: {
        igrejas: igrejasExistentes.length,
        equipes: equipesExistentes.length,
      },
      depois: {
        igrejasCriadas: criarIgrejas.length,
        equipesCriadas: criarEquipes.length,
      },
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      repetido: false,
      datasetVersao: dataset.versao,
      igrejasCriadas: criarIgrejas.length,
      equipesCriadas: criarEquipes.length,
      totalIgrejas: dataset.igrejas.length,
      totalEquipes: dataset.equipes.length,
    };
  });
}

/** Consulta autorizada e read-only; ordenada por nome e filtrável por termo. */
export async function lerCatalogo(
  db: Firestore,
  termo = '',
): Promise<ResumoCatalogo> {
  const [igrejasSnap, equipesSnap] = await Promise.all([
    db.collection('igrejas').get(),
    db.collection('equipes').get(),
  ]);
  const igrejas = igrejasSnap.docs.map((doc) => mapearIgreja(doc.id, doc.data()));
  const equipes = equipesSnap.docs.map((doc) => mapearEquipe(doc.id, doc.data()));
  return {
    igrejas: pesquisarIgrejas(igrejas, termo).map((igreja) => ({
      ...igreja,
      rotulo: rotuloIgreja(igreja),
    })),
    equipes: pesquisarEquipes(equipes, termo),
  };
}


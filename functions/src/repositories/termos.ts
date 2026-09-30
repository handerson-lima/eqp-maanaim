import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  SemAutoridadeError,
  TERMO_ID_PADRAO,
  type EntradaPublicarTermo,
  type TermoResumo,
  type VersaoTermoResumo,
} from '../domain/termos.js';

export const ORIGEM_TERMOS = 'administracao-termos-publicacao';
const ACAO_RECIBO = 'PUBLICAR_TERMO';

export interface ContextoTermo {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
}

export interface ResultadoPublicarTermo {
  repetido: boolean;
  termoId: string;
  versaoId: string;
  numeroVersao: number;
  hashSha256: string;
  totalVoluntariosImpactados: number;
}

function iso(valor: unknown): string {
  if (!valor) return '';
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return '';
}

/**
 * Publica de forma atômica e imutável uma nova versão do termo,
 * garantindo idempotência com recibo em `commands` e registro em `auditOutbox`.
 */
export async function publicarTermo(
  db: Firestore,
  contexto: ContextoTermo,
  entrada: EntradaPublicarTermo,
): Promise<ResultadoPublicarTermo> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const autoridadeRef = db.collection('autoridadesAdministrativas').doc(contexto.atorUid);
  const termoRef = db.collection('termos').doc(entrada.termoId);

  return await db.runTransaction(async (tx) => {
    // 1. Verificação de idempotência no recibo
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      return {
        repetido: true,
        termoId: String(dadosRecibo.termoId ?? entrada.termoId),
        versaoId: String(dadosRecibo.versaoId ?? ''),
        numeroVersao: Number(dadosRecibo.numeroVersao ?? 0),
        hashSha256: String(dadosRecibo.hashSha256 ?? entrada.hashConteudo),
        totalVoluntariosImpactados: Number(dadosRecibo.totalVoluntariosImpactados ?? 0),
      };
    }

    // 2. Validação da autoridade administrativa em transação
    const autoridadeSnap = await tx.get(autoridadeRef);
    if (!podeAdministrar(autoridadeSnap.data())) {
      throw new SemAutoridadeError();
    }

    // 3. Verificação de versão atual do termo pai
    const termoSnap = await tx.get(termoRef);
    let versaoVigenteNumero = 0;
    let versaoAnteriorId: string | null = null;

    if (termoSnap.exists) {
      const dadosTermo = termoSnap.data() ?? {};
      versaoVigenteNumero = Number(dadosTermo.versaoVigenteNumero ?? 0);
      versaoAnteriorId = (dadosTermo.versaoVigenteId as string) || null;

      if (entrada.expectedVersion !== versaoVigenteNumero) {
        throw new ConflitoVersaoError();
      }
    } else {
      if (entrada.expectedVersion !== 0) {
        throw new ConflitoVersaoError();
      }
    }

    const proximaVersao = versaoVigenteNumero + 1;

    // 4. Identificação de voluntários ativos impactados (sem tocar aceites anteriores)
    // Para a primeira versão ou base inicial, se a coleção não existir ou for vazia, total = 0
    let totalVoluntariosImpactados = 0;
    try {
      const fichasAtivasSnap = await tx.get(
        db.collection('fichas').where('estado', '==', 'ATIVA'),
      );
      totalVoluntariosImpactados = fichasAtivasSnap.size;
    } catch {
      totalVoluntariosImpactados = 0;
    }

    // 5. Criação do documento imutável da nova versão
    const versaoRef = termoRef.collection('versoes').doc();
    const versaoId = versaoRef.id;

    tx.create(versaoRef, {
      id: versaoId,
      termoId: entrada.termoId,
      numeroVersao: proximaVersao,
      titulo: entrada.titulo,
      conteudo: entrada.conteudo,
      hashSha256: entrada.hashConteudo,
      publicadoPorUid: contexto.atorUid,
      publicadoEm: FieldValue.serverTimestamp(),
      versaoAnteriorId,
      imutavel: true,
    });

    // 6. Atualização ou criação do termo canônico pai
    if (termoSnap.exists) {
      tx.update(termoRef, {
        titulo: entrada.titulo,
        versaoVigenteId: versaoId,
        versaoVigenteNumero: proximaVersao,
        hashSha256: entrada.hashConteudo,
        totalVersoes: proximaVersao,
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(termoRef, {
        id: entrada.termoId,
        tipoTermo: entrada.tipoTermo,
        titulo: entrada.titulo,
        versaoVigenteId: versaoId,
        versaoVigenteNumero: proximaVersao,
        hashSha256: entrada.hashConteudo,
        totalVersoes: 1,
        ativo: true,
        criadoEm: FieldValue.serverTimestamp(),
        atualizadoEm: FieldValue.serverTimestamp(),
      });
    }

    // 7. Recibo atômico (sem PII)
    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO,
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      termoId: entrada.termoId,
      versaoId,
      numeroVersao: proximaVersao,
      hashSha256: entrada.hashConteudo,
      totalVoluntariosImpactados,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 8. Entrada no auditOutbox (sem PII)
    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO,
      termoId: entrada.termoId,
      versaoId,
      numeroVersao: proximaVersao,
      hashSha256: entrada.hashConteudo,
      versaoAnteriorId,
      totalVoluntariosImpactados,
      origem: contexto.origem,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      repetido: false,
      termoId: entrada.termoId,
      versaoId,
      numeroVersao: proximaVersao,
      hashSha256: entrada.hashConteudo,
      totalVoluntariosImpactados,
    };
  });
}

/**
 * Consulta a lista completa de versões do termo para administradores.
 */
export async function consultarTermosRepo(
  db: Firestore,
  atorUid: string,
  termoId = TERMO_ID_PADRAO,
): Promise<TermoResumo | null> {
  const autoridadeDoc = await db.collection('autoridadesAdministrativas').doc(atorUid).get();
  if (!podeAdministrar(autoridadeDoc.data())) {
    throw new SemAutoridadeError();
  }

  const termoDoc = await db.collection('termos').doc(termoId).get();
  if (!termoDoc.exists) {
    return null;
  }

  const termoData = termoDoc.data() ?? {};
  const versoesSnap = await db
    .collection('termos')
    .doc(termoId)
    .collection('versoes')
    .orderBy('numeroVersao', 'desc')
    .get();

  const versoes: VersaoTermoResumo[] = versoesSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      termoId,
      numeroVersao: Number(d.numeroVersao ?? 0),
      titulo: String(d.titulo ?? ''),
      conteudo: String(d.conteudo ?? ''),
      hashSha256: String(d.hashSha256 ?? ''),
      publicadoEm: iso(d.publicadoEm),
      publicadoPorUid: String(d.publicadoPorUid ?? ''),
      versaoAnteriorId: (d.versaoAnteriorId as string) || null,
      imutavel: Boolean(d.imutavel ?? true),
    };
  });

  return {
    id: termoDoc.id,
    tipoTermo: termoData.tipoTermo ?? 'ADESAO_VOLUNTARIADO',
    titulo: String(termoData.titulo ?? ''),
    versaoVigenteId: String(termoData.versaoVigenteId ?? ''),
    versaoVigenteNumero: Number(termoData.versaoVigenteNumero ?? 0),
    hashSha256: String(termoData.hashSha256 ?? ''),
    totalVersoes: Number(termoData.totalVersoes ?? 0),
    publicadoEm: iso(termoData.criadoEm),
    atualizadoEm: iso(termoData.atualizadoEm),
    ativo: Boolean(termoData.ativo ?? true),
    versoes,
  };
}

/**
 * Obtém a versão vigente do termo para leitura institucional (voluntário ou admin).
 */
export async function obterTermoVigenteRepo(
  db: Firestore,
  termoId = TERMO_ID_PADRAO,
): Promise<VersaoTermoResumo | null> {
  const termoDoc = await db.collection('termos').doc(termoId).get();
  if (!termoDoc.exists) return null;

  const termoData = termoDoc.data() ?? {};
  if (termoData.ativo !== true) return null;

  const versaoVigenteId = termoData.versaoVigenteId as string | undefined;
  if (!versaoVigenteId) return null;

  const versaoDoc = await db
    .collection('termos')
    .doc(termoId)
    .collection('versoes')
    .doc(versaoVigenteId)
    .get();

  if (!versaoDoc.exists) return null;

  const d = versaoDoc.data() ?? {};
  return {
    id: versaoDoc.id,
    termoId,
    numeroVersao: Number(d.numeroVersao ?? 0),
    titulo: String(d.titulo ?? ''),
    conteudo: String(d.conteudo ?? ''),
    hashSha256: String(d.hashSha256 ?? ''),
    publicadoEm: iso(d.publicadoEm),
    publicadoPorUid: String(d.publicadoPorUid ?? ''),
    versaoAnteriorId: (d.versaoAnteriorId as string) || null,
    imutavel: Boolean(d.imutavel ?? true),
  };
}

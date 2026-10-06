import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DeclaracaoNaoInformadaError,
  EquipesNaoSelecionadasError,
  FichaNaoEditavelError,
  FichaNaoEncontradaError,
  PermissaoNegadaError,
  SemAutoridadeError,
  TERMO_ID_PADRAO,
  TermoNaoVigenteError,
  type ComprovanteAceiteTermo,
  type EntradaAceitarTermoVigente,
  type EntradaPublicarTermo,
  type TermoResumo,
  type VersaoTermoResumo,
} from '../domain/termos.js';

export const ORIGEM_TERMOS = 'administracao-termos-publicacao';
const ACAO_RECIBO = 'PUBLICAR_TERMO';
const ACAO_ACEITE = 'ACEITAR_TERMO_VIGENTE';
export const ORIGEM_ACEITE = 'voluntario-aceite-termo';

export interface ContextoTermo {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
}

export interface ContextoAceiteTermo {
  commandId: string;
  correlationId?: string;
  uid: string;
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

/**
 * Registra o aceite eletrônico do termo vigente em transação atômica.
 * - Idempotente via `commands/{commandId}`
 * - Valida existência da ficha e seleção de ao menos uma equipe
 * - Valida versão vigente ativa e integridade do hashSha256
 * - Grava documento imutável em `fichas/{uid}/aceites/{versaoId}`
 * - Atualiza projeção em `fichas/{uid}`
 * - Grava auditoria append-only em `auditOutbox/{commandId}`
 */
export async function aceitarTermoVigenteRepo(
  db: Firestore,
  contexto: ContextoAceiteTermo,
  entrada: EntradaAceitarTermoVigente,
): Promise<ComprovanteAceiteTermo> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(contexto.uid);
  const termoRef = db.collection('termos').doc(entrada.termoId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em `commands`
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new PermissaoNegadaError('Operação indisponível para o usuário informado.');
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      return {
        id: String(dadosRecibo.aceiteId ?? contexto.commandId),
        uid: contexto.uid,
        fichaId: contexto.uid,
        termoId: String(dadosRecibo.termoId ?? entrada.termoId),
        versaoId: String(dadosRecibo.versaoId ?? entrada.versaoId),
        numeroVersao: Number(dadosRecibo.numeroVersao ?? 0),
        hashSha256: String(dadosRecibo.hashSha256 ?? entrada.hashSha256),
        titulo: String(dadosRecibo.titulo ?? ''),
        declaracaoLidoEConcordo: true,
        aceitoEm: iso(dadosRecibo.criadoEm),
        commandId: contexto.commandId,
        repetido: true,
      };
    }

    // 2. Valida se a ficha existe e se está em RASCUNHO
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};
    if (fichaData.estado && fichaData.estado !== 'RASCUNHO') {
      throw new FichaNaoEditavelError('Apenas fichas em rascunho podem ter o termo aceito.');
    }

    // 3. Valida se há ao menos uma equipe/participação cadastrada no rascunho
    const participacoesSnap = await tx.get(
      db.collection('participacoes').where('fichaId', '==', contexto.uid),
    );
    const semParticipacoes =
      !participacoesSnap ||
      participacoesSnap.empty === true ||
      (Array.isArray(participacoesSnap.docs) && participacoesSnap.docs.length === 0);

    if (semParticipacoes) {
      throw new EquipesNaoSelecionadasError();
    }

    // 4. Valida se o termo existe e está ativo
    const termoSnap = await tx.get(termoRef);
    if (!termoSnap.exists || termoSnap.data()?.ativo !== true) {
      throw new TermoNaoVigenteError('Nenhum termo ativo encontrado.');
    }

    const termoData = termoSnap.data() ?? {};
    const versaoVigenteId = termoData.versaoVigenteId as string | undefined;
    if (!versaoVigenteId) {
      throw new TermoNaoVigenteError('Nenhum termo vigente configurado.');
    }

    // 5. Valida se a versão indicada é exatamente a vigente e se o hash bate
    if (entrada.versaoId !== versaoVigenteId) {
      throw new TermoNaoVigenteError();
    }

    const versaoRef = termoRef.collection('versoes').doc(versaoVigenteId);
    const versaoSnap = await tx.get(versaoRef);
    if (!versaoSnap.exists) {
      throw new TermoNaoVigenteError('Versão vigente não encontrada no catálogo.');
    }

    const versaoData = versaoSnap.data() ?? {};
    if (versaoData.hashSha256 !== entrada.hashSha256) {
      throw new TermoNaoVigenteError(
        'Hash de integridade da versão do termo diverge do registro oficial.',
      );
    }

    const numeroVersao = Number(versaoData.numeroVersao ?? termoData.versaoVigenteNumero ?? 1);
    const titulo = String(versaoData.titulo ?? termoData.titulo ?? 'Termo de Adesão');

    // 6. Evidência imutável de aceite (fichas/{uid}/aceites/{versaoVigenteId})
    const aceiteRef = fichaRef.collection('aceites').doc(versaoVigenteId);
    const aceiteSnap = await tx.get(aceiteRef);
    if (aceiteSnap.exists) {
      // A versão vigente já foi aceita anteriormente nesta ficha e sua evidência é imutável!
      const dadosAceite = aceiteSnap.data() ?? {};
      return {
        id: versaoVigenteId,
        uid: contexto.uid,
        fichaId: contexto.uid,
        termoId: String(dadosAceite.termoId ?? entrada.termoId),
        versaoId: versaoVigenteId,
        numeroVersao,
        hashSha256: String(dadosAceite.hashSha256 ?? entrada.hashSha256),
        titulo,
        declaracaoLidoEConcordo: true,
        aceitoEm: iso(dadosAceite.aceitoEm),
        commandId: String(dadosAceite.commandId ?? contexto.commandId),
        repetido: true,
      };
    }
    const aceiteId = versaoVigenteId;

    tx.set(aceiteRef, {
      id: aceiteId,
      uid: contexto.uid,
      fichaId: contexto.uid,
      termoId: entrada.termoId,
      versaoId: versaoVigenteId,
      numeroVersao,
      hashSha256: entrada.hashSha256,
      titulo,
      declaracaoLidoEConcordo: true,
      aceitoEm: FieldValue.serverTimestamp(),
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      imutavel: true,
    });

    // 7. Atualiza projeção do termo aceito na ficha
    tx.update(fichaRef, {
      termoAceito: {
        termoId: entrada.termoId,
        versaoId: versaoVigenteId,
        numeroVersao,
        hashSha256: entrada.hashSha256,
        titulo,
        aceitoEm: FieldValue.serverTimestamp(),
        commandId: contexto.commandId,
      },
      atualizadoEm: FieldValue.serverTimestamp(),
    });

    // 8. Recibo idempotente do comando em commands
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      uid: contexto.uid,
      action: ACAO_ACEITE,
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      aceiteId,
      termoId: entrada.termoId,
      versaoId: versaoVigenteId,
      numeroVersao,
      hashSha256: entrada.hashSha256,
      titulo,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // 9. Evento de auditoria append-only em auditOutbox
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      actorUid: contexto.uid,
      action: 'ACEITE_TERMO_REGISTRADO',
      fichaId: contexto.uid,
      termoId: entrada.termoId,
      versaoId: versaoVigenteId,
      numeroVersao,
      hashSha256: entrada.hashSha256,
      origem: ORIGEM_ACEITE,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      id: aceiteId,
      uid: contexto.uid,
      fichaId: contexto.uid,
      termoId: entrada.termoId,
      versaoId: versaoVigenteId,
      numeroVersao,
      hashSha256: entrada.hashSha256,
      titulo,
      declaracaoLidoEConcordo: true,
      aceitoEm: new Date().toISOString(),
      commandId: contexto.commandId,
      repetido: false,
    };
  });
}

/**
 * Consulta o histórico completo de aceites registrados para a ficha do voluntário.
 */
export async function obterHistoricoAceitesRepo(
  db: Firestore,
  uid: string,
): Promise<ComprovanteAceiteTermo[]> {
  const snapshot = await db
    .collection('fichas')
    .doc(uid)
    .collection('aceites')
    .orderBy('aceitoEm', 'desc')
    .get();

  return snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      uid: String(d.uid ?? uid),
      fichaId: String(d.fichaId ?? uid),
      termoId: String(d.termoId ?? ''),
      versaoId: String(d.versaoId ?? ''),
      numeroVersao: Number(d.numeroVersao ?? 0),
      hashSha256: String(d.hashSha256 ?? ''),
      titulo: String(d.titulo ?? ''),
      declaracaoLidoEConcordo: Boolean(d.declaracaoLidoEConcordo ?? true),
      aceitoEm: iso(d.aceitoEm),
      commandId: String(d.commandId ?? ''),
    };
  });
}


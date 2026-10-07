import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  IgrejaInvalidaError,
  calcularDiffFicha,
  type EntradaSalvarMinhaFicha,
  type FichaPermanente,
} from '../domain/ficha.js';
import { MENSAGEM_CANONICA_DECISAO_NEGATIVA } from '../domain/mensagens.js';

export interface ContextoFicha {
  commandId: string;
  uid: string;
}

export interface ResultadoSalvarFicha {
  repetido: boolean;
  ficha: FichaPermanente;
}

function serializarTimestamp(valor: unknown): string | null {
  if (!valor) return null;
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof valor === 'string') return valor;
  return null;
}

function montarFicha(id: string, dados: Record<string, unknown>): FichaPermanente {
  const termoAceitoRaw =
    dados.termoAceito && typeof dados.termoAceito === 'object'
      ? (dados.termoAceito as Record<string, unknown>)
      : null;

  const termoAceito = termoAceitoRaw
    ? {
        termoId: String(termoAceitoRaw.termoId ?? ''),
        versaoId: String(termoAceitoRaw.versaoId ?? ''),
        numeroVersao: Number(termoAceitoRaw.numeroVersao ?? 0),
        hashSha256: String(termoAceitoRaw.hashSha256 ?? ''),
        titulo: termoAceitoRaw.titulo ? String(termoAceitoRaw.titulo) : undefined,
        aceitoEm: serializarTimestamp(termoAceitoRaw.aceitoEm) ?? new Date().toISOString(),
        commandId: String(termoAceitoRaw.commandId ?? ''),
      }
    : null;

  return {
    id,
    ownerUid: String(dados.ownerUid ?? id),
    nomeCompleto: String(dados.nomeCompleto ?? ''),
    profissao: String(dados.profissao ?? ''),
    cpf: String(dados.cpf ?? ''),
    igrejaId: String(dados.igrejaId ?? ''),
    estado: String(dados.estado ?? 'RASCUNHO'),
    versao: Number(dados.versao ?? 1),
    termoAceito,
    proximaAcao:
      String(dados.estado ?? '') === 'REJEITADA'
        ? MENSAGEM_CANONICA_DECISAO_NEGATIVA
        : (dados.proximaAcao ? String(dados.proximaAcao) : null),
    mensagemVoluntario:
      String(dados.estado ?? '') === 'REJEITADA'
        ? MENSAGEM_CANONICA_DECISAO_NEGATIVA
        : (dados.mensagemVoluntario ? String(dados.mensagemVoluntario) : null),
    criadoEm: serializarTimestamp(dados.criadoEm),
    atualizadoEm: serializarTimestamp(dados.atualizadoEm),
  };
}

/**
 * Consulta a ficha de um voluntário pelo seu UID.
 * Retorna null se não houver ficha criada.
 */
export async function obterMinhaFichaRepo(
  db: Firestore,
  uid: string,
): Promise<FichaPermanente | null> {
  const docSnap = await db.collection('fichas').doc(uid).get();
  if (!docSnap.exists) {
    return null;
  }
  return montarFicha(docSnap.id, docSnap.data() ?? {});
}

/**
 * Persiste transacionalmente a criação ou atualização da ficha permanente.
 * Garante idempotência por commandId, checa se a igreja está ativa,
 * executa controle otimista de versão e gera recibo em `commands`
 * e evento em `auditOutbox`.
 */
export async function salvarMinhaFichaRepo(
  db: Firestore,
  contexto: ContextoFicha,
  entrada: EntradaSalvarMinhaFicha,
): Promise<ResultadoSalvarFicha> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(contexto.uid);
  const igrejaRef = db.collection('igrejas').doc(entrada.igrejaId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em `commands`
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid !== contexto.uid) {
        throw new Error('Operação indisponível para o usuário informado.');
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const fichaSnap = await tx.get(fichaRef);
      if (fichaSnap.exists) {
        return {
          repetido: true,
          ficha: montarFicha(fichaSnap.id, fichaSnap.data() ?? {}),
        };
      }
    }

    // 2. Validação da Igreja: deve existir e estar com ativo == true
    const igrejaSnap = await tx.get(igrejaRef);
    if (!igrejaSnap.exists || igrejaSnap.data()?.ativo !== true) {
      throw new IgrejaInvalidaError('Igreja inválida ou inativa');
    }

    // 3. Verificação de versão e estado da ficha
    const fichaSnap = await tx.get(fichaRef);
    const dadosAtuais = fichaSnap.exists ? (fichaSnap.data() ?? {}) : null;

    if (dadosAtuais) {
      const versaoAtual = Number(dadosAtuais.versao ?? 1);
      if (
        entrada.expectedVersion !== undefined &&
        entrada.expectedVersion !== null &&
        entrada.expectedVersion !== versaoAtual
      ) {
        throw new ConflitoVersaoError();
      }
    } else {
      if (
        entrada.expectedVersion !== undefined &&
        entrada.expectedVersion !== null &&
        entrada.expectedVersion !== 0
      ) {
        throw new ConflitoVersaoError();
      }
    }

    const versaoAnterior = dadosAtuais ? Number(dadosAtuais.versao ?? 1) : 0;
    const novaVersao = versaoAnterior + 1;
    const estadoFicha = dadosAtuais ? String(dadosAtuais.estado ?? 'RASCUNHO') : 'RASCUNHO';

    const diff = calcularDiffFicha(dadosAtuais, entrada);
    const acaoAuditoria = dadosAtuais ? 'FICHA_ATUALIZADA' : 'FICHA_CRIADA';

    const novosDadosFicha: Record<string, unknown> = {
      id: contexto.uid,
      ownerUid: contexto.uid,
      nomeCompleto: entrada.nomeCompleto,
      profissao: entrada.profissao,
      cpf: entrada.cpf,
      igrejaId: entrada.igrejaId,
      estado: estadoFicha,
      versao: novaVersao,
      atualizadoEm: FieldValue.serverTimestamp(),
    };

    if (!dadosAtuais) {
      novosDadosFicha.criadoEm = FieldValue.serverTimestamp();
      tx.set(fichaRef, novosDadosFicha);
    } else {
      tx.set(fichaRef, novosDadosFicha, { merge: true });
    }

    // Grava recibo do comando
    tx.set(reciboRef, {
      uid: contexto.uid,
      action: 'SALVAR_MINHA_FICHA',
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      correlationId: contexto.commandId,
      versao: novaVersao,
      criadoEm: FieldValue.serverTimestamp(),
    });

    // Grava evento de auditoria no auditOutbox
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.commandId,
      actorUid: contexto.uid,
      action: acaoAuditoria,
      fichaId: contexto.uid,
      diff,
      estadoFicha,
      versao: novaVersao,
      criadoEm: FieldValue.serverTimestamp(),
    });

    return {
      repetido: false,
      ficha: {
        id: contexto.uid,
        ownerUid: contexto.uid,
        nomeCompleto: entrada.nomeCompleto,
        profissao: entrada.profissao,
        cpf: entrada.cpf,
        igrejaId: entrada.igrejaId,
        estado: estadoFicha,
        versao: novaVersao,
        termoAceito: dadosAtuais?.termoAceito ?? null,
        criadoEm: serializarTimestamp(dadosAtuais?.criadoEm) ?? new Date().toISOString(),
        atualizadoEm: new Date().toISOString(),
      },
    };
  });
}

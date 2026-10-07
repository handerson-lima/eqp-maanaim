import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  construirNotificacaoVoluntario,
  validarAusenciaPIIEJustificativas,
  type NotificacaoSegura,
  type TipoNotificacao,
} from '../domain/notificacao.js';

function serializarTimestamp(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return String(valor);
}

/**
 * Cria e persiste uma notificação segura no Firestore a partir de um evento de auditoria.
 * Valida rigorosamente a ausência de PII e termos restritos antes da escrita.
 */
export async function emitirNotificacaoSeguraRepo(
  db: Firestore,
  parametros: {
    commandId: string;
    destinatarioUid: string;
    tipo: TipoNotificacao;
    estado: string;
    deepLink?: string;
  },
): Promise<NotificacaoSegura> {
  const agora = new Date().toISOString();
  const id = `notif_${parametros.commandId}_${parametros.destinatarioUid}`;

  const notificacao = construirNotificacaoVoluntario(
    id,
    parametros.destinatarioUid,
    parametros.tipo,
    parametros.estado,
    parametros.deepLink ?? '/minha-ficha',
    agora,
  );

  const checagem = validarAusenciaPIIEJustificativas(notificacao as unknown as Record<string, unknown>);
  if (!checagem.seguro) {
    throw new Error(`Tentativa de emitir notificação inválida: ${checagem.motivoViolacao}`);
  }

  const docRef = db.collection('notificacoes').doc(id);
  await docRef.set({
    ...notificacao,
    commandId: parametros.commandId,
    criadoEm: FieldValue.serverTimestamp(),
    atualizadoEm: FieldValue.serverTimestamp(),
  });

  return notificacao;
}

/**
 * Consulta as notificações do voluntário autenticado.
 * Apenas o próprio voluntário pode consultar suas notificações.
 */
export async function obterMinhasNotificacoesRepo(
  db: Firestore,
  uid: string,
): Promise<NotificacaoSegura[]> {
  const snapshot = await db
    .collection('notificacoes')
    .where('destinatarioUid', '==', uid)
    .get();

  return snapshot.docs
    .map((doc) => {
      const data = doc.data() ?? {};
      return {
        id: doc.id,
        destinatarioUid: String(data.destinatarioUid ?? ''),
        tipo: data.tipo as TipoNotificacao,
        estado: String(data.estado ?? ''),
        proximaAcao: String(data.proximaAcao ?? ''),
        deepLink: String(data.deepLink ?? '/minha-ficha'),
        criadoEm: serializarTimestamp(data.criadoEm),
      };
    })
    .sort((a, b) => b.criadoEm.localeCompare(a.criadoEm));
}

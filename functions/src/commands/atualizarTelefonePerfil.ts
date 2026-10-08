import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { normalizarTelefone, TelefoneInvalidoError } from '../domain/telefone.js';
import { atualizarTelefoneRepo } from '../repositories/ficha.js';

/**
 * Atualiza o telefone (WhatsApp) da ficha cadastral do voluntário autenticado.
 * Valida o formato brasileiro e persiste de forma segura e transacional,
 * emitindo evento de auditoria sem PII em auditOutbox (AD-12).
 */
export const atualizarTelefonePerfil = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const telefoneRaw = request.data?.telefone;
    let telefoneFormatado: string;

    try {
      telefoneFormatado = normalizarTelefone(telefoneRaw);
    } catch (erro) {
      if (erro instanceof TelefoneInvalidoError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Telefone inválido.');
    }

    const db = getFirestore();

    try {
      const resultado = await atualizarTelefoneRepo(
        db,
        request.auth.uid,
        telefoneFormatado,
      );

      return {
        sucesso: true,
        telefone: resultado.telefone,
      };
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível atualizar o telefone. Tente novamente mais tarde.',
      );
    }
  },
);

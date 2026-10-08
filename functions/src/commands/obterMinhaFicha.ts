import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { obterMinhaFichaRepo } from '../repositories/ficha.js';

/**
 * Consulta a ficha cadastral permanente do voluntário autenticado.
 * Apenas o próprio voluntário pode ler sua ficha.
 */
export const obterMinhaFicha = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    // Se o cliente tentar especificar um UID diferente, rejeita imediatamente
    if (
      request.data?.uid &&
      typeof request.data.uid === 'string' &&
      request.data.uid.trim() !== request.auth.uid
    ) {
      throw new HttpsError(
        'permission-denied',
        'Não é permitido consultar a ficha de outro voluntário.',
      );
    }

    const db = getFirestore();
    const ficha = await obterMinhaFichaRepo(db, request.auth.uid);

    if (!ficha) {
      return { existe: false };
    }

    return {
      existe: true,
      ficha: {
        id: ficha.id,
        nomeCompleto: ficha.nomeCompleto,
        profissao: ficha.profissao,
        cpf: ficha.cpf,
        igrejaId: ficha.igrejaId,
        telefone: ficha.telefone ?? null,
        estado: ficha.estado,
        versao: ficha.versao,
        termoAceito: ficha.termoAceito ?? null,
        proximaAcao: ficha.proximaAcao ?? null,
        mensagemVoluntario: ficha.mensagemVoluntario ?? null,
        atualizadoEm: ficha.atualizadoEm,
      },
    };
  },
);

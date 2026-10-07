import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  SolicitacaoInvalidaError,
  validarExpirarCiclos,
} from '../domain/expirarCiclo.js';
import { executarExpirarCiclosRepo } from '../repositories/expirarCiclo.js';
import { validarAutoridadeCoordenador } from '../repositories/decisaoCoordenador.js';

/**
 * Callable autenticada para acionamento administrativo/reconciliação do job de expiração.
 * Restrita a Coordenador Geral ou Administrador do sistema.
 */
export const expirarCiclosVencidos = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'É necessário entrar na conta.');
    }

    const db = getFirestore();

    // Apenas Coordenador Geral ou Administrador pode disparar manualmente
    const autoridade = await validarAutoridadeCoordenador(db, request.auth.uid);
    if (!autoridade.autorizado) {
      throw new HttpsError(
        'permission-denied',
        'Apenas a coordenação geral pode disparar a rotina de expiração de ciclos.',
      );
    }

    let entrada;
    try {
      entrada = validarExpirarCiclos(request.data);
    } catch (erro) {
      if (erro instanceof SolicitacaoInvalidaError) {
        throw new HttpsError('invalid-argument', erro.message);
      }
      throw new HttpsError('invalid-argument', 'Dados de solicitação inválidos.');
    }

    // O relógio é sempre do servidor: o chamador não pode antecipar nem atrasar
    // a expiração de ciclos (política de tempo do servidor / AD-10).
    entrada = { ...entrada, agoraIso: new Date().toISOString() };

    try {
      const resultado = await executarExpirarCiclosRepo(db, entrada);
      return resultado;
    } catch (erro) {
      if (erro instanceof HttpsError) {
        throw erro;
      }
      throw new HttpsError(
        'internal',
        'Não foi possível processar a expiração dos ciclos. Tente novamente mais tarde.',
      );
    }
  },
);

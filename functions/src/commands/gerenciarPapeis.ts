import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  OperacaoInvalidaError,
  SemAutoridadeError,
  UltimoAdminError,
  validarPapeis,
} from '../domain/pessoas.js';
import { reconciliarClaimAdministrativa } from '../repositories/autoridadeAdministrativa.js';
import { ORIGEM_ADMINISTRATIVA, alterarPapeis } from '../repositories/pessoas.js';

const erro = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument' | 'aborted',
) => new HttpsError(code, 'Operação administrativa indisponível.');

/**
 * Única fronteira de concessão/revogação de papéis de sistema. Exige App Check,
 * Auth e autoridade administrativa vigente, bloqueia autoatribuição/auto-revogação
 * e a remoção do último ADMIN; a claim é reconciliada após o commit.
 */
export const gerenciarPapeis = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw erro('permission-denied');
    let entrada;
    try {
      entrada = validarPapeis(request.data);
    } catch {
      throw erro('invalid-argument');
    }
    if (entrada.alvoUid === request.auth.uid) throw erro('failed-precondition');
    const db = getFirestore();
    // Valida a autoridade do ator antes de qualquer consulta ao alvo: um chamador
    // sem papel não pode distinguir UID existente de inexistente.
    const atorPrevio = await db
      .collection('autoridadesAdministrativas')
      .doc(request.auth.uid)
      .get();
    if (!podeAdministrar(atorPrevio.data())) throw erro('permission-denied');
    try {
      await getAuth().getUser(entrada.alvoUid);
    } catch {
      throw erro('invalid-argument');
    }
    const contexto = {
      commandId: entrada.commandId,
      correlacaoId: entrada.correlationId ?? entrada.commandId,
      atorUid: request.auth.uid,
      origem: ORIGEM_ADMINISTRATIVA,
    };
    try {
      const resultado = await alterarPapeis(db, contexto, entrada);
      // Conclui a projeção também em replay: se a reconciliação anterior falhou,
      // o recibo ficou PENDENTE_CLAIM e o retry precisa terminá-la.
      const reciboRef = db.collection('commands').doc(entrada.commandId);
      const reciboAtual = await reciboRef.get();
      if (reciboAtual.data()?.estado !== 'COMPLETO') {
        if (!(await reconciliarClaimAdministrativa(db, resultado.alvoUid))) {
          throw erro('aborted');
        }
        await reciboRef.update({
          estado: 'COMPLETO',
          concluidoEm: FieldValue.serverTimestamp(),
        });
      }
      return {
        concluido: true,
        repetido: resultado.repetido,
        papeis: resultado.papeis,
      };
    } catch (falha) {
      if (falha instanceof HttpsError) throw falha;
      if (falha instanceof SemAutoridadeError) throw erro('permission-denied');
      if (falha instanceof ComandoDivergenteError || falha instanceof ConflitoVersaoError) {
        throw erro('aborted');
      }
      if (falha instanceof OperacaoInvalidaError || falha instanceof UltimoAdminError) {
        throw erro('failed-precondition');
      }
      throw falha;
    }
  },
);

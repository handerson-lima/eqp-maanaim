import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import {
  aplicarClaimsSistema,
  papeisEfetivos,
} from '../domain/autoridadeAdministrativa.js';

const MAX_TENTATIVAS = 5;

/**
 * Reconciliador por revisão: nunca escreve uma decisão antiga depois de reler.
 * A projeção é refeita a partir da revisão canônica atual, derivando uma claim
 * por papel de sistema e preservando domínios alheios, com tentativas limitadas
 * para não recorrer indefinidamente sob concorrência sustentada.
 */
export async function reconciliarClaimAdministrativa(db: Firestore, uid: string): Promise<boolean> {
  const ref = db.collection('autoridadesAdministrativas').doc(uid);
  const auth = getAuth();
  for (let tentativa = 0; tentativa < MAX_TENTATIVAS; tentativa++) {
    const antes = await ref.get();
    if (!antes.exists) return false;
    const dados = antes.data()!;
    const revisao = dados.revisao as number;
    const user = await auth.getUser(uid);
    // Não substitui claims de outros domínios; a releitura posterior detecta
    // corrida e reexecuta a projeção atual, compensando esta escrita externa.
    await auth.setCustomUserClaims(uid, aplicarClaimsSistema(user.customClaims, papeisEfetivos(dados)));
    const depois = await ref.get();
    if (depois.exists && depois.data()!.revisao === revisao) {
      await ref.update({ claimStatus: 'CONCLUIDA', claimRevisao: revisao, claimAtualizadaEm: FieldValue.serverTimestamp() });
      return true;
    }
  }
  // Concorrência sustentada impediu estabilizar a revisão: a claim pode estar
  // obsoleta, então a operação é reportada como pendente em vez de concluída.
  return false;
}

import { type Firestore } from 'firebase-admin/firestore';
import {
  DIAS_AVISO_PREVIO_PADRAO,
  DIAS_RENOVACAO_IMINENTE_PADRAO,
  type ConfiguracaoJanelaVigencia,
} from '../domain/vigencia.js';

/** Coleção/documento canônico da configuração operacional de janelas de renovação. */
export const COLECAO_CONFIGURACOES = 'configuracoes';
export const DOC_CONFIG_VIGENCIA = 'vigenciaRenovacao';

/**
 * Lê a configuração operacional das janelas de alerta de renovação (AD-7).
 * Quando o documento não existe ou é inválido, retorna os padrões do domínio.
 */
export async function obterConfiguracaoJanelaVigencia(
  db: Firestore,
): Promise<ConfiguracaoJanelaVigencia> {
  try {
    const snap = await db.collection(COLECAO_CONFIGURACOES).doc(DOC_CONFIG_VIGENCIA).get();
    if (!snap.exists) return {};
    const dados = snap.data() ?? {};
    const aviso = Number(dados.diasAvisoPrevio);
    const iminente = Number(dados.diasRenovacaoIminente);
    return {
      diasAvisoPrevio:
        Number.isFinite(aviso) && aviso > 0 ? aviso : DIAS_AVISO_PREVIO_PADRAO,
      diasRenovacaoIminente:
        Number.isFinite(iminente) && iminente > 0
          ? iminente
          : DIAS_RENOVACAO_IMINENTE_PADRAO,
    };
  } catch {
    return {};
  }
}

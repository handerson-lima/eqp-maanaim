import { createHash } from 'node:crypto';

export const PAPEL_ADMINISTRADOR = 'ADMINISTRADOR';
/** Nome da Custom Claim de administração. Único ponto de verdade no backend. */
export const NOME_CLAIM_ADMINISTRATIVA = 'maanaimAdmin';

export type AutoridadeAdministrativa = {
  ativa: boolean;
  revisao: number;
  papel: typeof PAPEL_ADMINISTRADOR;
  claimStatus: 'PENDENTE' | 'CONCLUIDA';
};

export type EntradaAlteracao = {
  alvoUid: string;
  conceder: boolean;
};

/** A claim é apenas projeção. A decisão sempre lê este documento canônico. */
export function podeAdministrar(valor: unknown): boolean {
  const a = valor as Partial<AutoridadeAdministrativa> | undefined;
  return a?.ativa === true && a.papel === PAPEL_ADMINISTRADOR;
}

/**
 * Deriva a próxima projeção de claims preservando domínios alheios: apenas a
 * claim de administração é escrita ou removida.
 */
export function aplicarClaimAdministrativa(
  claimsExistentes: unknown,
  ativa: boolean
): Record<string, unknown> {
  const claims = { ...((claimsExistentes as Record<string, unknown> | null | undefined) ?? {}) };
  if (ativa) claims[NOME_CLAIM_ADMINISTRATIVA] = true;
  else delete claims[NOME_CLAIM_ADMINISTRATIVA];
  return claims;
}

/**
 * Vincula o recibo ao conteúdo do comando sem persistir o UID do alvo: o mesmo
 * `commandId` reutilizado com alvo ou sentido divergente é recusado.
 */
export function hashAlteracao(entrada: EntradaAlteracao): string {
  return createHash('sha256')
    .update(`${entrada.alvoUid}:${entrada.conceder ? 'CONCEDER' : 'REVOGAR'}`)
    .digest('hex');
}

import { createHash } from 'node:crypto';

export const PAPEL_ADMINISTRADOR = 'ADMINISTRADOR';
export const PAPEL_COORDENADOR = 'COORDENADOR';

/** Catálogo de papéis de sistema geridos na Story 1.3 (Q2). */
export const PAPEIS_SISTEMA = [PAPEL_ADMINISTRADOR, PAPEL_COORDENADOR] as const;
export type PapelSistema = (typeof PAPEIS_SISTEMA)[number];

/** Nome das Custom Claims; único ponto de verdade no backend. */
export const NOME_CLAIM_ADMINISTRATIVA = 'maanaimAdmin';
export const NOME_CLAIM_COORDENADOR = 'maanaimCoordenador';

/** Uma claim por papel de sistema, sem ampliar a autoridade de cada ação. */
export const CLAIM_POR_PAPEL: Record<PapelSistema, string> = {
  [PAPEL_ADMINISTRADOR]: NOME_CLAIM_ADMINISTRATIVA,
  [PAPEL_COORDENADOR]: NOME_CLAIM_COORDENADOR,
};

export type AutoridadeAdministrativa = {
  ativa: boolean;
  papeis: PapelSistema[];
  revisao: number;
  claimStatus: 'PENDENTE' | 'CONCLUIDA';
};

export type EntradaAlteracao = {
  alvoUid: string;
  conceder: boolean;
  expectedVersion: number;
};

export function ehPapelSistema(valor: unknown): valor is PapelSistema {
  return (
    typeof valor === 'string' &&
    (PAPEIS_SISTEMA as readonly string[]).includes(valor)
  );
}

/**
 * Lê o conjunto efetivo do agregado canônico. Documentos gravados antes de Q1
 * usam `papel` singular; ambos os formatos convergem para o mesmo conjunto.
 */
export function papeisEfetivos(valor: unknown): PapelSistema[] {
  const a = valor as
    | { ativa?: unknown; papeis?: unknown; papel?: unknown }
    | null
    | undefined;
  if (a?.ativa !== true) return [];
  const bruto = Array.isArray(a.papeis)
    ? a.papeis
    : typeof a.papel === 'string'
      ? [a.papel]
      : [];
  const conjunto = new Set<PapelSistema>();
  for (const item of bruto) {
    if (ehPapelSistema(item)) conjunto.add(item);
  }
  return [...conjunto];
}

export function possuiPapel(valor: unknown, papel: PapelSistema): boolean {
  return papeisEfetivos(valor).includes(papel);
}

/** A decisão sempre lê este documento canônico; a claim é apenas projeção. */
export function podeAdministrar(valor: unknown): boolean {
  return possuiPapel(valor, PAPEL_ADMINISTRADOR);
}

/**
 * Projeta o conjunto de claims de papéis de sistema preservando domínios
 * alheios: apenas `maanaimAdmin` e `maanaimCoordenador` são escritas/removidas.
 */
export function aplicarClaimsSistema(
  claimsExistentes: unknown,
  papeis: readonly string[],
): Record<string, unknown> {
  const claims = {
    ...((claimsExistentes as Record<string, unknown> | null | undefined) ?? {}),
  };
  const conjunto = new Set(papeis);
  for (const papel of PAPEIS_SISTEMA) {
    if (conjunto.has(papel)) claims[CLAIM_POR_PAPEL[papel]] = true;
    else delete claims[CLAIM_POR_PAPEL[papel]];
  }
  return claims;
}

/**
 * Vincula o recibo ao conteúdo do comando sem persistir o UID do alvo: o mesmo
 * `commandId` reutilizado com alvo ou sentido divergente é recusado.
 */
export function hashAlteracao(entrada: EntradaAlteracao): string {
  return createHash('sha256')
    .update(
      `${entrada.alvoUid}:${entrada.conceder ? 'CONCEDER' : 'REVOGAR'}:${entrada.expectedVersion}`,
    )
    .digest('hex');
}

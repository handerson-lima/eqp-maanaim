import { readFile } from 'node:fs/promises';
import { getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import {
  importarPastoresIniciais,
  ORIGEM_SEED_INICIAL,
  type EntradaBruta,
  type ResultadoImportacao,
} from '../domain/importacaoPastores.js';
import { parsearPlanilhaPastores } from '../domain/planilhaPastores.js';
import { aplicarVinculosAusentes } from '../domain/vinculosAusentes.js';
import { criarPortasFirestore } from '../repositories/firestoreImportacao.js';

export type OpcoesImportacaoArquivo = {
  caminho: string;
  modo: 'EXECUCAO' | 'SIMULACAO';
  commandId: string;
  correlacaoId?: string;
  origem?: string;
  agora?: Date;
  /** Injetável para exercitar o fluxo sem tocar no disco. */
  lerArquivo?: (caminho: string) => Promise<string>;
};

/** Lê a planilha, acrescenta os vínculos ausentes e valida tudo antes de gravar. */
export function prepararEntradas(conteudo: string): EntradaBruta[] {
  return aplicarVinculosAusentes(parsearPlanilhaPastores(conteudo));
}

/**
 * Execução administrativa local: usa credenciais privilegiadas (IAM ou
 * emulador) e mantém a fonte de PII no disco local. Não é um endpoint público.
 */
export async function importarDeArquivo(
  opcoes: OpcoesImportacaoArquivo,
): Promise<ResultadoImportacao> {
  const ler = opcoes.lerArquivo ?? ((caminho: string) => readFile(caminho, 'utf8'));
  const conteudo = await ler(opcoes.caminho);
  const entradas = prepararEntradas(conteudo);
  const projeto =
    process.env.GOOGLE_CLOUD_PROJECT ?? process.env.GCLOUD_PROJECT ?? undefined;
  const app =
    getApps().length > 0
      ? getApp()
      : initializeApp(projeto ? { projectId: projeto } : undefined);
  const portas = criarPortasFirestore(getFirestore(app), getAuth(app));
  return importarPastoresIniciais(
    {
      commandId: opcoes.commandId,
      correlacaoId: opcoes.correlacaoId ?? opcoes.commandId,
      origem: opcoes.origem ?? ORIGEM_SEED_INICIAL,
      modo: opcoes.modo,
      agora: opcoes.agora ?? new Date(),
      entradas,
    },
    portas,
  );
}

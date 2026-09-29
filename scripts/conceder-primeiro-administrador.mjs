#!/usr/bin/env node
// Processo local IAM/ADC. O UID nunca é exibido nem persistido fora da chave
// canônica autoridadesAdministrativas/{uid}.
import { env, stderr, stdout, exit } from 'node:process';
import { createRequire } from 'node:module';

const uid = env.UID_ADMINISTRADOR;
if (!uid) {
  stderr.write('Uso: UID_ADMINISTRADOR=<uid> node scripts/conceder-primeiro-administrador.mjs\n');
  exit(2);
}

async function principal() {
  // As dependências do runtime vivem em functions/node_modules; resolve-as a
  // partir de functions/ para não depender de node_modules na raiz do repositório.
  const requireFromFunctions = createRequire(new URL('../functions/package.json', import.meta.url));
  const { getApps, getApp, initializeApp } = requireFromFunctions('firebase-admin/app');
  const { getAuth } = requireFromFunctions('firebase-admin/auth');
  const { getFirestore, FieldValue } = requireFromFunctions('firebase-admin/firestore');
  const { reconciliarClaimAdministrativa } = await import('../functions/lib/repositories/autoridadeAdministrativa.js');
  // Com ADC de usuário o Auth não infere o projeto; use GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.
  const projeto = env.GOOGLE_CLOUD_PROJECT ?? env.GCLOUD_PROJECT ?? null;
  const app = getApps().length ? getApp() : initializeApp(projeto ? { projectId: projeto } : undefined);
  const db = getFirestore(app);
  await getAuth(app).getUser(uid); // antes da transação; falha sem parcial.
  await db.runTransaction(async tx => {
    const ativos = await tx.get(db.collection('autoridadesAdministrativas').where('ativa', '==', true));
    const ref = db.collection('autoridadesAdministrativas').doc(uid);
    const atual = await tx.get(ref);
    const souAtivo = atual.exists && atual.data()?.ativa === true;
    if (ativos.size && !souAtivo) throw new Error('JA_EXISTE_ADMINISTRADOR');
    if (!atual.exists) {
      tx.create(ref, { ativa: true, papel: 'ADMINISTRADOR', versao: 1, revisao: 1, claimStatus: 'PENDENTE', criadoEm: FieldValue.serverTimestamp() });
    } else if (!souAtivo) {
      // Retoma uma autoridade existente mas inativa, em vez de reportar sucesso
      // sem conceder a administração.
      tx.update(ref, { ativa: true, papel: 'ADMINISTRADOR', claimStatus: 'PENDENTE', versao: (atual.data()?.versao ?? 0) + 1, revisao: (atual.data()?.revisao ?? 0) + 1, atualizadoEm: FieldValue.serverTimestamp() });
    }
  });
  if (!await reconciliarClaimAdministrativa(db, uid)) throw new Error('RECONCILIACAO_PENDENTE');
  stdout.write('{"status":"CONCLUIDO"}\n');
}
principal().catch(() => { stderr.write('Falha controlada no provisionamento.\n'); exit(1); });

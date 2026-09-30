#!/usr/bin/env node
// Processo local IAM/ADC. O UID nunca é exibido nem persistido fora da chave
// canônica autoridadesAdministrativas/{uid}.
import { env, stderr, stdout, exit } from 'node:process';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';

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
  const { PAPEL_ADMINISTRADOR, podeAdministrar, papeisEfetivos } = await import('../functions/lib/domain/autoridadeAdministrativa.js');
  // Com ADC de usuário o Auth não infere o projeto; use GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.
  const projeto = env.GOOGLE_CLOUD_PROJECT ?? env.GCLOUD_PROJECT ?? null;
  const app = getApps().length ? getApp() : initializeApp(projeto ? { projectId: projeto } : {});
  const db = getFirestore(app);
  const identidade = await getAuth(app).getUser(uid); // antes da transação; falha sem parcial.
  if (identidade.disabled) throw new Error('IDENTIDADE_DESABILITADA');
  // O recibo/auditoria usam um commandId opaco aleatório: o UID nunca é
  // persistido fora da chave canônica autoridadesAdministrativas/{uid}.
  const commandId = randomUUID();
  const reciboRef = db.collection('commands').doc(commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(commandId);
  let antesAtiva = false;
  await db.runTransaction(async tx => {
    const ativos = await tx.get(db.collection('autoridadesAdministrativas').where('ativa', '==', true));
    const ref = db.collection('autoridadesAdministrativas').doc(uid);
    const atual = await tx.get(ref);
    const souAtivo = atual.exists && atual.data()?.ativa === true;
    antesAtiva = atual.exists && atual.data()?.ativa === true;
    // Conta apenas autoridades válidas (podeAdministrar), como a callable.
    const validos = ativos.docs.filter(d => podeAdministrar(d.data()));
    if (validos.length && !souAtivo) throw new Error('JA_EXISTE_ADMINISTRADOR');
    if (!atual.exists) {
      tx.create(ref, { ativa: true, papeis: [PAPEL_ADMINISTRADOR], versao: 1, revisao: 1, claimStatus: 'PENDENTE', criadoEm: FieldValue.serverTimestamp() });
    } else if (!souAtivo) {
      // Retoma uma autoridade existente mas inativa, mesclando o papel plural e
      // removendo o campo legado `papel`.
      const papeis = [...new Set([...papeisEfetivos(atual.data()), PAPEL_ADMINISTRADOR])];
      tx.update(ref, { ativa: true, papeis, papel: FieldValue.delete(), claimStatus: 'PENDENTE', versao: (atual.data()?.versao ?? 0) + 1, revisao: (atual.data()?.revisao ?? 0) + 1, atualizadoEm: FieldValue.serverTimestamp() });
    }
    tx.create(reciboRef, {
      commandId,
      action: 'PROVISIONAR_PRIMEIRO_ADMINISTRADOR',
      estado: 'PENDENTE_CLAIM',
      origem: 'processo-operacional-iam-adc',
      criadoEm: FieldValue.serverTimestamp(),
    });
    tx.create(auditoriaRef, {
      commandId,
      action: 'AUTORIDADE_INICIAL_PROVISIONADA',
      antes: { ativa: antesAtiva },
      depois: { ativa: true },
      origem: 'processo-operacional-iam-adc',
      criadoEm: FieldValue.serverTimestamp(),
    });
  });
  if (!await reconciliarClaimAdministrativa(db, uid)) throw new Error('RECONCILIACAO_PENDENTE');
  await reciboRef.update({ estado: 'COMPLETO', concluidoEm: FieldValue.serverTimestamp() });
  stdout.write('{"status":"CONCLUIDO"}\n');
}
principal().catch(() => { stderr.write('Falha controlada no provisionamento.\n'); exit(1); });

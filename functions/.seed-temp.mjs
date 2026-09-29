import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const igrejas = [
  ['240001', 'Igapó'],
  ['240002', 'Santarém'],
  ['240003', 'Mirassol'],
  ['240004', 'Pajuçara'],
  ['240005', 'Macau'],
  ['240006', 'Mossoró'],
  ['240008', 'Goianinha'],
  ['240012', 'Alecrim'],
  ['240013', 'Nova Parnamirim'],
  ['240015', 'Parnamirim'],
  ['240017', 'Planalto'],
  ['240018', 'Nova Cruz'],
  ['240019', 'Montanhas'],
  ['240022', 'Monte Alegre'],
  ['240023', 'Acari'],
  ['240025', 'São José de Mipibú'],
  ['240027', 'Santa Tereza'],
  ['240028', 'Ceará - Mirim'],
  ['240029', 'Ponta Negra'],
  ['240032', 'Alvorada - Jose Luiz da Silva'],
  ['240033', 'Lagoa D Anta'],
  ['240034', 'Uruaçu'],
  ['240038', 'Caico'],
  ['240041', 'Extremoz'],
  ['240042', 'Cidade das Rosas'],
];

const app = initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-maanaim' });
const db = getFirestore(app);
for (const [codigo, nome] of igrejas) {
  await db.collection('igrejas').doc(`ig-${codigo}`).set({ codigo, nome, ativo: true });
}
console.log(`SEED_OK ${igrejas.length}`);

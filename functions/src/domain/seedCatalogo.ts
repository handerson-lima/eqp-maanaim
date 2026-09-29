import {
  VERSAO_DATASET_CATALOGO,
  type DatasetCatalogo,
} from './catalogo.js';

/**
 * Dataset canônico do PRD §44/§46, versionado. É a fonte única do seed inicial.
 * Não contém PII: os responsáveis das equipes são geridos pela Story 1.4.
 */
export const DATASET_CATALOGO: DatasetCatalogo = {
  versao: VERSAO_DATASET_CATALOGO,
  igrejas: [
    { codigo: '240023', nome: 'Acari' },
    { codigo: '240012', nome: 'Alecrim' },
    { codigo: '240032', nome: 'Alvorada - Jose Luiz da Silva' },
    { codigo: '240038', nome: 'Caico' },
    { codigo: '240028', nome: 'Ceará - Mirim' },
    { codigo: '240042', nome: 'Cidade das Rosas' },
    { codigo: '240041', nome: 'Extremoz' },
    { codigo: '240008', nome: 'Goianinha' },
    { codigo: '240001', nome: 'Igapó' },
    { codigo: '240033', nome: 'Lagoa D Anta' },
    { codigo: '240005', nome: 'Macau' },
    { codigo: '240003', nome: 'Mirassol' },
    { codigo: '240022', nome: 'Monte Alegre' },
    { codigo: '240019', nome: 'Montanhas' },
    { codigo: '240006', nome: 'Mossoró' },
    { codigo: '240018', nome: 'Nova Cruz' },
    { codigo: '240013', nome: 'Nova Parnamirim' },
    { codigo: '240004', nome: 'Pajuçara' },
    { codigo: '240015', nome: 'Parnamirim' },
    { codigo: '240017', nome: 'Planalto' },
    { codigo: '240029', nome: 'Ponta Negra' },
    { codigo: '240027', nome: 'Santa Tereza' },
    { codigo: '240002', nome: 'Santarém' },
    { codigo: '240025', nome: 'São José de Mipibú' },
    { codigo: '240034', nome: 'Uruaçu' },
  ],
  equipes: [
    { nome: 'Apoio' },
    { nome: 'Cantina' },
    { nome: 'Comunicação' },
    { nome: 'Cozinha' },
    { nome: 'Grupo de Louvor' },
    { nome: 'Hospedagem' },
    { nome: 'Libras' },
    { nome: 'Limpeza' },
    { nome: 'Livraria' },
    { nome: 'Manutenção' },
    { nome: 'Professores UEF' },
    { nome: 'Saúde' },
    { nome: 'Secretaria' },
    { nome: 'Segurança' },
  ],
};

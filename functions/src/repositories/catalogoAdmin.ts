import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import {
  type EntradaSalvarEquipe,
  type EntradaSalvarIgreja,
  type EquipeAdmin,
  type IgrejaAdmin,
  type ResultadoSalvarCatalogo,
  type ResumoCatalogoAdmin,
  CodigoIgrejaDuplicadoError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  EntidadeInexistenteError,
  NomeEquipeDuplicadoError,
  SemAutoridadeError,
  chaveEquipe,
  hashSalvarEquipe,
  hashSalvarIgreja,
  idEquipeSeed,
  idIgrejaSeed,
  normalizarNome,
  rotuloIgreja,
} from '../domain/catalogo.js';
import { podeAdministrar } from '../domain/autoridadeAdministrativa.js';

export type ContextoSalvarCatalogo = {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
};

const ACAO_RECIBO_SALVAR_IGREJA = 'CATALOGO_IGREJA_SALVA';
const ACAO_RECIBO_SALVAR_EQUIPE = 'CATALOGO_EQUIPE_SALVA';
const ACAO_AUDITORIA_IGREJA_CRIADA = 'CATALOGO_IGREJA_CRIADA';
const ACAO_AUDITORIA_IGREJA_EDITADA = 'CATALOGO_IGREJA_EDITADA';
const ACAO_AUDITORIA_EQUIPE_CRIADA = 'CATALOGO_EQUIPE_CRIADA';
const ACAO_AUDITORIA_EQUIPE_EDITADA = 'CATALOGO_EQUIPE_EDITADA';

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor.trim() : '';
}

/**
 * Criação ou edição autenticada de igreja.
 * Valida unicidade de código String, versão esperada para controle de concorrência,
 * e gera recibo idempotente e auditoria outbox na mesma transação.
 */
export async function salvarIgrejaRepo(
  db: Firestore,
  contexto: ContextoSalvarCatalogo,
  entrada: EntradaSalvarIgreja,
): Promise<ResultadoSalvarCatalogo> {
  const payloadHash = hashSalvarIgreja(entrada);
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return db.runTransaction(async (tx) => {
    const atorRef = db.collection('autoridadesAdministrativas').doc(contexto.atorUid);
    const [atorSnap, reciboSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      if (
        recibo.action !== ACAO_RECIBO_SALVAR_IGREJA ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        id: String(recibo.entidadeId),
        repetido: true,
        versao: Number(recibo.versao ?? 1),
      };
    }

    const ehCriacao = !entrada.igrejaId || entrada.expectedVersion === 0;

    if (ehCriacao) {
      const id = entrada.igrejaId || idIgrejaSeed(entrada.codigo);
      const igrejaRef = db.collection('igrejas').doc(id);

      const [buscaCodigoSnap, igrejaExistenteSnap] = await Promise.all([
        tx.get(db.collection('igrejas').where('codigo', '==', entrada.codigo)),
        tx.get(igrejaRef),
      ]);

      if (!buscaCodigoSnap.empty || igrejaExistenteSnap.exists) {
        throw new CodigoIgrejaDuplicadoError(entrada.codigo);
      }

      tx.create(igrejaRef, {
        codigo: entrada.codigo,
        nome: entrada.nome,
        ativo: true,
        versao: 1,
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
        atualizadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(reciboRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_RECIBO_SALVAR_IGREJA,
        estado: 'COMPLETO',
        payloadHash,
        entidadeId: id,
        versao: 1,
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(auditoriaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_AUDITORIA_IGREJA_CRIADA,
        entidadeId: id,
        antes: null,
        depois: {
          codigo: entrada.codigo,
          nome: entrada.nome,
          ativo: true,
          versao: 1,
        },
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      return {
        id,
        repetido: false,
        versao: 1,
      };
    } else {
      const id = entrada.igrejaId!;
      const igrejaRef = db.collection('igrejas').doc(id);
      const [igrejaSnap, buscaCodigoSnap] = await Promise.all([
        tx.get(igrejaRef),
        tx.get(db.collection('igrejas').where('codigo', '==', entrada.codigo)),
      ]);

      if (!igrejaSnap.exists) {
        throw new EntidadeInexistenteError('IGREJA', id);
      }

      const dados = igrejaSnap.data() ?? {};
      const versaoAtual = Number(dados.versao ?? 1);
      if (versaoAtual !== entrada.expectedVersion) {
        throw new ConflitoVersaoError();
      }

      for (const doc of buscaCodigoSnap.docs) {
        if (doc.id !== id) {
          throw new CodigoIgrejaDuplicadoError(entrada.codigo);
        }
      }

      const novaVersao = versaoAtual + 1;
      tx.update(igrejaRef, {
        codigo: entrada.codigo,
        nome: entrada.nome,
        versao: novaVersao,
        atualizadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(reciboRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_RECIBO_SALVAR_IGREJA,
        estado: 'COMPLETO',
        payloadHash,
        entidadeId: id,
        versao: novaVersao,
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(auditoriaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_AUDITORIA_IGREJA_EDITADA,
        entidadeId: id,
        antes: {
          codigo: dados.codigo,
          nome: dados.nome,
          versao: versaoAtual,
        },
        depois: {
          codigo: entrada.codigo,
          nome: entrada.nome,
          versao: novaVersao,
        },
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      return {
        id,
        repetido: false,
        versao: novaVersao,
      };
    }
  });
}

/**
 * Criação ou edição autenticada de equipe.
 * Valida unicidade de nome normalizado, versão esperada e auditoria.
 */
export async function salvarEquipeRepo(
  db: Firestore,
  contexto: ContextoSalvarCatalogo,
  entrada: EntradaSalvarEquipe,
): Promise<ResultadoSalvarCatalogo> {
  const payloadHash = hashSalvarEquipe(entrada);
  const chave = chaveEquipe(entrada.nome);
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return db.runTransaction(async (tx) => {
    const atorRef = db.collection('autoridadesAdministrativas').doc(contexto.atorUid);
    const [atorSnap, reciboSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      if (
        recibo.action !== ACAO_RECIBO_SALVAR_EQUIPE ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        id: String(recibo.entidadeId),
        repetido: true,
        versao: Number(recibo.versao ?? 1),
      };
    }

    const ehCriacao = !entrada.equipeId || entrada.expectedVersion === 0;

    if (ehCriacao) {
      const id = entrada.equipeId || idEquipeSeed(entrada.nome);
      const equipeRef = db.collection('equipes').doc(id);

      const [buscaNomeSnap, equipeExistenteSnap] = await Promise.all([
        tx.get(db.collection('equipes').where('nomeNormalizado', '==', chave)),
        tx.get(equipeRef),
      ]);

      if (!buscaNomeSnap.empty || equipeExistenteSnap.exists) {
        throw new NomeEquipeDuplicadoError(entrada.nome);
      }

      tx.create(equipeRef, {
        nome: entrada.nome,
        nomeNormalizado: chave,
        ativo: true,
        versao: 1,
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
        atualizadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(reciboRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_RECIBO_SALVAR_EQUIPE,
        estado: 'COMPLETO',
        payloadHash,
        entidadeId: id,
        versao: 1,
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(auditoriaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_AUDITORIA_EQUIPE_CRIADA,
        entidadeId: id,
        antes: null,
        depois: {
          nome: entrada.nome,
          nomeNormalizado: chave,
          ativo: true,
          versao: 1,
        },
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      return {
        id,
        repetido: false,
        versao: 1,
      };
    } else {
      const id = entrada.equipeId!;
      const equipeRef = db.collection('equipes').doc(id);
      const [equipeSnap, buscaNomeSnap] = await Promise.all([
        tx.get(equipeRef),
        tx.get(db.collection('equipes').where('nomeNormalizado', '==', chave)),
      ]);

      if (!equipeSnap.exists) {
        throw new EntidadeInexistenteError('EQUIPE', id);
      }

      const dados = equipeSnap.data() ?? {};
      const versaoAtual = Number(dados.versao ?? 1);
      if (versaoAtual !== entrada.expectedVersion) {
        throw new ConflitoVersaoError();
      }

      for (const doc of buscaNomeSnap.docs) {
        if (doc.id !== id) {
          throw new NomeEquipeDuplicadoError(entrada.nome);
        }
      }

      const novaVersao = versaoAtual + 1;
      tx.update(equipeRef, {
        nome: entrada.nome,
        nomeNormalizado: chave,
        versao: novaVersao,
        atualizadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(reciboRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_RECIBO_SALVAR_EQUIPE,
        estado: 'COMPLETO',
        payloadHash,
        entidadeId: id,
        versao: novaVersao,
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      tx.create(auditoriaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlacaoId,
        actorUid: contexto.atorUid,
        action: ACAO_AUDITORIA_EQUIPE_EDITADA,
        entidadeId: id,
        antes: {
          nome: dados.nome,
          versao: versaoAtual,
        },
        depois: {
          nome: entrada.nome,
          versao: novaVersao,
        },
        origem: contexto.origem,
        criadoEm: FieldValue.serverTimestamp(),
      });

      return {
        id,
        repetido: false,
        versao: novaVersao,
      };
    }
  });
}

/**
 * Consulta administrativa do catálogo que reúne igrejas e equipes com
 * identificação dos responsáveis vigentes mínimos e versões para concorrência.
 * Sem expor CPF, e-mail ou dados fora do escopo.
 */
export async function lerCatalogoAdmin(
  db: Firestore,
  termo = '',
): Promise<ResumoCatalogoAdmin> {
  const [
    igrejasSnap,
    equipesSnap,
    pessoasSnap,
    vinculosIgrejaSnap,
    vinculosEquipeSnap,
  ] = await Promise.all([
    db.collection('igrejas').get(),
    db.collection('equipes').get(),
    db.collection('pessoas').select('nomeCompleto').get(),
    db.collection('vinculosPastorIgreja').where('estado', '==', 'VIGENTE').get(),
    db.collection('vinculosPastorEquipe').where('estado', '==', 'VIGENTE').get(),
  ]);

  const mapaNomes = new Map<string, string>();
  for (const doc of pessoasSnap.docs) {
    const nome = texto(doc.data().nomeCompleto);
    if (nome) mapaNomes.set(doc.id, nome);
  }

  const mapaPastorIgreja = new Map<string, { pessoaId: string; nome: string }>();
  for (const doc of vinculosIgrejaSnap.docs) {
    const d = doc.data();
    const igrejaId = texto(d.entidadeId) || texto(d.igrejaId);
    const pessoaId = texto(d.pessoaId);
    if (igrejaId && pessoaId && mapaNomes.has(pessoaId)) {
      mapaPastorIgreja.set(igrejaId, { pessoaId, nome: mapaNomes.get(pessoaId)! });
    }
  }

  const mapaResponsavelEquipe = new Map<string, { pessoaId: string; nome: string }>();
  for (const doc of vinculosEquipeSnap.docs) {
    const d = doc.data();
    const equipeId = texto(d.entidadeId) || texto(d.equipeId);
    const pessoaId = texto(d.pessoaId);
    if (equipeId && pessoaId && mapaNomes.has(pessoaId)) {
      mapaResponsavelEquipe.set(equipeId, { pessoaId, nome: mapaNomes.get(pessoaId)! });
    }
  }

  const igrejas: IgrejaAdmin[] = igrejasSnap.docs.map((doc) => {
    const d = doc.data();
    const codigo = String(d.codigo ?? '');
    const nome = texto(d.nome);
    const pastorVigente = mapaPastorIgreja.get(doc.id) ?? (
      d.pastorLocalVigentePessoaId && mapaNomes.has(d.pastorLocalVigentePessoaId)
        ? { pessoaId: d.pastorLocalVigentePessoaId, nome: mapaNomes.get(d.pastorLocalVigentePessoaId)! }
        : null
    );
    return {
      id: doc.id,
      codigo,
      nome,
      ativo: d.ativo === true,
      versao: Number(d.versao ?? 1),
      rotulo: rotuloIgreja({ nome, codigo }),
      pastorLocal: pastorVigente,
    };
  });

  const equipes: EquipeAdmin[] = equipesSnap.docs.map((doc) => {
    const d = doc.data();
    const nome = texto(d.nome);
    const respVigente = mapaResponsavelEquipe.get(doc.id) ?? (
      d.responsavelVigentePessoaId && mapaNomes.has(d.responsavelVigentePessoaId)
        ? { pessoaId: d.responsavelVigentePessoaId, nome: mapaNomes.get(d.responsavelVigentePessoaId)! }
        : null
    );
    return {
      id: doc.id,
      nome,
      nomeNormalizado: chaveEquipe(nome),
      ativo: d.ativo === true,
      versao: Number(d.versao ?? 1),
      responsavel: respVigente,
    };
  });

  const filtrarIgrejasAdmin = (itens: IgrejaAdmin[], busca: string) => {
    const alvo = normalizarNome(busca);
    return itens
      .filter((i) => {
        if (!alvo) return true;
        if (normalizarNome(i.nome).includes(alvo)) return true;
        return i.codigo.includes(busca.trim());
      })
      .sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR', { sensitivity: 'base' }));
  };

  const filtrarEquipesAdmin = (itens: EquipeAdmin[], busca: string) => {
    const alvo = normalizarNome(busca);
    return itens
      .filter((e) => {
        if (!alvo) return true;
        return normalizarNome(e.nome).includes(alvo);
      })
      .sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR', { sensitivity: 'base' }));
  };

  return {
    igrejas: filtrarIgrejasAdmin(igrejas, termo),
    equipes: filtrarEquipesAdmin(equipes, termo),
  };
}

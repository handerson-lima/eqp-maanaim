import type { Auth, UserRecord } from 'firebase-admin/auth';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import {
  PAPEL_ADMINISTRADOR,
  podeAdministrar,
  papeisEfetivos,
} from '../domain/autoridadeAdministrativa.js';
import {
  AlvoInexistenteError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  OperacaoInvalidaError,
  SemAutoridadeError,
  UltimoAdminError,
  pesquisarPessoas,
  type EntradaPapeis,
  type EntradaPessoa,
  type PessoaResumo,
  type ResumoPessoas,
} from '../domain/pessoas.js';

/** Origem auditável das mutações administrativas da Story 1.3. */
export const ORIGEM_ADMINISTRATIVA = 'administracao-pessoas-papeis';

const ACAO_RECIBO_PESSOA = 'SALVAR_PESSOA';
const ACAO_RECIBO_PAPEIS = 'GERENCIAR_PAPEIS';

export type ContextoPessoa = {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
};

export type ResultadoSalvarPessoa = {
  uid: string;
  repetido: boolean;
  coordenador: boolean;
  versao: number;
};

export type ResultadoGerenciarPapeis = {
  alvoUid: string;
  repetido: boolean;
  papeis: string[];
};

function codigoDoErro(erro: unknown): string | number | null {
  if (erro && typeof erro === 'object' && 'code' in erro) {
    const codigo = (erro as { code?: unknown }).code;
    if (typeof codigo === 'string' || typeof codigo === 'number') return codigo;
  }
  return null;
}

async function buscarUsuario(auth: Auth, email: string): Promise<UserRecord | null> {
  try {
    return await auth.getUserByEmail(email);
  } catch (erro) {
    if (codigoDoErro(erro) === 'auth/user-not-found') return null;
    throw erro;
  }
}

/**
 * Provisiona a identidade sem senha, no padrão da importação inicial: a pessoa
 * define a senha pela recuperação e nenhuma PII além do e-mail é enviada ao Auth.
 */
async function garantirUsuario(auth: Auth, email: string): Promise<UserRecord> {
  const existente = await buscarUsuario(auth, email);
  if (existente) return existente;
  try {
    return await auth.createUser({ email, emailVerified: false, disabled: false });
  } catch (erro) {
    if (codigoDoErro(erro) === 'auth/email-already-exists') {
      const usuario = await buscarUsuario(auth, email);
      if (usuario) return usuario;
    }
    throw erro;
  }
}

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor : '';
}

/**
 * Única fronteira de escrita do perfil de pessoa e do registro restrito do
 * Coordenador. A autoridade é validada dentro da transação e recibo/auditoria
 * são gravados no mesmo commit, sem PII.
 */
export async function salvarPessoa(
  db: Firestore,
  auth: Auth,
  contexto: ContextoPessoa,
  entrada: EntradaPessoa,
): Promise<ResultadoSalvarPessoa> {
  // Valida a autoridade antes de qualquer provisão de identidade: um chamador
  // autenticado sem papel não pode criar contas Auth. A guarda é repetida na
  // transação para não permitir corrida entre a leitura e a escrita.
  const atorPrevio = await db
    .collection('autoridadesAdministrativas')
    .doc(contexto.atorUid)
    .get();
  if (!podeAdministrar(atorPrevio.data())) throw new SemAutoridadeError();

  let uid: string;
  if (entrada.uid) {
    try {
      uid = (await auth.getUser(entrada.uid)).uid;
    } catch {
      throw new AlvoInexistenteError();
    }
  } else {
    uid = (await garantirUsuario(auth, entrada.email)).uid;
  }

  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const pessoaRef = db.collection('pessoas').doc(uid);
  const coordenadorRef = db.collection('coordenadores').doc(uid);

  return db.runTransaction(async (tx) => {
    const atorRef = db.collection('autoridadesAdministrativas').doc(contexto.atorUid);
    const [atorSnap, reciboSnap, pessoaSnap, coordenadorSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(reciboRef),
      tx.get(pessoaRef),
      tx.get(coordenadorRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      // Replay só é aceito quando o conteúdo é idêntico e do mesmo autor.
      if (
        recibo.action !== ACAO_RECIBO_PESSOA ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== entrada.payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        uid,
        repetido: true,
        coordenador: recibo.coordenador === true,
        versao: Number(pessoaSnap.data()?.versao ?? 0),
      };
    }

    const existia = pessoaSnap.exists;
    const versao = Number((pessoaSnap.data() ?? {}).versao ?? 0);
    tx.set(
      pessoaRef,
      {
        uid,
        nomeCompleto: entrada.nomeCompleto,
        email: entrada.email,
        emailNormalizado: entrada.emailNormalizado,
        // Sinaliza a designação vigente; o registro restrito com o CPF é
        // preservado para histórico e nunca apagado em un-designação.
        coordenador: entrada.coordenador,
        origem: contexto.origem,
        versao: versao + 1,
        atualizadoEm: FieldValue.serverTimestamp(),
        ...(existia ? {} : { criadoEm: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );

    if (entrada.coordenador) {
      const versaoCoordenador = Number((coordenadorSnap.data() ?? {}).versao ?? 0);
      tx.set(
        coordenadorRef,
        {
          uid,
          nomeCompleto: entrada.nomeCompleto,
          cpf: entrada.cpf,
          versao: versaoCoordenador + 1,
          atualizadoEm: FieldValue.serverTimestamp(),
          ...(coordenadorSnap.exists ? {} : { criadoEm: FieldValue.serverTimestamp() }),
        },
        { merge: true },
      );
    }

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO_PESSOA,
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      coordenador: entrada.coordenador,
      criadoEm: FieldValue.serverTimestamp(),
    });
    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: existia ? 'PESSOA_ATUALIZADA' : 'PESSOA_CRIADA',
      alvoUid: uid,
      antes: { existia },
      depois: { coordenador: entrada.coordenador },
      criadoEm: FieldValue.serverTimestamp(),
    });
    return { uid, repetido: false, coordenador: entrada.coordenador, versao: versao + 1 };
  });
}

/**
 * Atualiza o conjunto de papéis do agregado canônico. Bloqueia conflito de
 * versão, revogação inexistente e a remoção do último ADMIN ativo; a claim é
 * reconciliada após o commit pelo comando.
 */
export async function alterarPapeis(
  db: Firestore,
  contexto: ContextoPessoa,
  entrada: EntradaPapeis,
): Promise<ResultadoGerenciarPapeis> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);

  return db.runTransaction(async (tx) => {
    const atorRef = db.collection('autoridadesAdministrativas').doc(contexto.atorUid);
    const alvoRef = db.collection('autoridadesAdministrativas').doc(entrada.alvoUid);
    const [atorSnap, alvoSnap, reciboSnap] = await Promise.all([
      tx.get(atorRef),
      tx.get(alvoRef),
      tx.get(reciboRef),
    ]);
    if (!podeAdministrar(atorSnap.data())) throw new SemAutoridadeError();

    if (reciboSnap.exists) {
      const recibo = reciboSnap.data() ?? {};
      if (
        recibo.action !== ACAO_RECIBO_PAPEIS ||
        recibo.actorUid !== contexto.atorUid ||
        recibo.payloadHash !== entrada.payloadHash
      ) {
        throw new ComandoDivergenteError();
      }
      return {
        alvoUid: entrada.alvoUid,
        repetido: true,
        papeis: papeisEfetivos(alvoSnap.data()),
      };
    }

    const atual = alvoSnap.data();
    const versao = Number(atual?.versao ?? 0);
    if (versao !== entrada.expectedVersion) throw new ConflitoVersaoError();

    const atuais = papeisEfetivos(atual);
    const presente = atuais.includes(entrada.papel);
    if (entrada.conceder && presente) throw new OperacaoInvalidaError();
    if (!entrada.conceder && !presente) throw new OperacaoInvalidaError();

    if (!entrada.conceder && entrada.papel === PAPEL_ADMINISTRADOR) {
      // Nunca remove a última administração ativa do sistema.
      const ativos = await tx.get(
        db.collection('autoridadesAdministrativas').where('ativa', '==', true),
      );
      const outros = ativos.docs.filter(
        (doc) => doc.id !== entrada.alvoUid && podeAdministrar(doc.data()),
      );
      if (outros.length === 0) throw new UltimoAdminError();
    }

    const proximos = entrada.conceder
      ? [...atuais, entrada.papel]
      : atuais.filter((papel) => papel !== entrada.papel);
    tx.set(
      alvoRef,
      {
        ativa: proximos.length > 0,
        papeis: proximos,
        papel: FieldValue.delete(),
        versao: versao + 1,
        revisao: Number(atual?.revisao ?? 0) + 1,
        claimStatus: 'PENDENTE',
        atualizadoEm: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.create(reciboRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: ACAO_RECIBO_PAPEIS,
      estado: 'PENDENTE_CLAIM',
      payloadHash: entrada.payloadHash,
      criadoEm: FieldValue.serverTimestamp(),
    });
    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlacaoId,
      actorUid: contexto.atorUid,
      action: entrada.conceder ? 'PAPEL_CONCEDIDO' : 'PAPEL_REVOGADO',
      alvoUid: entrada.alvoUid,
      papel: entrada.papel,
      antes: atuais,
      depois: proximos,
      criadoEm: FieldValue.serverTimestamp(),
    });
    return { alvoUid: entrada.alvoUid, repetido: false, papeis: proximos };
  });
}

/**
 * Consulta autorizada e read-only de pessoas e papéis efetivos. Nunca lê nem
 * devolve CPF; o registro restrito do Coordenador é apenas sinalizado por id.
 */
export async function lerPessoas(
  db: Firestore,
  termo = '',
  atorUid = '',
): Promise<ResumoPessoas> {
  const [pessoasSnap, autoridadesSnap, coordenadoresSnap] = await Promise.all([
    db.collection('pessoas').get(),
    db.collection('autoridadesAdministrativas').get(),
    // Seleciona apenas os IDs para não carregar o CPF do registro restrito.
    db.collection('coordenadores').select().get(),
  ]);
  const autoridades = new Map(
    autoridadesSnap.docs.map((doc) => [doc.id, doc.data()]),
  );
  const coordenadores = new Set(coordenadoresSnap.docs.map((doc) => doc.id));
  const resultado: PessoaResumo[] = [];
  const vistos = new Set<string>();
  for (const doc of pessoasSnap.docs) {
    const dados = doc.data();
    resultado.push({
      uid: doc.id,
      nomeCompleto: texto(dados.nomeCompleto),
      email: texto(dados.email),
      papeis: papeisEfetivos(autoridades.get(doc.id)),
      versao: Number(autoridades.get(doc.id)?.versao ?? 0),
      // Linhas legadas (sem o booleano) usam a presença do registro restrito.
      coordenador:
        typeof dados.coordenador === 'boolean'
          ? dados.coordenador
          : coordenadores.has(doc.id),
    });
    vistos.add(doc.id);
  }
  for (const [uid, autoridade] of autoridades) {
    if (vistos.has(uid)) continue;
    resultado.push({
      uid,
      nomeCompleto: '',
      email: '',
      papeis: papeisEfetivos(autoridade),
      versao: Number(autoridade?.versao ?? 0),
      coordenador: coordenadores.has(uid),
    });
  }
  return {
    pessoas: pesquisarPessoas(resultado, termo),
    contexto: { uid: atorUid, papeis: papeisEfetivos(autoridades.get(atorUid)) },
  };
}

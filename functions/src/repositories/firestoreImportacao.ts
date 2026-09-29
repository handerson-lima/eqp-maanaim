import type { Auth, UserRecord } from 'firebase-admin/auth';
import {
  FieldValue,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  ConflitoVinculoError,
  IgrejaInativaError,
  PAPEL_PASTOR_LOCAL,
  idDaLinha,
  type ContextoLinha,
  type EntradaValidada,
  type IgrejaResumo,
  type PessoaResumo,
  type PortasImportacao,
} from '../domain/importacaoPastores.js';

function codigoDoErro(erro: unknown): string | number | null {
  if (erro && typeof erro === 'object' && 'code' in erro) {
    const codigo = (erro as { code?: unknown }).code;
    if (typeof codigo === 'string' || typeof codigo === 'number') return codigo;
  }
  return null;
}

async function buscarUsuario(
  auth: Auth,
  email: string,
): Promise<UserRecord | null> {
  try {
    return await auth.getUserByEmail(email);
  } catch (erro) {
    if (codigoDoErro(erro) === 'auth/user-not-found') return null;
    throw erro;
  }
}

async function garantirUsuario(auth: Auth, email: string): Promise<UserRecord> {
  const existente = await buscarUsuario(auth, email);
  if (existente) return existente;
  try {
    // Conta criada sem senha e sem convite: a definição de senha acontece
    // exclusivamente pela recuperação iniciada pelo próprio pastor.
    return await auth.createUser({ email, emailVerified: false, disabled: false });
  } catch (erro) {
    if (codigoDoErro(erro) === 'auth/email-already-exists') {
      const usuario = await buscarUsuario(auth, email);
      if (usuario) return usuario;
    }
    throw erro;
  }
}

/**
 * Adapta Firestore/Auth às portas da carga. Toda escrita de vínculo, recibo e
 * auditoria ocorre na mesma transação sobre o documento canônico da igreja.
 */
export function criarPortasFirestore(
  db: Firestore,
  auth: Auth,
): PortasImportacao {
  return {
    async buscarIgrejaPorCodigo(codigo: string): Promise<IgrejaResumo | null> {
      const snap = await db
        .collection('igrejas')
        .where('codigo', '==', codigo)
        .limit(2)
        .get();
      if (snap.empty) return null;
      if (snap.size > 1) throw new Error('IGREJA_AMBIGUA');
      const doc = snap.docs[0];
      const dados = doc.data();
      const vigente = dados.pastorLocalVigentePessoaId;
      return {
        id: doc.id,
        codigo: String(dados.codigo ?? codigo),
        ativo: dados.ativo === true,
        pastorLocalVigentePessoaId:
          typeof vigente === 'string' ? vigente : null,
      };
    },

    async buscarPessoaPorEmail(
      emailNormalizado: string,
    ): Promise<PessoaResumo | null> {
      const usuario = await buscarUsuario(auth, emailNormalizado);
      if (!usuario) return null;
      const pessoa = await db.collection('pessoas').doc(usuario.uid).get();
      return pessoa.exists ? { id: usuario.uid } : null;
    },

    async garantirIdentidade(
      entrada: EntradaValidada,
      contexto: ContextoLinha,
    ): Promise<PessoaResumo> {
      const usuario = await garantirUsuario(auth, entrada.email);
      const pessoaRef = db.collection('pessoas').doc(usuario.uid);
      const pessoa = await pessoaRef.get();
      // Nunca sobrescreve um cadastro já administrado; apenas cria o ausente.
      if (!pessoa.exists) {
        try {
          await pessoaRef.create({
            uid: usuario.uid,
            nomeCompleto: entrada.nomeCompleto,
            email: entrada.email,
            origem: contexto.origem,
            criadoEm: FieldValue.serverTimestamp(),
            atualizadoEm: FieldValue.serverTimestamp(),
          });
        } catch (erro) {
          const codigo = codigoDoErro(erro);
          if (codigo !== 6 && codigo !== 'already-exists') throw erro;
        }
      }
      return { id: usuario.uid };
    },

    async aplicarVinculo(
      entrada: EntradaValidada,
      pessoa: PessoaResumo,
      igreja: IgrejaResumo,
      contexto: ContextoLinha,
    ): Promise<'CRIADO' | 'JA_VIGENTE'> {
      const igrejaRef = db.collection('igrejas').doc(igreja.id);
      const vinculoRef = db.collection('vinculosPastorIgreja').doc();
      const linhaId = idDaLinha(contexto.commandId, entrada.codigoIgreja);
      const reciboRef = db.collection('commands').doc(linhaId);
      const auditoriaRef = db.collection('auditOutbox').doc(linhaId);

      return db.runTransaction(async (tx) => {
        const igrejaAtual = await tx.get(igrejaRef);
        const reciboAtual = await tx.get(reciboRef);

        if (reciboAtual.exists) {
          const dados = reciboAtual.data() ?? {};
          if (dados.payloadHash === entrada.payloadHash) return 'JA_VIGENTE';
          throw new ComandoDivergenteError();
        }

        const dadosIgreja = igrejaAtual.data() ?? {};
        if (!igrejaAtual.exists || dadosIgreja.ativo !== true) {
          throw new IgrejaInativaError();
        }
        const vigente =
          typeof dadosIgreja.pastorLocalVigentePessoaId === 'string'
            ? dadosIgreja.pastorLocalVigentePessoaId
            : null;
        if (vigente) {
          if (vigente === pessoa.id) return 'JA_VIGENTE';
          throw new ConflitoVinculoError();
        }

        tx.update(igrejaRef, {
          pastorLocalVigentePessoaId: pessoa.id,
          pastorLocalVigenteVinculoId: vinculoRef.id,
          atualizadoEm: FieldValue.serverTimestamp(),
        });
        tx.create(vinculoRef, {
          pessoaId: pessoa.id,
          igrejaId: igreja.id,
          codigoIgreja: entrada.codigoIgreja,
          papel: PAPEL_PASTOR_LOCAL,
          estado: 'VIGENTE',
          inicioVigencia: FieldValue.serverTimestamp(),
          fimVigencia: null,
          origem: contexto.origem,
          commandId: contexto.commandId,
          correlationId: contexto.correlacaoId,
          criadoEm: FieldValue.serverTimestamp(),
        });
        tx.create(reciboRef, {
          commandId: contexto.commandId,
          correlationId: contexto.correlacaoId,
          action: 'IMPORTAR_VINCULO_PASTOR_INICIAL',
          estado: 'COMPLETO',
          codigoIgreja: entrada.codigoIgreja,
          igrejaId: igreja.id,
          pessoaId: pessoa.id,
          vinculoId: vinculoRef.id,
          payloadHash: entrada.payloadHash,
          origem: contexto.origem,
          criadoEm: FieldValue.serverTimestamp(),
        });
        tx.create(auditoriaRef, {
          commandId: contexto.commandId,
          correlationId: contexto.correlacaoId,
          action: 'VINCULO_PASTOR_CRIADO',
          igrejaId: igreja.id,
          codigoIgreja: entrada.codigoIgreja,
          pessoaId: pessoa.id,
          vinculoId: vinculoRef.id,
          papel: PAPEL_PASTOR_LOCAL,
          ator: contexto.origem,
          criadoEm: FieldValue.serverTimestamp(),
        });
        return 'CRIADO';
      });
    },
  };
}

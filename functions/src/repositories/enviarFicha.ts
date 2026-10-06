import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import { cpfValido } from '../domain/cpf.js';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DadosIncompletosError,
  EquipeInativaError,
  FichaNaoEncontradaError,
  FichaNaoRascunhoError,
  IgrejaInativaError,
  PermissaoNegadaError,
  SemParticipacoesError,
  TermoNaoAceitoError,
  type EntradaEnviarFichaAprovacao,
  type ResultadoEnviarFichaAprovacao,
} from '../domain/enviarFicha.js';
import { TERMO_ID_PADRAO } from '../domain/termos.js';

export interface ContextoEnviarFicha {
  commandId: string;
  correlationId?: string;
  uid: string;
}

function iso(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return String(valor);
}

/**
 * Executa de forma atômica e transacional a submissão da ficha do voluntário:
 * 1. Validação de idempotência em commands/{commandId}.
 * 2. Validação da ficha existente, em RASCUNHO, sem concorrência e com dados completos.
 * 3. Validação do termo vigente aceito.
 * 4. Validação das equipes das participações (ao menos uma ativa).
 * 5. Validação da igreja ativa.
 * 6. Transição da ficha para AGUARDANDO_PASTOR_LOCAL e incremento de versão.
 * 7. Transição das participações de rascunho para AGUARDANDO_PASTOR_LOCAL.
 * 8. Materialização da projeção filaPendencias para o pastor local.
 * 9. Gravação do recibo em commands e evento append-only em auditOutbox.
 */
export async function enviarFichaAprovacaoRepo(
  db: Firestore,
  contexto: ContextoEnviarFicha,
  entrada: EntradaEnviarFichaAprovacao,
): Promise<ResultadoEnviarFichaAprovacao> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(contexto.uid);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const filaRef = db.collection('filaPendencias').doc(contexto.uid);

  return await db.runTransaction(async (tx) => {
    // 1. Verificação de idempotência no recibo de comando
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new PermissaoNegadaError('Operação indisponível para o usuário informado.');
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        estado: String(res?.estado ?? 'AGUARDANDO_PASTOR_LOCAL'),
        versao: Number(res?.versao ?? 1),
        proximaAcao: String(res?.proximaAcao ?? 'Aguardando avaliação do Pastor Local'),
        igrejaId: String(res?.igrejaId ?? ''),
        enviadoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação da Ficha Permanente
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};

    if (fichaData.estado && fichaData.estado !== 'RASCUNHO') {
      throw new FichaNaoRascunhoError();
    }

    const versaoAtual = Number(fichaData.versao ?? 1);
    if (
      entrada.expectedVersion !== undefined &&
      entrada.expectedVersion !== null &&
      versaoAtual !== entrada.expectedVersion
    ) {
      throw new ConflitoVersaoError();
    }

    // Validação estrita de campos cadastrais obrigatórios
    const nomeCompleto = String(fichaData.nomeCompleto ?? '').trim();
    const profissao = String(fichaData.profissao ?? '').trim();
    const cpf = String(fichaData.cpf ?? '').trim();
    const igrejaId = String(fichaData.igrejaId ?? '').trim();

    if (
      nomeCompleto.length < 3 ||
      profissao.length < 2 ||
      !cpfValido(cpf) ||
      igrejaId.length === 0
    ) {
      throw new DadosIncompletosError();
    }

    // 3. Validação do termo vigente aceito
    const termoAceito = fichaData.termoAceito as Record<string, unknown> | undefined;
    if (!termoAceito || !termoAceito.versaoId || !termoAceito.hashSha256) {
      throw new TermoNaoAceitoError();
    }

    const termoId = String(termoAceito.termoId || TERMO_ID_PADRAO);
    const termoRef = db.collection('termos').doc(termoId);
    const termoSnap = await tx.get(termoRef);
    if (!termoSnap.exists || termoSnap.data()?.ativo !== true) {
      throw new TermoNaoAceitoError('Termo de voluntariado institucional inativo ou não encontrado.');
    }
    const termoData = termoSnap.data() ?? {};
    if (termoData.versaoVigenteId !== termoAceito.versaoId) {
      throw new TermoNaoAceitoError('O termo aceito não corresponde à versão atualmente vigente.');
    }

    // 4. Validação das participações e equipes
    const participacoesSnap = await tx.get(
      db.collection('participacoes').where('fichaId', '==', contexto.uid),
    );
    const semParticipacoes =
      !participacoesSnap ||
      participacoesSnap.empty === true ||
      (Array.isArray(participacoesSnap.docs) && participacoesSnap.docs.length === 0);

    if (semParticipacoes) {
      throw new SemParticipacoesError();
    }

    const participacoesDocs = participacoesSnap.docs;
    const equipesParaValidar = Array.from(
      new Set(
        participacoesDocs.map((doc) => String(doc.data()?.equipeId ?? '')).filter(Boolean),
      ),
    );

    for (const equipeId of equipesParaValidar) {
      const equipeDoc = await tx.get(db.collection('equipes').doc(equipeId));
      if (!equipeDoc.exists || equipeDoc.data()?.ativo !== true) {
        throw new EquipeInativaError(`Equipe ${equipeId} está inativa ou não existe.`);
      }
    }

    // 5. Validação da Igreja
    const igrejaDoc = await tx.get(db.collection('igrejas').doc(igrejaId));
    if (!igrejaDoc.exists || igrejaDoc.data()?.ativo !== true) {
      throw new IgrejaInativaError();
    }
    const igrejaData = igrejaDoc.data() ?? {};
    const pastorLocalPessoaId = (igrejaData.pastorLocalVigentePessoaId as string) || null;

    // 6. Transição de agregados
    const novaVersao = versaoAtual + 1;
    const agora = FieldValue.serverTimestamp();
    const proximaAcao = 'Aguardando avaliação do Pastor Local';

    // Ficha
    tx.update(fichaRef, {
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      proximaAcao,
      versao: novaVersao,
      enviadoEm: agora,
      atualizadoEm: agora,
    });

    // Participações
    const participacoesSumario: Array<{ id: string; equipeId: string; nomeEquipe: string }> = [];
    for (const partDoc of participacoesDocs) {
      const d = partDoc.data() ?? {};
      if (d.estado === 'RASCUNHO') {
        tx.update(partDoc.ref, {
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          proximaAcao,
          atualizadoEm: agora,
        });
      }
      participacoesSumario.push({
        id: partDoc.id,
        equipeId: String(d.equipeId ?? ''),
        nomeEquipe: String(d.nomeEquipe ?? ''),
      });
    }

    // 7. Projeção de Fila para o Pastor Local
    tx.set(filaRef, {
      fichaId: contexto.uid,
      voluntarioUid: contexto.uid,
      voluntarioNome: nomeCompleto,
      igrejaId,
      pastorLocalPessoaId,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      proximaAcao,
      ano: new Date().getUTCFullYear(),
      equipes: participacoesSumario.map((p) => ({
        equipeId: p.equipeId,
        nomeEquipe: p.nomeEquipe,
      })),
      enviadoEm: agora,
      atualizadoEm: agora,
    });

    // 8. Recibo Idempotente
    const resultadoOperacao = {
      sucesso: true,
      repetido: false,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: novaVersao,
      proximaAcao,
      igrejaId,
    };

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.uid,
      acao: 'ENVIAR_FICHA_APROVACAO',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado: resultadoOperacao,
      criadoEm: agora,
    });

    // 9. Auditoria append-only em auditOutbox
    tx.create(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: entrada.correlationId ?? contexto.commandId,
      atorUid: contexto.uid,
      acao: 'FICHA_ENVIADA_APROVACAO',
      entidades: [
        { tipo: 'FICHA', id: contexto.uid },
        { tipo: 'FILA_PENDENCIAS', id: contexto.uid },
        ...participacoesSumario.map((p) => ({ tipo: 'PARTICIPACAO', id: p.id })),
      ],
      antes: { estado: 'RASCUNHO' },
      depois: { estado: 'AGUARDANDO_PASTOR_LOCAL' },
      metadados: {
        igrejaId,
        quantidadeEquipes: participacoesSumario.length,
      },
      timestamp: agora,
    });

    return {
      sucesso: true,
      repetido: false,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: novaVersao,
      proximaAcao,
      igrejaId,
      enviadoEm: new Date().toISOString(),
    };
  });
}

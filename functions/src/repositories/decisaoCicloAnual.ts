import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  CicloNaoElegivelError,
  CicloNaoEncontradoError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  ParticipacaoCicloNaoEncontradaError,
  ReuniaoPastoresNaoConfirmadaError,
  SemAutoridadeCoordenadorError,
  SemVinculoPastoralError,
  SemVinculoResponsavelEquipeError,
  type EntradaConcluirCicloAnualCoordenador,
  type EntradaDecidirCicloAnualPastor,
  type EntradaDecidirCicloAnualResponsavel,
  type ResultadoConcluirCicloAnualCoordenador,
  type ResultadoDecidirCicloAnualPastor,
  type ResultadoDecidirCicloAnualResponsavel,
} from '../domain/decisaoCicloAnual.js';
import { avaliarAutoridadeCoordenador } from './decisaoCoordenador.js';
import { calcularVigenciaAnual } from '../domain/vigencia.js';

export interface ContextoDecisaoCiclo {
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

// ----------------------------------------------------------------------------
// Etapa 1: Decisão do Pastor Local no Ciclo Anual
// ----------------------------------------------------------------------------

export async function decidirCicloAnualPastorRepo(
  db: Firestore,
  contexto: ContextoDecisaoCiclo,
  entrada: EntradaDecidirCicloAnualPastor,
): Promise<ResultadoDecidirCicloAnualPastor> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const cicloRef = db.collection('ciclos').doc(entrada.cicloId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em commands
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new SemVinculoPastoralError('Operação indisponível para o usuário informado.');
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        cicloId: entrada.cicloId,
        decisao: entrada.decisao,
        estadoCiclo: String(res?.estadoCiclo ?? 'AGUARDANDO_RESPONSAVEL_EQUIPE'),
        proximaAcao: String(res?.proximaAcao ?? ''),
        decididoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação do Ciclo Anual
    const cicloSnap = await tx.get(cicloRef);
    if (!cicloSnap.exists) {
      throw new CicloNaoEncontradoError();
    }
    const cicloData = cicloSnap.data() ?? {};

    if (cicloData.estado !== 'AGUARDANDO_PASTOR_LOCAL') {
      throw new CicloNaoElegivelError(
        `Ciclo em estado '${cicloData.estado}', esperado 'AGUARDANDO_PASTOR_LOCAL'.`,
      );
    }

    const versaoAtualCiclo = Number(cicloData.versao ?? 1);
    if (entrada.expectedVersion && versaoAtualCiclo !== entrada.expectedVersion) {
      throw new ConflitoVersaoError();
    }

    const participacaoId = String(cicloData.participacaoId ?? '');
    if (!participacaoId) {
      throw new ParticipacaoCicloNaoEncontradaError();
    }

    // 3. Leitura da Participação e da Ficha
    const partRef = db.collection('participacoes').doc(participacaoId);
    const partSnap = await tx.get(partRef);
    if (!partSnap.exists) {
      throw new ParticipacaoCicloNaoEncontradaError();
    }
    const partData = partSnap.data() ?? {};

    const fichaId = String(cicloData.fichaId ?? partData.fichaId ?? '');
    const fichaRef = db.collection('fichas').doc(fichaId);
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new CicloNaoEncontradoError('Ficha do voluntário não encontrada.');
    }
    const fichaData = fichaSnap.data() ?? {};

    const igrejaId = String(fichaData.igrejaId ?? '').trim();
    if (!igrejaId) {
      throw new SemVinculoPastoralError('Voluntário sem igreja vinculada.');
    }

    // 4. Validação do Vínculo Pastoral Vigente
    const igrejaRef = db.collection('igrejas').doc(igrejaId);
    const igrejaSnap = await tx.get(igrejaRef);
    if (!igrejaSnap.exists || igrejaSnap.data()?.ativo === false) {
      throw new SemVinculoPastoralError('A igreja vinculada está inativa ou não existe.');
    }

    const igrejaData = igrejaSnap.data() ?? {};
    if (igrejaData.pastorLocalVigentePessoaId !== contexto.uid) {
      throw new SemVinculoPastoralError();
    }

    const vinculoVigenteId = String(igrejaData.pastorLocalVigenteVinculoId ?? '');
    if (vinculoVigenteId) {
      const vinculoSnap = await tx.get(
        db.collection('vinculosPastorIgreja').doc(vinculoVigenteId),
      );
      if (vinculoSnap.exists) {
        const vData = vinculoSnap.data() ?? {};
        if (vData.estado !== 'VIGENTE' || vData.pessoaId !== contexto.uid) {
          throw new SemVinculoPastoralError('Vínculo pastoral expirado ou substituído.');
        }
      }
    }

    // 5. Nome do Pastor para auditoria e evidência
    const pastorPessoaSnap = await tx.get(db.collection('pessoas').doc(contexto.uid));
    const pastorNome = pastorPessoaSnap.exists
      ? String(pastorPessoaSnap.data()?.nomeCompleto ?? 'Pastor Local')
      : 'Pastor Local';

    const agoraDate = new Date();
    const agoraTs = Timestamp.fromDate(agoraDate);
    const agoraIso = agoraDate.toISOString();
    const novaVersaoCiclo = versaoAtualCiclo + 1;
    const versaoPart = Number(partData.versao ?? 1);

    let novoEstadoCiclo: string;
    let proximaAcao: string;

    if (entrada.decisao === 'APROVADO') {
      novoEstadoCiclo = 'AGUARDANDO_RESPONSAVEL_EQUIPE';
      proximaAcao = 'Aguardando avaliação do Responsável de Equipe (Ciclo Anual)';

      tx.update(cicloRef, {
        estado: novoEstadoCiclo,
        versao: novaVersaoCiclo,
        decisaoPastoral: {
          decisao: 'APROVADO',
          pastorUid: contexto.uid,
          pastorNome,
          vinculoId: vinculoVigenteId,
          decididoEm: agoraTs,
        },
        atualizadoEm: agoraTs,
      });

      tx.update(partRef, {
        proximaAcao,
        versao: versaoPart + 1,
        atualizadoEm: agoraTs,
      });

      // Evidência imutável
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'DECISAO_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        fichaId,
        etapa: 'PASTOR_LOCAL',
        decisao: 'APROVADO',
        atorUid: contexto.uid,
        atorNome: pastorNome,
        papel: 'PASTOR_LOCAL',
        igrejaId,
        justificativa: null,
        criadoEm: agoraTs,
      });
    } else {
      // DESFAVORAVEL
      novoEstadoCiclo = 'REJEITADO';
      proximaAcao = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;

      tx.update(cicloRef, {
        estado: novoEstadoCiclo,
        versao: novaVersaoCiclo,
        justificativaInterna: entrada.justificativa,
        decisaoPastoral: {
          decisao: 'DESFAVORAVEL',
          pastorUid: contexto.uid,
          pastorNome,
          vinculoId: vinculoVigenteId,
          justificativa: entrada.justificativa,
          decididoEm: agoraTs,
        },
        atualizadoEm: agoraTs,
      });

      tx.update(partRef, {
        intencaoRenovacao: 'NAO_CONTINUAR',
        programadoEncerramentoEm: partData.vigenciaFim ?? null,
        proximaAcao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
        versao: versaoPart + 1,
        atualizadoEm: agoraTs,
      });

      // Evidência imutável
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'DECISAO_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        fichaId,
        etapa: 'PASTOR_LOCAL',
        decisao: 'DESFAVORAVEL',
        atorUid: contexto.uid,
        atorNome: pastorNome,
        papel: 'PASTOR_LOCAL',
        igrejaId,
        justificativa: entrada.justificativa,
        criadoEm: agoraTs,
      });
    }

    // Atualização da fila do pastor se existia projeção associada
    const filaRef = db.collection('filaPendencias').doc(fichaId);
    const filaSnap = await tx.get(filaRef);
    if (filaSnap.exists) {
      const filaData = filaSnap.data() ?? {};
      const equipesRenovacao = Array.isArray(filaData.equipesRenovacao)
        ? (filaData.equipesRenovacao as Array<{ equipeId: string; nomeEquipe: string }>)
        : [];
      const restante = equipesRenovacao.filter((eq) => eq.equipeId !== cicloData.equipeId);
      if (restante.length === 0 && filaData.estado === 'AGUARDANDO_PASTOR_LOCAL') {
        tx.delete(filaRef);
      } else {
        tx.update(filaRef, {
          equipesRenovacao: restante,
          atualizadoEm: agoraTs,
        });
      }
    }

    // Evento append-only na Ficha
    const eventoRef = db
      .collection('fichas')
      .doc(fichaId)
      .collection('eventos')
      .doc(contexto.commandId);

    tx.set(eventoRef, {
      commandId: contexto.commandId,
      tipo: 'DECISAO_PASTORAL_CICLO_ANUAL',
      cicloId: entrada.cicloId,
      participacaoId,
      equipeId: cicloData.equipeId,
      decisao: entrada.decisao,
      data: agoraTs,
    });

    // Auditoria append-only (sem PII)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      atorUid: contexto.uid,
      acao: 'DECISAO_PASTORAL_CICLO_ANUAL',
      entidade: 'ciclos',
      entidadeId: entrada.cicloId,
      payloadHash: entrada.payloadHash,
      criadoEm: agoraTs,
      processado: false,
    });

    const resultado: ResultadoDecidirCicloAnualPastor = {
      sucesso: true,
      repetido: false,
      cicloId: entrada.cicloId,
      decisao: entrada.decisao,
      estadoCiclo: novoEstadoCiclo,
      proximaAcao,
      decididoEm: agoraIso,
    };

    // Recibo idempotente
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.uid,
      acao: 'DECIDIR_CICLO_ANUAL_PASTOR',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado,
      criadoEm: agoraTs,
    });

    return resultado;
  });
}

// ----------------------------------------------------------------------------
// Etapa 2: Decisão do Responsável de Equipe no Ciclo Anual
// ----------------------------------------------------------------------------

export async function decidirCicloAnualResponsavelRepo(
  db: Firestore,
  contexto: ContextoDecisaoCiclo,
  entrada: EntradaDecidirCicloAnualResponsavel,
): Promise<ResultadoDecidirCicloAnualResponsavel> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const cicloRef = db.collection('ciclos').doc(entrada.cicloId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em commands
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new SemVinculoResponsavelEquipeError(
          'Operação indisponível para o usuário informado.',
        );
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        cicloId: entrada.cicloId,
        decisao: entrada.decisao,
        estadoCiclo: String(res?.estadoCiclo ?? 'AGUARDANDO_COORDENADOR'),
        proximaAcao: String(res?.proximaAcao ?? ''),
        decididoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação do Ciclo Anual
    const cicloSnap = await tx.get(cicloRef);
    if (!cicloSnap.exists) {
      throw new CicloNaoEncontradoError();
    }
    const cicloData = cicloSnap.data() ?? {};

    if (cicloData.estado !== 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
      throw new CicloNaoElegivelError(
        `Ciclo em estado '${cicloData.estado}', esperado 'AGUARDANDO_RESPONSAVEL_EQUIPE'.`,
      );
    }

    const versaoAtualCiclo = Number(cicloData.versao ?? 1);
    if (entrada.expectedVersion && versaoAtualCiclo !== entrada.expectedVersion) {
      throw new ConflitoVersaoError();
    }

    const equipeId = String(cicloData.equipeId ?? '').trim();
    if (!equipeId) {
      throw new SemVinculoResponsavelEquipeError('Ciclo sem equipe vinculada.');
    }

    // 3. Validação da autoridade vigente sobre a Equipe
    const equipeRef = db.collection('equipes').doc(equipeId);
    const equipeSnap = await tx.get(equipeRef);
    if (!equipeSnap.exists || equipeSnap.data()?.ativo === false) {
      throw new SemVinculoResponsavelEquipeError('A equipe vinculada está inativa ou não existe.');
    }

    const equipeData = equipeSnap.data() ?? {};
    if (equipeData.responsavelVigentePessoaId !== contexto.uid) {
      throw new SemVinculoResponsavelEquipeError();
    }

    const vinculoVigenteId = String(equipeData.responsavelVigenteVinculoId ?? '');
    if (vinculoVigenteId) {
      const vinculoSnap = await tx.get(
        db.collection('vinculosPastorEquipe').doc(vinculoVigenteId),
      );
      if (vinculoSnap.exists) {
        const vData = vinculoSnap.data() ?? {};
        if (vData.estado !== 'VIGENTE' || vData.pessoaId !== contexto.uid) {
          throw new SemVinculoResponsavelEquipeError(
            'Vínculo de responsável de equipe expirado ou substituído.',
          );
        }
      }
    }

    // 4. Nome do Responsável
    const responsavelPessoaSnap = await tx.get(db.collection('pessoas').doc(contexto.uid));
    const responsavelNome = responsavelPessoaSnap.exists
      ? String(responsavelPessoaSnap.data()?.nomeCompleto ?? 'Responsável de Equipe')
      : 'Responsável de Equipe';

    // 5. Leitura da Participação
    const participacaoId = String(cicloData.participacaoId ?? '');
    const partRef = db.collection('participacoes').doc(participacaoId);
    const partSnap = await tx.get(partRef);
    if (!partSnap.exists) {
      throw new ParticipacaoCicloNaoEncontradaError();
    }
    const partData = partSnap.data() ?? {};
    const fichaId = String(cicloData.fichaId ?? partData.fichaId ?? '');

    const agoraDate = new Date();
    const agoraTs = Timestamp.fromDate(agoraDate);
    const agoraIso = agoraDate.toISOString();
    const novaVersaoCiclo = versaoAtualCiclo + 1;
    const versaoPart = Number(partData.versao ?? 1);

    let novoEstadoCiclo: string;
    let proximaAcao: string;

    if (entrada.decisao === 'APROVADO') {
      novoEstadoCiclo = 'AGUARDANDO_COORDENADOR';
      proximaAcao = 'Aguardando conclusão do Coordenador (Ciclo Anual)';

      tx.update(cicloRef, {
        estado: novoEstadoCiclo,
        versao: novaVersaoCiclo,
        decisaoResponsavel: {
          decisao: 'APROVADO',
          responsavelUid: contexto.uid,
          responsavelNome,
          equipeId,
          vinculoId: vinculoVigenteId,
          decididoEm: agoraTs,
        },
        atualizadoEm: agoraTs,
      });

      tx.update(partRef, {
        proximaAcao,
        versao: versaoPart + 1,
        atualizadoEm: agoraTs,
      });

      // Evidência imutável
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'DECISAO_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        fichaId,
        etapa: 'RESPONSAVEL_EQUIPE',
        decisao: 'APROVADO',
        atorUid: contexto.uid,
        atorNome: responsavelNome,
        papel: 'RESPONSAVEL_EQUIPE',
        equipeId,
        vinculoId: vinculoVigenteId,
        justificativa: null,
        criadoEm: agoraTs,
      });
    } else {
      // DESFAVORAVEL
      novoEstadoCiclo = 'REJEITADO';
      proximaAcao = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;

      tx.update(cicloRef, {
        estado: novoEstadoCiclo,
        versao: novaVersaoCiclo,
        justificativaInterna: entrada.justificativa,
        decisaoResponsavel: {
          decisao: 'DESFAVORAVEL',
          responsavelUid: contexto.uid,
          responsavelNome,
          equipeId,
          vinculoId: vinculoVigenteId,
          justificativa: entrada.justificativa,
          decididoEm: agoraTs,
        },
        atualizadoEm: agoraTs,
      });

      tx.update(partRef, {
        intencaoRenovacao: 'NAO_CONTINUAR',
        programadoEncerramentoEm: partData.vigenciaFim ?? null,
        proximaAcao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
        versao: versaoPart + 1,
        atualizadoEm: agoraTs,
      });

      // Evidência imutável
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'DECISAO_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        fichaId,
        etapa: 'RESPONSAVEL_EQUIPE',
        decisao: 'DESFAVORAVEL',
        atorUid: contexto.uid,
        atorNome: responsavelNome,
        papel: 'RESPONSAVEL_EQUIPE',
        equipeId,
        vinculoId: vinculoVigenteId,
        justificativa: entrada.justificativa,
        criadoEm: agoraTs,
      });
    }

    // Evento append-only na Ficha
    if (fichaId) {
      const eventoRef = db
        .collection('fichas')
        .doc(fichaId)
        .collection('eventos')
        .doc(contexto.commandId);

      tx.set(eventoRef, {
        commandId: contexto.commandId,
        tipo: 'DECISAO_RESPONSAVEL_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        equipeId,
        decisao: entrada.decisao,
        data: agoraTs,
      });
    }

    // Auditoria append-only (sem PII)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      atorUid: contexto.uid,
      acao: 'DECISAO_RESPONSAVEL_CICLO_ANUAL',
      entidade: 'ciclos',
      entidadeId: entrada.cicloId,
      payloadHash: entrada.payloadHash,
      criadoEm: agoraTs,
      processado: false,
    });

    const resultado: ResultadoDecidirCicloAnualResponsavel = {
      sucesso: true,
      repetido: false,
      cicloId: entrada.cicloId,
      decisao: entrada.decisao,
      estadoCiclo: novoEstadoCiclo,
      proximaAcao,
      decididoEm: agoraIso,
    };

    // Recibo idempotente
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.uid,
      acao: 'DECIDIR_CICLO_ANUAL_RESPONSAVEL',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado,
      criadoEm: agoraTs,
    });

    return resultado;
  });
}

// ----------------------------------------------------------------------------
// Etapa 3: Conclusão pelo Coordenador Geral no Ciclo Anual
// ----------------------------------------------------------------------------

export async function concluirCicloAnualCoordenadorRepo(
  db: Firestore,
  contexto: ContextoDecisaoCiclo,
  entrada: EntradaConcluirCicloAnualCoordenador,
): Promise<ResultadoConcluirCicloAnualCoordenador> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const cicloRef = db.collection('ciclos').doc(entrada.cicloId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em commands
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.uid) {
        throw new SemAutoridadeCoordenadorError('Operação indisponível para o usuário informado.');
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        cicloId: entrada.cicloId,
        participacaoId: String(res?.participacaoId ?? ''),
        decisao: entrada.decisao,
        estadoCiclo: String(res?.estadoCiclo ?? 'CONCLUIDO'),
        vigenciaInicio: res?.vigenciaInicio as string | undefined,
        vigenciaFim: res?.vigenciaFim as string | undefined,
        proximaAcao: String(res?.proximaAcao ?? 'Voluntariado ativo'),
        decididoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação do Ciclo Anual
    const cicloSnap = await tx.get(cicloRef);
    if (!cicloSnap.exists) {
      throw new CicloNaoEncontradoError();
    }
    const cicloData = cicloSnap.data() ?? {};

    if (cicloData.estado !== 'AGUARDANDO_COORDENADOR') {
      throw new CicloNaoElegivelError(
        `Ciclo em estado '${cicloData.estado}', esperado 'AGUARDANDO_COORDENADOR'.`,
      );
    }

    const versaoAtualCiclo = Number(cicloData.versao ?? 1);
    if (entrada.expectedVersion && versaoAtualCiclo !== entrada.expectedVersion) {
      throw new ConflitoVersaoError();
    }

    // 3. Validação de Autoridade do Coordenador Geral na transação (AD-1/AD-2)
    const autoridadeSnap = await tx.get(
      db.collection('autoridadesAdministrativas').doc(contexto.uid),
    );
    const pessoaSnap = await tx.get(db.collection('pessoas').doc(contexto.uid));
    const coordenadorNome = pessoaSnap.exists
      ? String(pessoaSnap.data()?.nomeCompleto ?? 'Coordenador Geral')
      : 'Coordenador Geral';

    const autoridade = avaliarAutoridadeCoordenador(
      autoridadeSnap.exists ? autoridadeSnap.data() : undefined,
      coordenadorNome,
    );

    if (!autoridade.autorizado) {
      throw new SemAutoridadeCoordenadorError();
    }

    // 4. Leitura da Participação
    const participacaoId = String(cicloData.participacaoId ?? '');
    const partRef = db.collection('participacoes').doc(participacaoId);
    const partSnap = await tx.get(partRef);
    if (!partSnap.exists) {
      throw new ParticipacaoCicloNaoEncontradaError();
    }
    const partData = partSnap.data() ?? {};
    const fichaId = String(cicloData.fichaId ?? partData.fichaId ?? '');

    const agoraDate = new Date();
    const agoraTs = Timestamp.fromDate(agoraDate);
    const agoraIso = agoraDate.toISOString();
    const novaVersaoCiclo = versaoAtualCiclo + 1;
    const versaoPart = Number(partData.versao ?? 1);

    let novoEstadoCiclo: string;
    let proximaAcao: string;
    let vigenciaInicioIso: string | undefined;
    let vigenciaFimIso: string | undefined;

    if (entrada.decisao === 'APROVADO') {
      if (!entrada.confirmouReuniaoPastores) {
        throw new ReuniaoPastoresNaoConfirmadaError();
      }

      novoEstadoCiclo = 'CONCLUIDO';
      proximaAcao = 'Voluntariado ativo';

      // Cálculo determinístico da nova vigência de 1 ano (AD-7 / Story 5.1)
      const novaVigencia = calcularVigenciaAnual(agoraDate);
      const vigenciaInicioTs = Timestamp.fromDate(novaVigencia.vigenciaInicio);
      const vigenciaFimTs = Timestamp.fromDate(novaVigencia.vigenciaFim);
      vigenciaInicioIso = novaVigencia.vigenciaInicio.toISOString();
      vigenciaFimIso = novaVigencia.vigenciaFim.toISOString();

      tx.update(cicloRef, {
        estado: novoEstadoCiclo,
        versao: novaVersaoCiclo,
        vigenciaInicio: vigenciaInicioTs,
        vigenciaFim: vigenciaFimTs,
        coordenadorUid: contexto.uid,
        coordenadorNome,
        confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
        observacao: entrada.observacao ?? null,
        decisaoCoordenador: {
          decisao: 'APROVADO',
          coordenadorUid: contexto.uid,
          coordenadorNome,
          papel: autoridade.papel,
          confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
          observacao: entrada.observacao ?? null,
          decididoEm: agoraTs,
        },
        atualizadoEm: agoraTs,
      });

      // Atualiza a participação com a nova vigência e zera flags transitórias
      tx.update(partRef, {
        estado: 'ATIVA',
        vigenciaInicio: vigenciaInicioTs,
        vigenciaFim: vigenciaFimTs,
        cicloAtualId: entrada.cicloId,
        cicloRenovacaoId: null,
        intencaoRenovacao: null,
        proximaAcao,
        versao: versaoPart + 1,
        atualizadoEm: agoraTs,
      });

      // Evidência imutável
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'CONCLUSAO_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        fichaId,
        etapa: 'COORDENADOR_GERAL',
        decisao: 'APROVADO',
        atorUid: contexto.uid,
        atorNome: coordenadorNome,
        papel: autoridade.papel,
        confirmouReuniaoPastores: entrada.confirmouReuniaoPastores,
        vigenciaInicio: vigenciaInicioTs,
        vigenciaFim: vigenciaFimTs,
        observacao: entrada.observacao ?? null,
        criadoEm: agoraTs,
      });
    } else {
      // DESFAVORAVEL
      novoEstadoCiclo = 'REJEITADO';
      proximaAcao = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;

      tx.update(cicloRef, {
        estado: novoEstadoCiclo,
        versao: novaVersaoCiclo,
        justificativaInterna: entrada.justificativa,
        decisaoCoordenador: {
          decisao: 'DESFAVORAVEL',
          coordenadorUid: contexto.uid,
          coordenadorNome,
          papel: autoridade.papel,
          justificativa: entrada.justificativa,
          decididoEm: agoraTs,
        },
        atualizadoEm: agoraTs,
      });

      tx.update(partRef, {
        intencaoRenovacao: 'NAO_CONTINUAR',
        programadoEncerramentoEm: partData.vigenciaFim ?? null,
        proximaAcao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
        versao: versaoPart + 1,
        atualizadoEm: agoraTs,
      });

      // Evidência imutável
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        correlationId: contexto.correlationId ?? contexto.commandId,
        tipo: 'CONCLUSAO_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        fichaId,
        etapa: 'COORDENADOR_GERAL',
        decisao: 'DESFAVORAVEL',
        atorUid: contexto.uid,
        atorNome: coordenadorNome,
        papel: autoridade.papel,
        justificativa: entrada.justificativa,
        criadoEm: agoraTs,
      });
    }

    // Evento append-only na Ficha
    if (fichaId) {
      const eventoRef = db
        .collection('fichas')
        .doc(fichaId)
        .collection('eventos')
        .doc(contexto.commandId);

      tx.set(eventoRef, {
        commandId: contexto.commandId,
        tipo: 'CONCLUSAO_COORDENADOR_CICLO_ANUAL',
        cicloId: entrada.cicloId,
        participacaoId,
        equipeId: cicloData.equipeId,
        decisao: entrada.decisao,
        data: agoraTs,
      });
    }

    // Auditoria append-only (sem PII)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      atorUid: contexto.uid,
      acao: 'CONCLUSAO_COORDENADOR_CICLO_ANUAL',
      entidade: 'ciclos',
      entidadeId: entrada.cicloId,
      payloadHash: entrada.payloadHash,
      criadoEm: agoraTs,
      processado: false,
    });

    const resultado: ResultadoConcluirCicloAnualCoordenador = {
      sucesso: true,
      repetido: false,
      cicloId: entrada.cicloId,
      participacaoId,
      decisao: entrada.decisao,
      estadoCiclo: novoEstadoCiclo,
      vigenciaInicio: vigenciaInicioIso,
      vigenciaFim: vigenciaFimIso,
      proximaAcao,
      decididoEm: agoraIso,
    };

    // Recibo idempotente
    tx.set(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.uid,
      acao: 'CONCLUIR_CICLO_ANUAL_COORDENADOR',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado,
      criadoEm: agoraTs,
    });

    return resultado;
  });
}

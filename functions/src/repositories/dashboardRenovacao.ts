import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  EntradaConsultarDashboardRenovacao,
  EscopoOpcaoFiltro,
  EstadoRenovacaoPastor,
  EstadoRenovacaoResponsavel,
  ItemRenovacaoCoordenador,
  ItemRenovacaoPastor,
  ItemRenovacaoResponsavel,
  ItemRenovacaoVoluntario,
  MetricasRenovacaoCoordenador,
  MetricasRenovacaoPastor,
  MetricasRenovacaoResponsavel,
  MetricasRenovacaoVoluntario,
  PapelDashboard,
  ParametroInvalidoDashboardError,
  PermissaoNegadaDashboardError,
  ResultadoDashboardRenovacao,
} from '../domain/dashboardRenovacao.js';
import { classificarVigencia } from '../domain/vigencia.js';
import { avaliarAutoridadeCoordenador } from './decisaoCoordenador.js';

function serializarTimestamp(valor: unknown): string | null {
  if (!valor) return null;
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof valor === 'string') return valor;
  return null;
}

function chunkArray<T>(itens: T[], tamanho: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < itens.length; i += tamanho) {
    chunks.push(itens.slice(i, i + tamanho));
  }
  return chunks;
}

export async function obterDashboardRenovacaoRepo(
  db: Firestore,
  atorUid: string,
  entrada: EntradaConsultarDashboardRenovacao,
): Promise<ResultadoDashboardRenovacao> {
  // 1. Detectar permissões e escopos potenciais do ator
  let ehAdminOuCoordenador = false;
  const autoridadeDoc = await db.collection('autoridadesAdministrativas').doc(atorUid).get();
  if (autoridadeDoc.exists) {
    const authData = autoridadeDoc.data();
    const avaliacao = avaliarAutoridadeCoordenador(authData, 'Usuario');
    if (avaliacao.autorizado) {
      ehAdminOuCoordenador = true;
    }
  }

  // Buscar igrejas sob pastoreio ativo
  const igrejasPastorMap = new Map<string, EscopoOpcaoFiltro>();
  const igrejasPastorDirectSnap = await db
    .collection('igrejas')
    .where('pastorLocalVigentePessoaId', '==', atorUid)
    .get();
  for (const doc of igrejasPastorDirectSnap.docs) {
    const d = doc.data() ?? {};
    if (d.ativo !== false) {
      igrejasPastorMap.set(doc.id, {
        id: doc.id,
        nome: String(d.nome ?? doc.id),
        codigo: d.codigo ? String(d.codigo) : undefined,
      });
    }
  }

  const vinculosPastorSnap = await db
    .collection('vinculosPastorIgreja')
    .where('pessoaId', '==', atorUid)
    .where('estado', '==', 'VIGENTE')
    .get();
  for (const doc of vinculosPastorSnap.docs) {
    const v = doc.data() ?? {};
    const igId = String(v.entidadeId ?? '');
    if (igId && !igrejasPastorMap.has(igId)) {
      const igDoc = await db.collection('igrejas').doc(igId).get();
      if (igDoc.exists && igDoc.data()?.ativo !== false) {
        const d = igDoc.data() ?? {};
        igrejasPastorMap.set(igId, {
          id: igId,
          nome: String(d.nome ?? igId),
          codigo: d.codigo ? String(d.codigo) : undefined,
        });
      }
    }
  }

  // Buscar equipes sob responsabilidade ativa
  const equipesRespMap = new Map<string, EscopoOpcaoFiltro>();
  const equipesRespDirectSnap = await db
    .collection('equipes')
    .where('responsavelVigentePessoaId', '==', atorUid)
    .get();
  for (const doc of equipesRespDirectSnap.docs) {
    const d = doc.data() ?? {};
    if (d.ativo !== false) {
      equipesRespMap.set(doc.id, {
        id: doc.id,
        nome: String(d.nome ?? doc.id),
      });
    }
  }

  const vinculosRespSnap = await db
    .collection('vinculosResponsavelEquipe')
    .where('pessoaId', '==', atorUid)
    .where('estado', '==', 'VIGENTE')
    .get();
  for (const doc of vinculosRespSnap.docs) {
    const v = doc.data() ?? {};
    const eqId = String(v.entidadeId ?? '');
    if (eqId && !equipesRespMap.has(eqId)) {
      const eqDoc = await db.collection('equipes').doc(eqId).get();
      if (eqDoc.exists && eqDoc.data()?.ativo !== false) {
        const d = eqDoc.data() ?? {};
        equipesRespMap.set(eqId, {
          id: eqId,
          nome: String(d.nome ?? eqId),
        });
      }
    }
  }

  // 2. Resolver o papel a ser atendido nesta requisição
  let papel: PapelDashboard;
  if (entrada.papelDesejado) {
    if (
      (entrada.papelDesejado === 'COORDENADOR' || entrada.papelDesejado === 'ADMINISTRADOR') &&
      !ehAdminOuCoordenador
    ) {
      throw new PermissaoNegadaDashboardError('Usuário não possui autoridade de coordenação ou administração.');
    }
    papel = entrada.papelDesejado;
  } else {
    if (ehAdminOuCoordenador) {
      papel = 'COORDENADOR';
    } else if (igrejasPastorMap.size > 0) {
      papel = 'PASTOR_LOCAL';
    } else if (equipesRespMap.size > 0) {
      papel = 'RESPONSAVEL_EQUIPE';
    } else {
      papel = 'VOLUNTARIO';
    }
  }

  const agora = new Date();

  // Mapas globais em memória para resolução rápida de nomes de igrejas e equipes
  const obterInfoIgreja = async (igrejaId: string): Promise<string> => {
    if (!igrejaId) return 'Não informada';
    if (igrejasPastorMap.has(igrejaId)) return igrejasPastorMap.get(igrejaId)!.nome;
    const doc = await db.collection('igrejas').doc(igrejaId).get();
    return doc.exists ? String(doc.data()?.nome ?? igrejaId) : igrejaId;
  };

  const obterInfoEquipe = async (equipeId: string): Promise<string> => {
    if (!equipeId) return 'Não informada';
    if (equipesRespMap.has(equipeId)) return equipesRespMap.get(equipeId)!.nome;
    const doc = await db.collection('equipes').doc(equipeId).get();
    return doc.exists ? String(doc.data()?.nome ?? equipeId) : equipeId;
  };

  // =========================================================================
  // CASO 1: VOLUNTÁRIO
  // =========================================================================
  if (papel === 'VOLUNTARIO') {
    const partsSnap = await db
      .collection('participacoes')
      .where('fichaId', '==', atorUid)
      .get();

    let totalAtivas = 0;
    let emJanela = 0;
    let pendentesManifestacao = 0;
    let emTramitacao = 0;
    let expiradas = 0;

    const itens: ItemRenovacaoVoluntario[] = [];

    for (const doc of partsSnap.docs) {
      const part = doc.data() ?? {};
      const estadoPart = String(part.estado ?? '');
      const eqId = String(part.equipeId ?? '');
      const eqNome = await obterInfoEquipe(eqId);
      const vigInicio = serializarTimestamp(part.vigenciaInicio);
      const vigFim = serializarTimestamp(part.vigenciaFim);
      const anoVig = part.anoVigencia ? Number(part.anoVigencia) : null;

      const alerta = classificarVigencia(agora, vigFim);
      const ehAtiva = estadoPart === 'ATIVA';
      const ehExpirada = estadoPart === 'EXPIRADA' || alerta.situacao === 'EXPIRADA';

      if (ehAtiva) totalAtivas++;
      if (ehExpirada) expiradas++;

      // Buscar ciclo anual atual se houver
      let cicloId: string | null = part.cicloAtualId ? String(part.cicloAtualId) : null;
      let anoCiclo: number | null = null;
      let estadoCiclo: string | null = null;

      if (cicloId) {
        const cDoc = await db.collection('ciclos').doc(cicloId).get();
        if (cDoc.exists) {
          const cData = cDoc.data() ?? {};
          anoCiclo = cData.ano ? Number(cData.ano) : null;
          estadoCiclo = cData.estado ? String(cData.estado) : null;
        }
      } else {
        // Tenta localizar ciclo recente da participação
        const cSnap = await db
          .collection('ciclos')
          .where('participacaoId', '==', doc.id)
          .where('tipo', '==', 'RENOVACAO_ANUAL')
          .limit(1)
          .get();
        if (!cSnap.empty) {
          const cDoc = cSnap.docs[0];
          const cData = cDoc.data() ?? {};
          cicloId = cDoc.id;
          anoCiclo = cData.ano ? Number(cData.ano) : null;
          estadoCiclo = cData.estado ? String(cData.estado) : null;
        }
      }

      const emJanelaRenovacao = ehAtiva && alerta.janelaRenovacaoAberta;
      if (emJanelaRenovacao) emJanela++;

      const cicloAberto =
        estadoCiclo &&
        ['AGUARDANDO_PASTOR_LOCAL', 'AGUARDANDO_RESPONSAVEL_EQUIPE', 'AGUARDANDO_COORDENADOR'].includes(
          estadoCiclo,
        );

      if (cicloAberto) emTramitacao++;

      const podeManifestar = emJanelaRenovacao && !cicloAberto;
      if (podeManifestar) pendentesManifestacao++;

      itens.push({
        participacaoId: doc.id,
        equipeId: eqId,
        equipeNome: eqNome,
        estadoParticipacao: estadoPart,
        vigenciaInicio: vigInicio,
        vigenciaFim: vigFim,
        anoVigencia: anoVig,
        situacaoVigencia: alerta.situacao,
        diasRestantes: alerta.diasRestantes,
        emJanelaRenovacao,
        podeManifestar,
        cicloId,
        anoCiclo,
        estadoCiclo,
      });
    }

    // Ordenar itens: menor prazo de vencimento primeiro
    itens.sort((a, b) => {
      const dA = a.diasRestantes ?? 9999;
      const dB = b.diasRestantes ?? 9999;
      return dA - dB;
    });

    const metricas: MetricasRenovacaoVoluntario = {
      totalParticipacoesAtivas: totalAtivas,
      emJanelaRenovacao: emJanela,
      pendentesManifestacao,
      emTramitacao,
      expiradas,
    };

    return {
      papelResolvido: 'VOLUNTARIO',
      metricas,
      itens,
      totalItens: itens.length,
      pagina: 1,
      totalPaginas: 1,
    };
  }

  // =========================================================================
  // CASO 2: PASTOR LOCAL
  // =========================================================================
  if (papel === 'PASTOR_LOCAL') {
    const igrejasNoEscopo = Array.from(igrejasPastorMap.values()).sort((a, b) =>
      a.nome.localeCompare(b.nome, 'pt-BR'),
    );

    if (igrejasNoEscopo.length === 0) {
      const metricasVazias: MetricasRenovacaoPastor = {
        pendentesParecer: 0,
        semManifestacao: 0,
        proximasVencimento: 0,
        expiradas: 0,
        totalSobEscopo: 0,
      };
      return {
        papelResolvido: 'PASTOR_LOCAL',
        metricas: metricasVazias,
        itens: [],
        totalItens: 0,
        pagina: 1,
        totalPaginas: 1,
        igrejasEscopo: [],
      };
    }

    let igrejasAlvoIds = igrejasNoEscopo.map((i) => i.id);
    if (entrada.igrejaId) {
      if (!igrejasPastorMap.has(entrada.igrejaId)) {
        throw new PermissaoNegadaDashboardError('Igreja selecionada não está sob seu pastoreio.');
      }
      igrejasAlvoIds = [entrada.igrejaId];
    }

    // Buscar voluntários (fichas) dessas igrejas
    const fichasMap = new Map<string, { nome: string; igrejaId: string; igrejaNome: string }>();
    const chunksIgrejas = chunkArray(igrejasAlvoIds, 30);
    for (const chunk of chunksIgrejas) {
      const fSnap = await db.collection('fichas').where('igrejaId', 'in', chunk).get();
      for (const fDoc of fSnap.docs) {
        const d = fDoc.data() ?? {};
        const igId = String(d.igrejaId ?? '');
        const igNome = igrejasPastorMap.get(igId)?.nome ?? (await obterInfoIgreja(igId));
        fichasMap.set(fDoc.id, {
          nome: String(d.nomeCompleto ?? d.nome ?? 'Voluntário'),
          igrejaId: igId,
          igrejaNome: igNome,
        });
      }
    }

    const fichaIds = Array.from(fichasMap.keys());
    let pendentesParecer = 0;
    let semManifestacao = 0;
    let proximasVencimento = 0;
    let expiradas = 0;
    let totalSobEscopo = 0;

    const itensTodos: ItemRenovacaoPastor[] = [];

    if (fichaIds.length > 0) {
      const chunksFichas = chunkArray(fichaIds, 30);
      for (const chunk of chunksFichas) {
        const partsSnap = await db
          .collection('participacoes')
          .where('fichaId', 'in', chunk)
          .get();

        for (const pDoc of partsSnap.docs) {
          const part = pDoc.data() ?? {};
          const fId = String(part.fichaId ?? '');
          const infoFicha = fichasMap.get(fId);
          if (!infoFicha) continue;

          const estadoPart = String(part.estado ?? '');
          if (!['ATIVA', 'EXPIRADA'].includes(estadoPart)) continue;

          const eqId = String(part.equipeId ?? '');
          const eqNome = await obterInfoEquipe(eqId);
          const vigFim = serializarTimestamp(part.vigenciaFim);
          const alerta = classificarVigencia(agora, vigFim);

          if (estadoPart === 'ATIVA') totalSobEscopo++;

          // Buscar ciclo atual
          let cicloId: string | null = part.cicloAtualId ? String(part.cicloAtualId) : null;
          let estadoCiclo: string | null = null;
          if (cicloId) {
            const cDoc = await db.collection('ciclos').doc(cicloId).get();
            if (cDoc.exists) {
              estadoCiclo = String(cDoc.data()?.estado ?? '');
            }
          } else {
            const cSnap = await db
              .collection('ciclos')
              .where('participacaoId', '==', pDoc.id)
              .where('tipo', '==', 'RENOVACAO_ANUAL')
              .limit(1)
              .get();
            if (!cSnap.empty) {
              cicloId = cSnap.docs[0].id;
              estadoCiclo = String(cSnap.docs[0].data()?.estado ?? '');
            }
          }

          let estadoRenovacao: EstadoRenovacaoPastor = 'OUTRO';

          if (estadoCiclo === 'AGUARDANDO_PASTOR_LOCAL') {
            estadoRenovacao = 'PENDENTE_PASTOR';
            pendentesParecer++;
          } else if (estadoPart === 'ATIVA' && alerta.janelaRenovacaoAberta && !estadoCiclo) {
            estadoRenovacao = 'SEM_MANIFESTACAO';
            semManifestacao++;
          } else if (alerta.situacao === 'RENOVACAO_IMINENTE_30D' && estadoPart === 'ATIVA') {
            estadoRenovacao = 'PROXIMO_VENCIMENTO';
            proximasVencimento++;
          } else if (alerta.situacao === 'EXPIRADA' || estadoPart === 'EXPIRADA') {
            estadoRenovacao = 'EXPIRADA';
            expiradas++;
          }

          itensTodos.push({
            participacaoId: pDoc.id,
            fichaId: fId,
            voluntarioNome: infoFicha.nome,
            igrejaId: infoFicha.igrejaId,
            igrejaNome: infoFicha.igrejaNome,
            equipeId: eqId,
            equipeNome: eqNome,
            vigenciaFim: vigFim,
            diasRestantes: alerta.diasRestantes,
            situacaoVigencia: alerta.situacao,
            cicloId,
            estadoCiclo,
            estadoRenovacao,
          });
        }
      }
    }

    // Filtrar se houver filtro de estado
    let itensFiltrados = itensTodos;
    if (entrada.estadoRenovacao) {
      itensFiltrados = itensTodos.filter(
        (it) => it.estadoRenovacao === entrada.estadoRenovacao,
      );
    }

    // Ordenar itens: pendentes pastor primeiro, depois próximos do vencimento
    itensFiltrados.sort((a, b) => {
      if (a.estadoRenovacao === 'PENDENTE_PASTOR' && b.estadoRenovacao !== 'PENDENTE_PASTOR') return -1;
      if (a.estadoRenovacao !== 'PENDENTE_PASTOR' && b.estadoRenovacao === 'PENDENTE_PASTOR') return 1;
      const dA = a.diasRestantes ?? 9999;
      const dB = b.diasRestantes ?? 9999;
      return dA - dB;
    });

    const limite = entrada.limite ?? 20;
    const pagina = entrada.pagina ?? 1;
    const totalItens = itensFiltrados.length;
    const totalPaginas = Math.ceil(totalItens / limite) || 1;
    const offset = (pagina - 1) * limite;
    const itensPaginados = itensFiltrados.slice(offset, offset + limite);

    const metricas: MetricasRenovacaoPastor = {
      pendentesParecer,
      semManifestacao,
      proximasVencimento,
      expiradas,
      totalSobEscopo,
    };

    return {
      papelResolvido: 'PASTOR_LOCAL',
      metricas,
      itens: itensPaginados,
      totalItens,
      pagina,
      totalPaginas,
      igrejasEscopo: igrejasNoEscopo,
    };
  }

  // =========================================================================
  // CASO 3: RESPONSÁVEL DE EQUIPE
  // =========================================================================
  if (papel === 'RESPONSAVEL_EQUIPE') {
    const equipesNoEscopo = Array.from(equipesRespMap.values()).sort((a, b) =>
      a.nome.localeCompare(b.nome, 'pt-BR'),
    );

    if (equipesNoEscopo.length === 0) {
      const metricasVazias: MetricasRenovacaoResponsavel = {
        pendentesEquipe: 0,
        emTramitacao: 0,
        semManifestacao: 0,
        expiradas: 0,
        totalEquipe: 0,
      };
      return {
        papelResolvido: 'RESPONSAVEL_EQUIPE',
        metricas: metricasVazias,
        itens: [],
        totalItens: 0,
        pagina: 1,
        totalPaginas: 1,
        equipesEscopo: [],
      };
    }

    let equipesAlvoIds = equipesNoEscopo.map((e) => e.id);
    if (entrada.equipeId) {
      if (!equipesRespMap.has(entrada.equipeId)) {
        throw new PermissaoNegadaDashboardError('Equipe selecionada não está sob sua responsabilidade.');
      }
      equipesAlvoIds = [entrada.equipeId];
    }

    let pendentesEquipe = 0;
    let emTramitacao = 0;
    let semManifestacao = 0;
    let expiradas = 0;
    let totalEquipe = 0;

    const itensTodos: ItemRenovacaoResponsavel[] = [];

    const chunksEquipes = chunkArray(equipesAlvoIds, 30);
    for (const chunk of chunksEquipes) {
      const partsSnap = await db
        .collection('participacoes')
        .where('equipeId', 'in', chunk)
        .get();

      for (const pDoc of partsSnap.docs) {
        const part = pDoc.data() ?? {};
        const estadoPart = String(part.estado ?? '');
        if (!['ATIVA', 'EXPIRADA'].includes(estadoPart)) continue;

        const eqId = String(part.equipeId ?? '');
        const eqNome = equipesRespMap.get(eqId)?.nome ?? (await obterInfoEquipe(eqId));
        const fId = String(part.fichaId ?? '');

        // Buscar nome do voluntário e igreja da ficha
        let volNome = 'Voluntário';
        let igId = '';
        let igNome = 'Não informada';
        if (fId) {
          const fDoc = await db.collection('fichas').doc(fId).get();
          if (fDoc.exists) {
            const fData = fDoc.data() ?? {};
            volNome = String(fData.nomeCompleto ?? fData.nome ?? 'Voluntário');
            igId = String(fData.igrejaId ?? '');
            igNome = await obterInfoIgreja(igId);
          }
        }

        const vigFim = serializarTimestamp(part.vigenciaFim);
        const alerta = classificarVigencia(agora, vigFim);

        if (estadoPart === 'ATIVA') totalEquipe++;

        // Buscar ciclo
        let cicloId: string | null = part.cicloAtualId ? String(part.cicloAtualId) : null;
        let estadoCiclo: string | null = null;
        if (cicloId) {
          const cDoc = await db.collection('ciclos').doc(cicloId).get();
          if (cDoc.exists) {
            estadoCiclo = String(cDoc.data()?.estado ?? '');
          }
        } else {
          const cSnap = await db
            .collection('ciclos')
            .where('participacaoId', '==', pDoc.id)
            .where('tipo', '==', 'RENOVACAO_ANUAL')
            .limit(1)
            .get();
          if (!cSnap.empty) {
            cicloId = cSnap.docs[0].id;
            estadoCiclo = String(cSnap.docs[0].data()?.estado ?? '');
          }
        }

        let estadoRenovacao: EstadoRenovacaoResponsavel = 'OUTRO';

        if (estadoCiclo === 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
          estadoRenovacao = 'PENDENTE_EQUIPE';
          pendentesEquipe++;
        } else if (
          estadoCiclo &&
          ['AGUARDANDO_PASTOR_LOCAL', 'AGUARDANDO_COORDENADOR'].includes(estadoCiclo)
        ) {
          estadoRenovacao = 'EM_TRAMITACAO';
          emTramitacao++;
        } else if (estadoPart === 'ATIVA' && alerta.janelaRenovacaoAberta && !estadoCiclo) {
          estadoRenovacao = 'SEM_MANIFESTACAO';
          semManifestacao++;
        } else if (alerta.situacao === 'EXPIRADA' || estadoPart === 'EXPIRADA') {
          estadoRenovacao = 'EXPIRADA';
          expiradas++;
        }

        itensTodos.push({
          participacaoId: pDoc.id,
          fichaId: fId,
          voluntarioNome: volNome,
          igrejaId: igId,
          igrejaNome: igNome,
          equipeId: eqId,
          equipeNome: eqNome,
          vigenciaFim: vigFim,
          diasRestantes: alerta.diasRestantes,
          situacaoVigencia: alerta.situacao,
          cicloId,
          estadoCiclo,
          estadoRenovacao,
        });
      }
    }

    let itensFiltrados = itensTodos;
    if (entrada.estadoRenovacao) {
      itensFiltrados = itensTodos.filter(
        (it) => it.estadoRenovacao === entrada.estadoRenovacao,
      );
    }

    itensFiltrados.sort((a, b) => {
      if (a.estadoRenovacao === 'PENDENTE_EQUIPE' && b.estadoRenovacao !== 'PENDENTE_EQUIPE') return -1;
      if (a.estadoRenovacao !== 'PENDENTE_EQUIPE' && b.estadoRenovacao === 'PENDENTE_EQUIPE') return 1;
      const dA = a.diasRestantes ?? 9999;
      const dB = b.diasRestantes ?? 9999;
      return dA - dB;
    });

    const limite = entrada.limite ?? 20;
    const pagina = entrada.pagina ?? 1;
    const totalItens = itensFiltrados.length;
    const totalPaginas = Math.ceil(totalItens / limite) || 1;
    const offset = (pagina - 1) * limite;
    const itensPaginados = itensFiltrados.slice(offset, offset + limite);

    const metricas: MetricasRenovacaoResponsavel = {
      pendentesEquipe,
      emTramitacao,
      semManifestacao,
      expiradas,
      totalEquipe,
    };

    return {
      papelResolvido: 'RESPONSAVEL_EQUIPE',
      metricas,
      itens: itensPaginados,
      totalItens,
      pagina,
      totalPaginas,
      equipesEscopo: equipesNoEscopo,
    };
  }

  // =========================================================================
  // CASO 4: COORDENADOR GERAL / ADMINISTRADOR
  // =========================================================================
  if (papel === 'COORDENADOR' || papel === 'ADMINISTRADOR') {
    // Listar opções de filtros (todas igrejas e equipes ativas)
    const todasIgrejasSnap = await db.collection('igrejas').get();
    const todasIgrejas: EscopoOpcaoFiltro[] = [];
    for (const d of todasIgrejasSnap.docs) {
      const data = d.data() ?? {};
      if (data.ativo !== false) {
        todasIgrejas.push({
          id: d.id,
          nome: String(data.nome ?? d.id),
          codigo: data.codigo ? String(data.codigo) : undefined,
        });
      }
    }
    todasIgrejas.sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'));

    const todasEquipesSnap = await db.collection('equipes').get();
    const todasEquipes: EscopoOpcaoFiltro[] = [];
    for (const d of todasEquipesSnap.docs) {
      const data = d.data() ?? {};
      if (data.ativo !== false) {
        todasEquipes.push({
          id: d.id,
          nome: String(data.nome ?? d.id),
        });
      }
    }
    todasEquipes.sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'));

    // Consultar participações (com filtro opcional por equipe se informado)
    let partsQuery: FirebaseFirestore.Query = db.collection('participacoes');
    if (entrada.equipeId) {
      partsQuery = partsQuery.where('equipeId', '==', entrada.equipeId);
    }
    if (entrada.anoVigencia) {
      partsQuery = partsQuery.where('anoVigencia', '==', entrada.anoVigencia);
    }

    const partsSnap = await partsQuery.get();

    // Cache local de fichas
    const fichasLocalMap = new Map<string, { nome: string; igrejaId: string; igrejaNome: string }>();

    let totalAtivos = 0;
    let emJanelaRenovacao = 0;
    let pendentesPastorLocal = 0;
    let pendentesResponsaveis = 0;
    let aguardandoCoordenador = 0;
    let renovadosConcluidos = 0;
    let expirados = 0;

    const itensTodos: ItemRenovacaoCoordenador[] = [];

    for (const pDoc of partsSnap.docs) {
      const part = pDoc.data() ?? {};
      const estadoPart = String(part.estado ?? '');
      if (!['ATIVA', 'EXPIRADA'].includes(estadoPart)) continue;

      const fId = String(part.fichaId ?? '');
      if (!fId) continue;

      if (!fichasLocalMap.has(fId)) {
        const fDoc = await db.collection('fichas').doc(fId).get();
        if (fDoc.exists) {
          const fData = fDoc.data() ?? {};
          const igId = String(fData.igrejaId ?? '');
          const igNome = await obterInfoIgreja(igId);
          fichasLocalMap.set(fId, {
            nome: String(fData.nomeCompleto ?? fData.nome ?? 'Voluntário'),
            igrejaId: igId,
            igrejaNome: igNome,
          });
        } else {
          fichasLocalMap.set(fId, {
            nome: 'Voluntário',
            igrejaId: '',
            igrejaNome: 'Não informada',
          });
        }
      }

      const infoFicha = fichasLocalMap.get(fId)!;

      // Se filtrou por igrejaId, descartar fichas fora da igreja
      if (entrada.igrejaId && infoFicha.igrejaId !== entrada.igrejaId) {
        continue;
      }

      const eqId = String(part.equipeId ?? '');
      const eqNome = await obterInfoEquipe(eqId);
      const vigFim = serializarTimestamp(part.vigenciaFim);
      const anoVig = part.anoVigencia ? Number(part.anoVigencia) : null;
      const alerta = classificarVigencia(agora, vigFim);

      if (estadoPart === 'ATIVA') totalAtivos++;
      if (alerta.janelaRenovacaoAberta && estadoPart === 'ATIVA') emJanelaRenovacao++;
      if (estadoPart === 'EXPIRADA' || alerta.situacao === 'EXPIRADA') expirados++;

      // Buscar ciclo atual
      let cicloId: string | null = part.cicloAtualId ? String(part.cicloAtualId) : null;
      let estadoCiclo: string | null = null;
      if (cicloId) {
        const cDoc = await db.collection('ciclos').doc(cicloId).get();
        if (cDoc.exists) {
          estadoCiclo = String(cDoc.data()?.estado ?? '');
        }
      } else {
        const cSnap = await db
          .collection('ciclos')
          .where('participacaoId', '==', pDoc.id)
          .where('tipo', '==', 'RENOVACAO_ANUAL')
          .limit(1)
          .get();
        if (!cSnap.empty) {
          cicloId = cSnap.docs[0].id;
          estadoCiclo = String(cSnap.docs[0].data()?.estado ?? '');
        }
      }

      let estadoRenovacao = 'EM_DIA';
      if (estadoCiclo === 'AGUARDANDO_PASTOR_LOCAL') {
        estadoRenovacao = 'AGUARDANDO_PASTOR_LOCAL';
        pendentesPastorLocal++;
      } else if (estadoCiclo === 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
        estadoRenovacao = 'AGUARDANDO_RESPONSAVEL_EQUIPE';
        pendentesResponsaveis++;
      } else if (estadoCiclo === 'AGUARDANDO_COORDENADOR') {
        estadoRenovacao = 'AGUARDANDO_COORDENADOR';
        aguardandoCoordenador++;
      } else if (estadoCiclo === 'CONCLUIDO') {
        estadoRenovacao = 'RENOVADO_CONCLUIDO';
        renovadosConcluidos++;
      } else if (alerta.janelaRenovacaoAberta && !estadoCiclo) {
        estadoRenovacao = 'SEM_MANIFESTACAO';
      } else if (alerta.situacao === 'EXPIRADA' || estadoPart === 'EXPIRADA') {
        estadoRenovacao = 'EXPIRADA';
      }

      itensTodos.push({
        participacaoId: pDoc.id,
        fichaId: fId,
        voluntarioNome: infoFicha.nome,
        igrejaId: infoFicha.igrejaId,
        igrejaNome: infoFicha.igrejaNome,
        equipeId: eqId,
        equipeNome: eqNome,
        vigenciaFim: vigFim,
        diasRestantes: alerta.diasRestantes,
        situacaoVigencia: alerta.situacao,
        cicloId,
        estadoCiclo,
        anoVigencia: anoVig,
        estadoRenovacao,
      });
    }

    let itensFiltrados = itensTodos;
    if (entrada.estadoRenovacao) {
      itensFiltrados = itensTodos.filter(
        (it) => it.estadoRenovacao === entrada.estadoRenovacao,
      );
    }

    // Ordenação: Pendentes de coordenação primeiro, depois outros ciclos abertos, depois dias restantes
    itensFiltrados.sort((a, b) => {
      const prioridade = (st: string) => {
        if (st === 'AGUARDANDO_COORDENADOR') return 1;
        if (st === 'AGUARDANDO_RESPONSAVEL_EQUIPE') return 2;
        if (st === 'AGUARDANDO_PASTOR_LOCAL') return 3;
        if (st === 'SEM_MANIFESTACAO') return 4;
        if (st === 'EXPIRADA') return 5;
        return 6;
      };
      const pA = prioridade(a.estadoRenovacao);
      const pB = prioridade(b.estadoRenovacao);
      if (pA !== pB) return pA - pB;
      const dA = a.diasRestantes ?? 9999;
      const dB = b.diasRestantes ?? 9999;
      return dA - dB;
    });

    const limite = entrada.limite ?? 20;
    const pagina = entrada.pagina ?? 1;
    const totalItens = itensFiltrados.length;
    const totalPaginas = Math.ceil(totalItens / limite) || 1;
    const offset = (pagina - 1) * limite;
    const itensPaginados = itensFiltrados.slice(offset, offset + limite);

    const metricas: MetricasRenovacaoCoordenador = {
      totalAtivos,
      emJanelaRenovacao,
      pendentesPastorLocal,
      pendentesResponsaveis,
      aguardandoCoordenador,
      renovadosConcluidos,
      expirados,
    };

    return {
      papelResolvido: papel,
      metricas,
      itens: itensPaginados,
      totalItens,
      pagina,
      totalPaginas,
      igrejasEscopo: todasIgrejas,
      equipesEscopo: todasEquipes,
    };
  }

  throw new ParametroInvalidoDashboardError('Papel não suportado.');
}

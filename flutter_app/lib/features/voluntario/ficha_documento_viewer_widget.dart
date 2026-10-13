import 'package:flutter/material.dart';

import '../../ui/components/logo_maanaim.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import 'ficha_service.dart';
import 'participacao_service.dart';

/// Widget nobre e responsivo de visualização e emissão do documento probatório
/// do voluntário (S09 — Minha Ficha), fiel à imagem de referência normativa
/// (maanaim-ui-reference.png, tela inferior direita).
class FichaDocumentoViewerWidget extends StatefulWidget {
  const FichaDocumentoViewerWidget({
    super.key,
    required this.ficha,
    required this.participacoes,
    this.participacaoSelecionada,
    this.nomeIgreja,
    this.codigoIgreja,
    this.emailVoluntario,
    this.termoVersao,
    this.aceiteEm,
    this.onBaixarPdf,
    this.isBaixandoPdf = false,
    this.onBaixarTermoPdf,
    this.baixandoParticipacaoId,
    this.onSelecionarParticipacao,
    this.exibirToolbar = true,
  });

  final FichaModel? ficha;
  final List<ParticipacaoModel> participacoes;
  final ParticipacaoModel? participacaoSelecionada;
  final String? nomeIgreja;
  final String? codigoIgreja;
  final String? emailVoluntario;
  final String? termoVersao;
  final String? aceiteEm;
  final VoidCallback? onBaixarPdf;
  final bool isBaixandoPdf;
  final void Function(ParticipacaoModel participacao)? onBaixarTermoPdf;
  final String? baixandoParticipacaoId;
  final ValueChanged<ParticipacaoModel>? onSelecionarParticipacao;
  final bool exibirToolbar;

  @override
  State<FichaDocumentoViewerWidget> createState() =>
      _FichaDocumentoViewerWidgetState();
}

class _FichaDocumentoViewerWidgetState
    extends State<FichaDocumentoViewerWidget> {
  double _zoom = 1.0;

  void _ajustarZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.7, 1.4);
    });
  }

  void _resetarZoom() {
    setState(() {
      _zoom = 1.0;
    });
  }

  String _formatarData(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dataIso).toLocal();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year.toString();
      return '$dia/$mes/$ano';
    } catch (_) {
      return dataIso;
    }
  }

  String _formatarDataHora(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dataIso).toLocal();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year.toString();
      final hora = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$ano às $hora:$min';
    } catch (_) {
      return dataIso;
    }
  }

  String? _identificadorDocumentoPersistido(FichaModel? ficha) {
    if (ficha == null) return null;
    final id = ficha.id.trim();
    if (id.startsWith('FV-')) return id;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ficha = widget.ficha;
    final idDocumento = _identificadorDocumentoPersistido(ficha);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        return Container(
          key: const Key('moldura_documento_viewer'),
          decoration: BoxDecoration(
            color: const Color(
              0xFF283344,
            ), // Fundo escuro/neutro institucional (referência S09)
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: const Color(0xFF3B485C)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de ferramentas / controles do documento (se habilitada)
              if (widget.exibirToolbar) _buildToolbar(isMobile),

              // Área da folha do documento
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? AppSpacing.s12 : AppSpacing.s24,
                  vertical: isMobile ? AppSpacing.s16 : AppSpacing.s24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Transform.scale(
                      scale: isMobile ? 1.0 : _zoom,
                      alignment: Alignment.topCenter,
                      child: _buildFolhaDocumento(ficha, idDocumento, isMobile),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(bool isMobile) {
    return Container(
      key: const Key('toolbar_documento_viewer'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2633),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppGeometry.radiusCard),
          topRight: Radius.circular(AppGeometry.radiusCard),
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s12,
        runSpacing: AppSpacing.s8,
        children: [
          // Indicador de página
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.description_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s8),
              const Text(
                '1 / 2',
                key: Key('indicador_pagina_viewer'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Controles de zoom (em desktop/tablet)
          if (!isMobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('btn_doc_zoom_out'),
                  tooltip: 'Diminuir zoom',
                  icon: const Icon(
                    Icons.remove,
                    size: 16,
                    color: Colors.white70,
                  ),
                  onPressed: () => _ajustarZoom(-0.25),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF283344),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(_zoom * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('btn_doc_zoom_in'),
                  tooltip: 'Aumentar zoom',
                  icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                  onPressed: () => _ajustarZoom(0.25),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  key: const Key('btn_doc_zoom_fit'),
                  tooltip: 'Ajustar zoom',
                  icon: const Icon(
                    Icons.fit_screen_outlined,
                    size: 16,
                    color: Colors.white70,
                  ),
                  onPressed: _resetarZoom,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

          // Ações de impressão e download
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onBaixarPdf != null) ...[
                IconButton(
                  key: const Key('btn_doc_imprimir'),
                  tooltip: 'Imprimir documento',
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 18,
                    color: Colors.white70,
                  ),
                  onPressed: widget.onBaixarPdf,
                ),
                IconButton(
                  key: const Key('btn_doc_baixar'),
                  tooltip: 'Baixar PDF oficial',
                  icon: widget.isBaixandoPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.download_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                  onPressed: widget.isBaixandoPdf ? null : widget.onBaixarPdf,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolhaDocumento(
    FichaModel? ficha,
    String? idDocumento,
    bool isMobile,
  ) {
    final statusFicha = ficha?.estado ?? 'RASCUNHO';

    return Container(
      key: const Key('folha_a4_documento'),
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? AppSpacing.s16 : AppSpacing.s32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 18,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho da Folha: Logo Maanaim, Título central, ID e StatusChip
          _buildCabecalhoDocumento(idDocumento, statusFicha, isMobile),
          const SizedBox(height: AppSpacing.s24),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: AppSpacing.s20),

          // Bloco 1 — Dados do Voluntário (Composição em 2 Colunas)
          _buildBlocoDadosVoluntario(ficha, isMobile),
          const SizedBox(height: AppSpacing.s24),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: AppSpacing.s20),

          // Bloco 2 — Tabela de Equipes
          _buildBlocoEquipes(isMobile),

          const SizedBox(height: AppSpacing.s24),
          // Rodapé probatório do documento
          _buildRodapeDocumento(ficha, idDocumento),
        ],
      ),
    );
  }

  Widget _buildCabecalhoDocumento(
    String? idDocumento,
    String statusFicha,
    bool isMobile,
  ) {
    final statusWidget = statusFicha == 'REJEITADA'
        ? const SizedBox.shrink()
        : StatusChip(
            status: statusFicha,
            label: statusFicha == 'ATIVA' ? 'ATIVA' : null,
          );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [LogoMaanaim.topBar(height: 32), statusWidget],
          ),
          const SizedBox(height: AppSpacing.s12),
          const Text(
            'FICHA DE VOLUNTÁRIO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.navy900,
              letterSpacing: 1.1,
            ),
          ),
          if (idDocumento != null) ...[
            const SizedBox(height: 4),
            Text(
              idDocumento,
              key: const Key('texto_id_documento_fv'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo oficial do Maanaim à esquerda
        LogoMaanaim.topBar(height: 40),
        const SizedBox(width: AppSpacing.s16),

        // Título centralizado e Identificador persistido
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'FICHA DE VOLUNTÁRIO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy900,
                  letterSpacing: 1.2,
                ),
              ),
              if (idDocumento != null) ...[
                const SizedBox(height: 4),
                Text(
                  idDocumento,
                  key: const Key('texto_id_documento_fv'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy900,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),

        // StatusChip institucional no topo direito
        statusWidget,
      ],
    );
  }

  Widget _buildBlocoDadosVoluntario(FichaModel? ficha, bool isMobile) {
    final nome = ficha?.nomeCompleto.isNotEmpty == true
        ? ficha!.nomeCompleto
        : 'Não disponível';
    final telefone = ficha?.telefone != null && ficha!.telefone!.isNotEmpty
        ? ficha.telefone!
        : 'Não disponível';
    final email = widget.emailVoluntario?.trim().isNotEmpty == true
        ? widget.emailVoluntario!.trim()
        : 'Não disponível';

    final nomeIgreja = widget.nomeIgreja?.trim();
    final codIgreja = widget.codigoIgreja?.trim();
    final igrejaRotulo = [
      nomeIgreja,
      codIgreja,
    ].whereType<String>().where((valor) => valor.isNotEmpty).join(' - ');

    final participacao = widget.participacaoSelecionada;
    final vigencia =
        participacao?.vigenciaInicio != null &&
            participacao?.vigenciaFim != null
        ? '${_formatarData(participacao!.vigenciaInicio)} a ${_formatarData(participacao.vigenciaFim)}'
        : 'Não disponível';
    final termo = widget.termoVersao != null
        ? 'Versão ${widget.termoVersao}'
        : (ficha?.termoAceito != null
              ? 'Versão ${ficha!.termoAceito!.numeroVersao}'
              : 'Não disponível');
    final aceite = widget.aceiteEm != null
        ? _formatarDataHora(widget.aceiteEm)
        : (ficha?.termoAceito != null
              ? _formatarDataHora(ficha!.termoAceito!.aceitoEm)
              : 'Não disponível');

    final col1 = [
      _buildItemDado('Nome:', nome, isDestaque: true),
      _buildItemDado('Telefone:', telefone),
      _buildItemDado('E-mail:', email),
    ];

    final col2 = [
      _buildItemDado(
        'Igreja:',
        igrejaRotulo.isEmpty ? 'Não disponível' : igrejaRotulo,
      ),
      _buildItemDado('Vigência:', vigencia),
      _buildItemDado('Termo:', termo),
      _buildItemDado('Aceite em:', aceite),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dados do voluntário',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.navy900,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (isMobile) ...[
          ...col1,
          ...col2,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: col1,
                ),
              ),
              const SizedBox(width: AppSpacing.s24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: col2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildItemDado(
    String rotulo,
    String valor, {
    bool isDestaque = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDestaque ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.navy900,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocoEquipes(bool isMobile) {
    final participacoes = widget.participacoes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            const Text(
              'Equipes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navy900,
              ),
            ),
            if (participacoes.isNotEmpty)
              Text(
                '${participacoes.length} ${participacoes.length == 1 ? 'equipe vinculada' : 'equipes vinculadas'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        if (participacoes.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'Nenhuma equipe cadastrada nesta ficha.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          )
        else if (isMobile)
          _buildListaEquipesMobile(participacoes)
        else
          _buildTabelaEquipesDesktop(participacoes),
      ],
    );
  }

  Widget _buildTabelaEquipesDesktop(List<ParticipacaoModel> participacoes) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Cabeçalho da Tabela
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppGeometry.radiusInput),
                topRight: Radius.circular(AppGeometry.radiusInput),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Equipe',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Situação',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Aprovado por',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Início da vigência',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Linhas da Tabela
          ...participacoes.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            final isUltima = idx == participacoes.length - 1;

            final nomeEquipe = p.nomeEquipe.isNotEmpty
                ? p.nomeEquipe
                : p.equipeId;
            const aprovadoPor = 'Não disponível';
            final dataStr = p.vigenciaInicio != null
                ? _formatarData(p.vigenciaInicio)
                : 'Não disponível';

            final isNegativa = p.isRejeitada || p.estado.contains('CANCELADA');
            final statusChip = isNegativa
                ? const SizedBox.shrink()
                : StatusChip(
                    status: p.estado,
                    label: p.isAtiva
                        ? 'ATIVA'
                        : (p.isPendente ? 'EM APROVAÇÃO' : null),
                  );

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              decoration: BoxDecoration(
                color: idx.isEven ? Colors.white : const Color(0xFFFAFAFC),
                border: isUltima
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      nomeEquipe,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: statusChip,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      aprovadoPor,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      dataStr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildListaEquipesMobile(List<ParticipacaoModel> participacoes) {
    return Column(
      children: participacoes.map((p) {
        final nomeEquipe = p.nomeEquipe.isNotEmpty ? p.nomeEquipe : p.equipeId;
        const aprovadoPor = 'Não disponível';
        final dataStr = p.vigenciaInicio != null
            ? _formatarData(p.vigenciaInicio)
            : 'Não disponível';

        final isNegativa = p.isRejeitada || p.estado.contains('CANCELADA');

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nomeEquipe,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  if (isNegativa)
                    const SizedBox.shrink()
                  else
                    StatusChip(
                      status: p.estado,
                      label: p.isAtiva
                          ? 'ATIVA'
                          : (p.isPendente ? 'EM APROVAÇÃO' : null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Aprovado por: $aprovadoPor',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Início da vigência: $dataStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (p.isAtiva && widget.onBaixarTermoPdf != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    key: Key('btn_doc_termo_pdf_${p.id}'),
                    onPressed: () => widget.onBaixarTermoPdf!(p),
                    icon: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 14,
                      color: AppColors.blue600,
                    ),
                    label: const Text(
                      'Baixar Termo em PDF',
                      style: TextStyle(fontSize: 12, color: AppColors.blue600),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRodapeDocumento(FichaModel? ficha, String? idDocumento) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s4,
        children: [
          const Text(
            'MAANAIM • GESTÃO DE VOLUNTÁRIOS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            idDocumento == null
                ? 'Visualização de dados persistidos'
                : 'Visualização de dados persistidos • $idDocumento',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

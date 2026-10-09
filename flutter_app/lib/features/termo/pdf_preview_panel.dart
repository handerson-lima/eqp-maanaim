import 'package:flutter/material.dart';

import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../voluntario/participacao_service.dart';
import 'pdf_termo_service.dart';
import 'termo_pdf_launcher.dart';

/// Painel neutro e responsivo para visualização, metadados e download
/// de documento privado por participação (AD-13 / Story 8.10).
class PdfPreviewPanel extends StatefulWidget {
  const PdfPreviewPanel({
    super.key,
    required this.fichaId,
    required this.participacao,
    this.pdfTermoGateway,
    this.nomeVoluntario,
    this.onAposBaixar,
    this.alturaMinima = 380,
  });

  final String fichaId;
  final ParticipacaoModel? participacao;
  final PdfTermoGateway? pdfTermoGateway;
  final String? nomeVoluntario;
  final VoidCallback? onAposBaixar;
  final double alturaMinima;

  @override
  State<PdfPreviewPanel> createState() => _PdfPreviewPanelState();
}

class _PdfPreviewPanelState extends State<PdfPreviewPanel> {
  bool _carregando = false;
  bool _baixando = false;
  String? _erro;
  ResultadoDownloadPdfModel? _downloadModel;
  bool _urlExpirada = false;

  @override
  void initState() {
    super.initState();
    _avaliarECarregar();
  }

  @override
  void didUpdateWidget(covariant PdfPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participacao?.id != widget.participacao?.id ||
        oldWidget.fichaId != widget.fichaId) {
      _avaliarECarregar();
    }
  }

  void _avaliarECarregar() {
    final p = widget.participacao;
    if (p == null || !p.isAtiva) {
      setState(() {
        _carregando = false;
        _baixando = false;
        _erro = null;
        _downloadModel = null;
        _urlExpirada = false;
      });
      return;
    }
    _carregarUrlPdf();
  }

  Future<void> _carregarUrlPdf({bool forcarRenovacao = false}) async {
    final p = widget.participacao;
    if (p == null || widget.fichaId.isEmpty) return;

    setState(() {
      _carregando = true;
      _erro = null;
      _urlExpirada = false;
    });

    try {
      final gateway = widget.pdfTermoGateway ?? FirebasePdfTermoGateway();
      final res = await gateway.obterUrlDownloadPdf(
        fichaId: widget.fichaId,
        participacaoId: p.id,
      );

      if (!mounted) return;
      setState(() {
        _carregando = false;
        if (res.isExpirada) {
          _urlExpirada = true;
          _downloadModel = null;
        } else {
          _urlExpirada = false;
          _downloadModel = res;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final isExp = msg.toLowerCase().contains('expirad') ||
          msg.toLowerCase().contains('token expired');
      setState(() {
        _carregando = false;
        if (isExp) {
          _urlExpirada = true;
          _downloadModel = null;
        } else {
          _erro = 'Falha ao carregar a pré-visualização: $msg';
        }
      });
    }
  }

  Future<void> _baixarPdf() async {
    final p = widget.participacao;
    if (p == null) return;

    setState(() => _baixando = true);

    try {
      final gateway = widget.pdfTermoGateway ?? FirebasePdfTermoGateway();
      // Sempre garante reautorização segura ou validação
      ResultadoDownloadPdfModel dados = _downloadModel ??
          await gateway.obterUrlDownloadPdf(
            fichaId: widget.fichaId,
            participacaoId: p.id,
          );

      if (dados.isExpirada) {
        dados = await gateway.obterUrlDownloadPdf(
          fichaId: widget.fichaId,
          participacaoId: p.id,
        );
      }

      if (!mounted) return;
      setState(() {
        _downloadModel = dados;
        _urlExpirada = false;
      });

      baixarOuAbrirPdf(dados.urlDownload);
      widget.onAposBaixar?.call();

      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'Documento da equipe ${p.nomeEquipe.isNotEmpty ? p.nomeEquipe : p.equipeId} pronto!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('expirad')) {
        setState(() => _urlExpirada = true);
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Tentar novamente',
            textColor: Colors.white,
            onPressed: _baixarPdf,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _baixando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: widget.alturaMinima),
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCabecalho(),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s16),
          _buildCorpo(),
        ],
      ),
    );
  }

  Widget _buildCabecalho() {
    final p = widget.participacao;
    final nomeEquipe = p?.nomeEquipe.isNotEmpty == true
        ? p!.nomeEquipe
        : (p?.equipeId ?? 'Equipe');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
          ),
          child: const Icon(
            Icons.picture_as_pdf_outlined,
            color: AppColors.blue600,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documento Probatório — $nomeEquipe',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p?.isAtiva == true
                    ? 'Termo individual homologado no servidor (AD-13)'
                    : 'Acompanhamento do documento privado',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (p != null) ...[
          const SizedBox(width: AppSpacing.s8),
          StatusChip(status: p.estado),
        ],
      ],
    );
  }

  Widget _buildCorpo() {
    final p = widget.participacao;

    if (p == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s32),
        child: Center(
          child: Text(
            'Selecione uma equipe para consultar o documento privado.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (!p.isAtiva) {
      return _buildIndisponivelNaoAprovada(p);
    }

    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.s16),
              Text(
                'Consultando autorização segura do documento...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_urlExpirada) {
      return _buildUrlExpirada();
    }

    if (_erro != null) {
      return _buildErroVisualizacao();
    }

    return _buildPreviewAtivo(p);
  }

  Widget _buildIndisponivelNaoAprovada(ParticipacaoModel p) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.s12),
          const Text(
            'Documento Probatório Indisponível',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'O termo de voluntariado desta equipe estará disponível para consulta e download somente após a conclusão da aprovação e homologação final no Maanaim.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Situação atual: ${p.proximaAcao.isNotEmpty ? p.proximaAcao : p.estado}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.navy900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlExpirada() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.timer_off_outlined,
            size: 36,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.s12),
          const Text(
            'Link Temporário Expirado',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Por diretriz de privacidade e segurança, o acesso temporário ao PDF expirou. Solicite uma renovação para reautorizar a visualização.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          ElevatedButton.icon(
            key: const Key('btn_renovar_url_pdf'),
            onPressed: () => _carregarUrlPdf(forcarRenovacao: true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Renovar link de acesso'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue600,
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErroVisualizacao() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
          const SizedBox(height: AppSpacing.s12),
          Text(
            _erro ?? 'Erro ao obter documento',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.navy900),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('btn_tentar_novamente_pdf'),
                onPressed: () => _carregarUrlPdf(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Recarregar documento'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              ElevatedButton.icon(
                key: const Key('btn_baixar_pdf_fallback'),
                onPressed: _baixando ? null : _baixarPdf,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Baixar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewAtivo(ParticipacaoModel p) {
    final nomeArq = _downloadModel?.nomeArquivo.isNotEmpty == true
        ? _downloadModel!.nomeArquivo
        : 'Termo_${p.equipeId}.pdf';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Folha visual neutra de representação do documento
        Container(
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho institucional do documento
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MAANAIM • VOLUNTARIADO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Homologado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              const Text(
                'TERMO DE ADESÃO E COMPROMISSO DE VOLUNTARIADO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy900,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLinhaMeta('Voluntário:', widget.nomeVoluntario ?? 'Homologado'),
                    const SizedBox(height: 4),
                    _buildLinhaMeta('Equipe:', p.nomeEquipe.isNotEmpty ? p.nomeEquipe : p.equipeId),
                    const SizedBox(height: 4),
                    _buildLinhaMeta('Ciclo:', p.ciclo),
                    if (p.vigenciaInicio != null && p.vigenciaFim != null) ...[
                      const SizedBox(height: 4),
                      _buildLinhaMeta(
                        'Vigência:',
                        '${p.vigenciaInicio!.split('T')[0]} a ${p.vigenciaFim!.split('T')[0]}',
                      ),
                    ],
                    const SizedBox(height: 4),
                    _buildLinhaMeta('Arquivo oficial:', nomeArq),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              const Text(
                'Este documento probatório é gerado exclusivamente a partir de evidências imutáveis no servidor conforme a diretriz AD-13.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),

        // Barra de Ações (Acessível: Touch targets >= 44px)
        Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('btn_abrir_documento'),
              onPressed: _baixando || _downloadModel == null
                  ? null
                  : () => baixarOuAbrirPdf(_downloadModel!.urlDownload),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir Documento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy900,
                side: const BorderSide(color: AppColors.navy900),
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            ElevatedButton.icon(
              key: const Key('btn_baixar_pdf'),
              onPressed: _baixando ? null : _baixarPdf,
              icon: _baixando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_baixando ? 'Baixando...' : 'Baixar PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue600,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinhaMeta(String rotulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            rotulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navy900,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/responsive_data_table.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../termo/termo_adesao_model.dart';
import '../termo/termo_dialog.dart';
import 'termos_service.dart';

/// Tela administrativa para gestão, publicação e consulta histórica de termos de adesão.
/// Conforme Story 8.14 (Tela S13): exibe versões, pendências operacionais vigentes,
/// universo histórico U(V) imutável e modal de revisão com impacto de ativos.
class TermosScreen extends StatefulWidget {
  const TermosScreen({
    super.key,
    required this.gateway,
  });

  final TermosGateway gateway;

  @override
  State<TermosScreen> createState() => _TermosScreenState();
}

class _TermosScreenState extends State<TermosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _conteudoController = TextEditingController();

  TermoVigente? _termo;
  bool _carregando = true;
  bool _publicando = false;
  String? _erro;
  String? _mensagemSucesso;
  bool _mostrarFormulario = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final termo = await widget.gateway.consultarTermos();
      if (mounted) {
        setState(() {
          _termo = termo;
          _carregando = false;
          if (termo != null && _tituloController.text.isEmpty) {
            _tituloController.text = termo.titulo;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os termos. Tente novamente.';
          _carregando = false;
        });
      }
    }
  }

  void _abrirModalConfirmacao() {
    if (!_formKey.currentState!.validate()) return;

    final proximaVersao = (_termo?.versaoVigenteNumero ?? 0) + 1;
    final titulo = _tituloController.text.trim();
    final conteudo = _conteudoController.text.trim();
    final totalAtivosAfetados = _termo?.totalAtivosAtuais ?? 0;

    showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: AppSpacing.s8),
              Flexible(child: Text('Confirmar Publicação')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atenção: A publicação da versão $proximaVersao é definitiva e estritamente imutável.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  const Text(
                    'Não será possível editar ou excluir este documento após a confirmação. '
                    'Correções futuras exigirão uma nova versão.',
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 18, color: AppColors.blue600),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              'Impacto nos Voluntários Ativos',
                              style: AppTypography.label.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          totalAtivosAfetados > 0
                              ? '$totalAtivosAfetados voluntário(s) em estado ATIVA serão incluídos no universo histórico U(v$proximaVersao) e terão pendência de aceite da nova versão vigente.'
                              : 'Nenhum voluntário ativo no momento. O universo U(v$proximaVersao) será constituído vazio.',
                          style: AppTypography.caption.copyWith(color: AppColors.navy900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text('Título: $titulo', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Caracteres: ${conteudo.length}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(dialogCtx).pop(false),
            ),
            PrimaryButton(
              label: 'Confirmar e Publicar',
              icon: Icons.check,
              onPressed: () => Navigator.of(dialogCtx).pop(true),
            ),
          ],
        );
      },
    ).then((confirmado) {
      if (confirmado == true) {
        _executarPublicacao();
      }
    });
  }

  Future<void> _executarPublicacao() async {
    setState(() {
      _publicando = true;
      _erro = null;
      _mensagemSucesso = null;
    });

    final titulo = _tituloController.text.trim();
    final conteudo = _conteudoController.text.trim();
    final expectedVersion = _termo?.versaoVigenteNumero ?? 0;
    final commandId = 'cmd-termo-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final resultado = await widget.gateway.publicarTermo(
        commandId: commandId,
        titulo: titulo,
        conteudo: conteudo,
        expectedVersion: expectedVersion,
      );

      if (mounted) {
        setState(() {
          _publicando = false;
          _mostrarFormulario = false;
          _conteudoController.clear();
          _mensagemSucesso =
              'Versão v${resultado.numeroVersao} publicada com sucesso!';
        });
        _carregar();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _publicando = false;
          _erro = 'Falha ao publicar o termo. Verifique a conexão ou se houve atualização concorrente.';
        });
      }
    }
  }

  void _verDetalhesVersao(VersaoTermo versao) {
    final eAVigente = versao.id == _termo?.versaoVigenteId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppGeometry.radiusCard)),
          ),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      StatusChip(
                        status: eAVigente ? 'ATIVA' : 'INATIVA',
                        label: eAVigente ? 'Vigente' : 'Histórico',
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'Versão ${versao.numeroVersao}',
                        style: AppTypography.h2,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                versao.titulo,
                style: AppTypography.h3,
              ),
              if (versao.publicadoEm != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Publicado em: ${versao.publicadoEm!.toLocal().toString().split('.')[0]}',
                  style: AppTypography.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              // Card de Auditoria e Universo U(V)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universo Histórico U(${versao.rotuloVersao})',
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    if (versao.universoRegistrado) ...[
                      Text(
                        'Afetados na publicação: ${versao.totalAfetados} voluntário(s)',
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Aceites comprovados: ${versao.aceitosHistorico}  |  Pendentes históricos: ${versao.pendentesHistorico}',
                        style: AppTypography.caption,
                      ),
                      if (versao.criterio != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Critério de snapshot: ${versao.criterio}',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ] else ...[
                      Text(
                        'Indisponível — universo histórico não registrado',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              SelectableText(
                'Hash SHA-256: ${versao.hashSha256}',
                style: AppTypography.caption.copyWith(fontFamily: 'monospace'),
              ),
              const Divider(height: AppSpacing.s24),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    versao.conteudo,
                    style: AppTypography.body,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _verDocumentoDialog(VersaoTermo versao) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.blue600),
            const SizedBox(width: AppSpacing.s8),
            Flexible(child: Text('${versao.titulo} (${versao.rotuloVersao})')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
          child: SingleChildScrollView(
            child: SelectableText(
              versao.conteudo,
              style: AppTypography.body,
            ),
          ),
        ),
        actions: [
          PrimaryButton(
            label: 'Fechar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _abrirModeloOficial() {
    const model = TermoAdesaoModel(
      nomeVoluntario: 'NOME DO VOLUNTÁRIO',
      profissaoVoluntario: 'PROFISSÃO DO VOLUNTÁRIO',
      cpfVoluntario: '000.000.000-00',
      nomeCoordenador: 'NOME DO COORDENADOR DO MAANAIM',
      cpfCoordenador: '000.000.000-00',
      nomeEquipe: 'NOME DA EQUIPE',
      nomePastorVoluntario: 'NOME DO PASTOR DO VOLUNTÁRIO',
      nomePastorEquipe: 'NOME DO PASTOR CHEFE DA EQUIPE',
      dataTexto: 'DATA',
    );
    exibirTermoAdesaoDialog(context, model);
  }

  Widget _buildCardTermoVigente(VersaoTermo versaoVigente) {
    return SectionCard(
      title: 'Termo Vigente',
      subtitle: versaoVigente.titulo,
      headerAction: StatusChip(
        status: 'ATIVA',
        label: 'Vigente ${versaoVigente.rotuloVersao}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: SelectableText(
                  'Hash SHA-256: ${versaoVigente.hashSha256}',
                  style: AppTypography.caption.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          if (versaoVigente.publicadoEm != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    'Publicado em: ${versaoVigente.publicadoEm!.toLocal().toString().split('.')[0]}',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          // Resumo da Pendência Operacional Vigente
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppColors.blue600),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ativos com aceite vigente pendente: ${_termo!.ativosComAceiteVigentePendente} de ${_termo!.totalAtivosAtuais}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy900,
                        ),
                      ),
                      Text(
                        'Ativos com aceite concluído: ${_termo!.ativosComAceiteVigenteConcluido} de ${_termo!.totalAtivosAtuais}',
                        style: AppTypography.caption.copyWith(color: AppColors.navy900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppGeometry.inputBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                versaoVigente.conteudo,
                style: AppTypography.body,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              SecondaryButton(
                label: 'Ver Documento Completo',
                icon: Icons.visibility_outlined,
                onPressed: () => _verDetalhesVersao(versaoVigente),
              ),
              SecondaryButton(
                label: 'Modelo Oficial (PDF)',
                icon: Icons.description_outlined,
                onPressed: _abrirModeloOficial,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardVersaoMobile(VersaoTermo versao) {
    final eAVigente = versao.id == _termo?.versaoVigenteId;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(AppGeometry.radiusButton),
                    ),
                    child: Text(
                      versao.rotuloVersao,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  StatusChip(
                    status: eAVigente ? 'ATIVA' : 'INATIVA',
                    label: eAVigente ? 'Vigente' : 'Histórico',
                  ),
                ],
              ),
              if (versao.publicadoEm != null)
                Text(
                  versao.publicadoEm!.toLocal().toString().split(' ')[0],
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            versao.titulo,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy900,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'SHA-256: ${versao.hashResumido}',
            style: AppTypography.caption.copyWith(
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (eAVigente) ...[
            Text(
              'Ativos com aceite vigente pendente: ${_termo!.ativosComAceiteVigentePendente} de ${_termo!.totalAtivosAtuais}',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: _termo!.ativosComAceiteVigentePendente > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          Text(
            'Histórico da publicação: ${versao.descricaoHistoricoAceites}',
            style: AppTypography.caption.copyWith(
              color: versao.universoRegistrado
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontStyle: versao.universoRegistrado ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              SecondaryButton(
                label: 'Ver Documento',
                icon: Icons.description_outlined,
                onPressed: () => _verDocumentoDialog(versao),
              ),
              SecondaryButton(
                label: 'Histórico / Detalhes',
                icon: Icons.history_outlined,
                onPressed: () => _verDetalhesVersao(versao),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final versaoVigente = _termo?.versaoAtual;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Termos e Versões',
                subtitle:
                    'Publicação e versionamento imutável dos termos de adesão do Maanaim com trilha de auditoria e métricas de aceite.',
                action: Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    SecondaryButton(
                      label: 'Modelo Oficial (PDF)',
                      icon: Icons.description_outlined,
                      onPressed: _abrirModeloOficial,
                    ),
                    PrimaryButton(
                      label: _mostrarFormulario ? 'Cancelar' : 'Nova Versão',
                      icon: _mostrarFormulario ? Icons.close : Icons.add,
                      onPressed: () {
                        setState(() {
                          _mostrarFormulario = !_mostrarFormulario;
                          _erro = null;
                          _mensagemSucesso = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              if (_erro != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    border: Border.all(color: AppColors.danger),
                    borderRadius: AppGeometry.inputBorderRadius,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _erro!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _carregar,
                        child: const Text('Repetir'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              if (_mensagemSucesso != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    border: Border.all(color: AppColors.success),
                    borderRadius: AppGeometry.inputBorderRadius,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _mensagemSucesso!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              if (_carregando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Formulário de Nova Versão
                if (_mostrarFormulario) ...[
                  SectionCard(
                    title: versaoVigente == null
                        ? 'Publicar 1ª Versão do Termo'
                        : 'Publicar Versão v${(_termo?.versaoVigenteNumero ?? 0) + 1}',
                    subtitle:
                        'O texto publicado será gravado com snapshot imutável de universo e se tornará estritamente imutável.',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _tituloController,
                            decoration: const InputDecoration(
                              labelText: 'Título do Termo *',
                              hintText: 'Ex: Termo de Adesão ao Serviço Voluntário',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 3) {
                                return 'Informe um título com pelo menos 3 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(Icons.auto_fix_high, size: 16),
                              label: const Text('Carregar texto oficial do modelo'),
                              onPressed: () {
                                setState(() {
                                  if (_tituloController.text.isEmpty) {
                                    _tituloController.text =
                                        'TERMO DE ADESÃO DE VOLUNTÁRIO';
                                  }
                                  _conteudoController.text =
                                      'Lei do Serviço Voluntário (LEI 9.608/1998)\n\n'
                                      'NOME DO VOLUNTÁRIO, Brasileiro(a), Profissão PROFISSÃO DO VOLUNTÁRIO, '
                                      'inscrito(a) no CPF/MF sob o nº CPF DO VOLUNTÁRIO, celebra com a IGREJA CRISTÃ MARANATA, '
                                      'pessoa jurídica de direito privado, inscrito no CNPJ sob o nº 27.056.910/0001-42, com sede na '
                                      'Rua Torquato Laranja, 90, Centro, Vila Velha – ES, CEP 29106-720, neste ato, representado pelo '
                                      'Administrador Voluntário do Maanaim do RIO GRANDE DO NORTE, NOME DO COORDENADOR DO MAANAIM, '
                                      'brasileiro, casado, inscrito no CPF/MF sob o nº CPF DO COORDENADOR DO MAANAIM, em conformidade aos '
                                      'preceitos da Lei nº 9.608 de 18/02/1998, o presente TERMO DE ADESÃO AO SERVIÇO VOLUNTÁRIO '
                                      'para prestação de serviço na equipe NOME DA EQUIPE.\n\n'
                                      'Por ser verdade declaramos conhecer e aceitar todos os termos da Lei nr 9.608 de 18/02/1998, '
                                      'que trata sobre o serviço voluntário.';
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          TextFormField(
                            controller: _conteudoController,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Conteúdo Integral do Termo *',
                              hintText: 'Insira as cláusulas, compromissos e declarações do termo...',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 20) {
                                return 'O conteúdo deve ter no mínimo 20 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SecondaryButton(
                                label: 'Cancelar',
                                onPressed: () {
                                  setState(() => _mostrarFormulario = false);
                                },
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              PrimaryButton(
                                label: 'Revisar e Publicar',
                                icon: Icons.publish,
                                isLoading: _publicando,
                                onPressed: _publicando ? null : _abrirModalConfirmacao,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                ],

                // Card do Termo Vigente
                if (versaoVigente == null)
                  SectionCard(
                    child: EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Nenhum termo publicado',
                      message:
                          'Ainda não há termo vigente para aceite dos voluntários. Clique em "Nova Versão" para publicar o primeiro termo.',
                      action: PrimaryButton(
                        label: 'Publicar Primeiro Termo',
                        onPressed: () {
                          setState(() => _mostrarFormulario = true);
                        },
                      ),
                    ),
                  )
                else
                  _buildCardTermoVigente(versaoVigente),

                const SizedBox(height: AppSpacing.s24),

                // Seção de Histórico de Versões em Tabela / Cartões
                if (_termo != null && _termo!.versoes.isNotEmpty) ...[
                  Text(
                    'Histórico de Versões (${_termo!.totalVersoes})',
                    style: AppTypography.h2,
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  AppDataTable<VersaoTermo>(
                    items: _termo!.versoes,
                    breakpoint: 768,
                    columns: [
                      AppDataColumn<VersaoTermo>(
                        label: 'Versão',
                        cellBuilder: (item) {
                          final eAVigente = item.id == _termo!.versaoVigenteId;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.rotuloVersao,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blue600,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              StatusChip(
                                status: eAVigente ? 'ATIVA' : 'INATIVA',
                                label: eAVigente ? 'Vigente' : 'Histórico',
                              ),
                            ],
                          );
                        },
                      ),
                      AppDataColumn<VersaoTermo>(
                        label: 'Publicação',
                        cellBuilder: (item) => Text(
                          item.publicadoEm != null
                              ? item.publicadoEm!.toLocal().toString().split('.')[0]
                              : '—',
                          style: AppTypography.caption,
                        ),
                      ),
                      AppDataColumn<VersaoTermo>(
                        label: 'Ativos c/ Aceite Pendente',
                        cellBuilder: (item) {
                          final eAVigente = item.id == _termo!.versaoVigenteId;
                          if (!eAVigente) {
                            return const Text('—', style: TextStyle(color: AppColors.textSecondary));
                          }
                          return Text(
                            '${_termo!.ativosComAceiteVigentePendente} de ${_termo!.totalAtivosAtuais}',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _termo!.ativosComAceiteVigentePendente > 0
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          );
                        },
                      ),
                      AppDataColumn<VersaoTermo>(
                        label: 'Afetados na Publicação',
                        cellBuilder: (item) {
                          if (!item.universoRegistrado) {
                            return const Text(
                              'Indisponível — universo histórico não registrado',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            );
                          }
                          return Text(
                            '${item.aceitosHistorico} de ${item.totalAfetados} aceitos (${item.pendentesHistorico} pendentes)',
                            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                      AppDataColumn<VersaoTermo>(
                        label: 'Ações',
                        cellBuilder: (item) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.description_outlined, size: 20, color: AppColors.blue600),
                              tooltip: 'Ver documento',
                              onPressed: () => _verDocumentoDialog(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history_outlined, size: 20, color: AppColors.navy900),
                              tooltip: 'Histórico e detalhes da versão',
                              onPressed: () => _verDetalhesVersao(item),
                            ),
                          ],
                        ),
                      ),
                    ],
                    cardBuilder: (context, item) => _buildCardVersaoMobile(item),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

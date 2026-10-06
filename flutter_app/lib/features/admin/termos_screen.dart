import 'package:flutter/material.dart';

import '../../ui/components/buttons.dart';
import '../../ui/components/layout_elements.dart';
import '../../ui/components/status_chips.dart';
import '../../ui/tokens.dart';
import '../termo/termo_adesao_model.dart';
import '../termo/termo_dialog.dart';
import 'termos_service.dart';

/// Tela administrativa para gestão, publicação e consulta histórica de termos de adesão.
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
          content: Column(
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
              Text('Título: $titulo', style: AppTypography.body),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Caracteres: ${conteudo.length}',
                style: AppTypography.caption,
              ),
            ],
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
                      StatusChip(status: 'INATIVA', label: versao.rotuloVersao),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'Versão ${versao.numeroVersao}',
                        style: AppTypography.h2,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                versao.titulo,
                style: AppTypography.h3,
              ),
              const SizedBox(height: AppSpacing.s8),
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
                    'Publicação e versionamento imutável dos termos de adesão do Maanaim com trilha de auditoria.',
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
                        'O texto publicado será gravado com hash SHA-256 e se tornará imutável.',
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
                  SectionCard(
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
                              Text(
                                'Publicado em: ${versaoVigente.publicadoEm!.toLocal().toString().split('.')[0]}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ],
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
                        SecondaryButton(
                          label: 'Ver Documento Completo',
                          icon: Icons.visibility_outlined,
                          onPressed: () => _verDetalhesVersao(versaoVigente),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.s24),

                // Seção de Histórico de Versões
                if (_termo != null && _termo!.versoes.isNotEmpty) ...[
                  Text(
                    'Histórico de Versões (${_termo!.totalVersoes})',
                    style: AppTypography.h2,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  ..._termo!.versoes.map((versao) {
                    final eAVigente = versao.id == _termo!.versaoVigenteId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                      child: SectionCard(
                        headerAction: eAVigente
                            ? const StatusChip(status: 'ATIVA', label: 'Vigente')
                            : const StatusChip(status: 'INATIVA', label: 'Histórico'),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s8),
                              decoration: BoxDecoration(
                                color: AppColors.blue50,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                versao.rotuloVersao,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blue600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    versao.titulo,
                                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: AppSpacing.s4),
                                  Text(
                                    'SHA-256: ${versao.hashResumido}',
                                    style: AppTypography.caption.copyWith(fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, size: 16),
                              tooltip: 'Visualizar conteúdo integral',
                              onPressed: () => _verDetalhesVersao(versao),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'layout_elements.dart';

/// Definição de coluna para o [AppDataTable].
class AppDataColumn<T> {
  const AppDataColumn({
    required this.label,
    required this.cellBuilder,
    this.numeric = false,
    this.tooltip,
  });

  final String label;
  final Widget Function(T item) cellBuilder;
  final bool numeric;
  final String? tooltip;
}

/// Lista de registros adaptada para mobile em cartões acessíveis e verticais.
class ResponsiveRecordList<T> extends StatelessWidget {
  const ResponsiveRecordList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? emptyWidget;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return emptyWidget ?? const EmptyState(title: 'Nenhum registro encontrado');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (context, index) => itemBuilder(context, items[index]),
    );
  }
}

/// Tabela institucional adaptativa:
/// - No Desktop/Tablet amplo (≥ [breakpoint]): renderiza como tabela de dados com cabeçalho limpo.
/// - No Mobile (< [breakpoint]): converte automaticamente para cartões empilhados sem exigir rolagem horizontal.
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.cardBuilder,
    this.breakpoint = 768.0,
    this.emptyWidget,
    this.isLoading = false,
    this.header,
  });

  final List<AppDataColumn<T>> columns;
  final List<T> items;
  final Widget Function(BuildContext context, T item)? cardBuilder;
  final double breakpoint;
  final Widget? emptyWidget;
  final bool isLoading;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        children: [
          LoadingSkeleton(height: 48),
          SizedBox(height: AppSpacing.s8),
          LoadingSkeleton(height: 120),
          SizedBox(height: AppSpacing.s8),
          LoadingSkeleton(height: 120),
        ],
      );
    }

    if (items.isEmpty) {
      return emptyWidget ?? const EmptyState(title: 'Nenhum registro encontrado');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= breakpoint;

        if (isDesktop) {
          return SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: header!,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF9FAFB),
                    ),
                    dataRowMinHeight: AppGeometry.minTouchTarget,
                    dataRowMaxHeight: AppGeometry.minTouchTarget + 16,
                    columns: columns.map((col) {
                      return DataColumn(
                        label: Text(
                          col.label,
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy900,
                          ),
                        ),
                        numeric: col.numeric,
                        tooltip: col.tooltip,
                      );
                    }).toList(),
                    rows: items.map((item) {
                      return DataRow(
                        cells: columns.map((col) {
                          return DataCell(col.cellBuilder(item));
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }

        // Modo mobile: renderiza em cartões
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: AppSpacing.s12),
            ],
            ResponsiveRecordList<T>(
              items: items,
              itemBuilder: (ctx, item) {
                if (cardBuilder != null) {
                  return cardBuilder!(ctx, item);
                }
                return _buildCartaoPadrao(item);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCartaoPadrao(T item) {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((col) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  col.label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: col.cellBuilder(item),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Barra de filtros contextual e acessível (busca + seletores + limpar).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    this.searchController,
    this.searchHint = 'Buscar...',
    this.onSearchChanged,
    this.filters,
    this.onClear,
    this.clearLabel = 'Limpar filtros',
  });

  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget>? filters;
  final VoidCallback? onClear;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final searchField = searchController != null || onSearchChanged != null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: AppGeometry.minTouchTarget,
                  maxWidth: isMobile ? double.infinity : 320,
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                  ),
                ),
              )
            : null;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (searchField != null) ...[
                searchField,
                const SizedBox(height: AppSpacing.s8),
              ],
              if (filters != null && filters!.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: filters!,
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              if (onClear != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(clearLabel),
                  ),
                ),
            ],
          );
        }

        return Row(
          children: [
            if (searchField != null) ...[
              searchField,
              const SizedBox(width: AppSpacing.s12),
            ],
            if (filters != null && filters!.isNotEmpty) ...[
              ...filters!,
              const SizedBox(width: AppSpacing.s12),
            ],
            const Spacer(),
            if (onClear != null)
              SecondaryButton(
                label: clearLabel,
                icon: Icons.clear,
                onPressed: onClear,
              ),
          ],
        );
      },
    );
  }
}

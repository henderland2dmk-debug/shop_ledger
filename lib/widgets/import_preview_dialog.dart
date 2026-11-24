import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../services/excel_import_service.dart';

/// Shows the parsed sheet before anything is added to the stock.
class ImportPreviewDialog extends StatelessWidget {
  const ImportPreviewDialog({
    super.key,
    required this.result,
    this.duplicateCount = 0,
    this.note,
    this.confirmLabel,
  });

  final ImportResult result;
  final int duplicateCount;
  final String? note;
  final String? confirmLabel;

  @override
  Widget build(BuildContext context) {
    final validRows = result.validRows;
    final invalidRows = result.invalidRows;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Review import', style: textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          result.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SummaryPill(
                          icon: Icons.check_circle_rounded,
                          label: validRows.length == 1
                              ? '1 product ready'
                              : '${validRows.length} products ready',
                          background: AppColors.softGreen,
                          foreground: AppColors.primaryDark,
                        ),
                        if (invalidRows.isNotEmpty)
                          _SummaryPill(
                            icon: Icons.error_outline_rounded,
                            label: invalidRows.length == 1
                                ? '1 row will be skipped'
                                : '${invalidRows.length} rows will be skipped',
                            background: AppColors.dangerSoft,
                            foreground: AppColors.danger,
                          ),
                        if (duplicateCount > 0)
                          _SummaryPill(
                            icon: Icons.merge_type_rounded,
                            label: duplicateCount == 1
                                ? '1 will update existing stock'
                                : '$duplicateCount will update existing stock',
                            background: AppColors.softLime,
                            foreground: const Color(0xFF4E7A21),
                          ),
                      ],
                    ),
                    if (invalidRows.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _InvalidRows(rows: invalidRows),
                    ],
                    if (validRows.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text('Ready to import', style: textTheme.titleSmall),
                      const SizedBox(height: 10),
                      _PreviewRows(rows: validRows),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 18),
                      Text(note!, style: textTheme.bodySmall),
                    ],
                    if (validRows.isEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'None of the rows can be imported yet. Add a '
                          'particular and a valid rate to at least one row.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Only rows with particulars and a rate are imported. '
                    'Missing quantities default to 1 and totals are calculated.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cancelButton = TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      );
                      final importButton = FilledButton(
                        key: const Key('confirm-import-button'),
                        onPressed: validRows.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(true),
                        child: Text(
                          confirmLabel ??
                              (validRows.length == 1
                                  ? 'Import 1 product'
                                  : 'Import ${validRows.length} products'),
                        ),
                      );

                      if (constraints.maxWidth < 420) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            importButton,
                            const SizedBox(height: 4),
                            cancelButton,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          cancelButton,
                          const SizedBox(width: 8),
                          importButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidRows extends StatelessWidget {
  const _InvalidRows({required this.rows});

  final List<ImportRow> rows;

  @override
  Widget build(BuildContext context) {
    final shown = rows.take(5).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2D5D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Rows that need attention',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final row in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'Row ${row.sourceRow}: ${row.errors.join(' · ')}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.danger),
              ),
            ),
          if (rows.length > shown.length)
            Text(
              'And ${rows.length - shown.length} more…',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

class _PreviewRows extends StatelessWidget {
  const _PreviewRows({required this.rows});

  final List<ImportRow> rows;

  @override
  Widget build(BuildContext context) {
    final shown = rows.take(30).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          const _PreviewRow(
            particulars: 'PARTICULARS',
            rate: 'RATE',
            quantity: 'QTY',
            total: 'TOTAL',
            isHeader: true,
          ),
          for (final row in shown) ...[
            const Divider(height: 14),
            _PreviewRow(
              particulars: row.particulars,
              rate: formatMoney(row.rate ?? 0),
              quantity: formatQuantity(row.quantity ?? 1),
              total: formatMoney(row.calculatedTotal),
            ),
          ],
          if (rows.length > shown.length) ...[
            const Divider(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing the first ${shown.length} of ${rows.length} rows',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.particulars,
    required this.rate,
    required this.quantity,
    required this.total,
    this.isHeader = false,
  });

  final String particulars;
  final String rate;
  final String quantity;
  final String total;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? Theme.of(context).textTheme.labelSmall
              ?.copyWith(letterSpacing: 0.7, fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink);

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: isHeader
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(particulars, maxLines: 1, style: style),
                )
              : Text(
                  particulars,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _NumberText(text: rate, style: style),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _NumberText(text: quantity, style: style),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _NumberText(
            text: total,
            style: isHeader
                ? style
                : style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _NumberText extends StatelessWidget {
  const _NumberText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/bill_item.dart';
import '../services/bill_import_service.dart';

/// Review panel used before bill rows are added to the current bill.
class BillImportPreviewDialog extends StatelessWidget {
  const BillImportPreviewDialog({super.key, required this.result});

  final BillImportResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
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
                      color: AppColors.softLime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF4E7A21),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add to bill', style: textTheme.titleLarge),
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
                        _Pill(
                          icon: Icons.check_circle_rounded,
                          label: result.itemCount == 1
                              ? '1 line ready'
                              : '${result.itemCount} lines ready',
                          background: AppColors.softGreen,
                          foreground: AppColors.primaryDark,
                        ),
                        if (result.issueCount > 0)
                          _Pill(
                            icon: Icons.error_outline_rounded,
                            label: result.issueCount == 1
                                ? '1 row skipped'
                                : '${result.issueCount} rows skipped',
                            background: AppColors.dangerSoft,
                            foreground: AppColors.danger,
                          ),
                      ],
                    ),
                    if (result.issueCount > 0) ...[
                      const SizedBox(height: 18),
                      Container(
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
                                    'Rows that cannot be added',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            for (final issue in result.issues.take(6))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  'Row ${issue.sourceRow} · ${issue.particulars}: '
                                  '${issue.reason}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            if (result.issues.length > 6)
                              Text(
                                'And ${result.issues.length - 6} more…',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (result.items.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text('Ready for the bill', style: textTheme.titleSmall),
                      const SizedBox(height: 10),
                      _ItemRows(items: result.items),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Adding ${formatQuantity(_quantity(result.items))} units  •  '
                            '${formatMoney(_total(result.items))}',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  );
                  final confirm = FilledButton(
                    key: const Key('confirm-bill-import-button'),
                    onPressed: result.items.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text(
                      result.itemCount == 1
                          ? 'Add 1 line'
                          : 'Add ${result.itemCount} lines',
                    ),
                  );

                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [confirm, const SizedBox(height: 4), cancel],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [cancel, const SizedBox(width: 8), confirm],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _quantity(List<BillItem> items) =>
      items.fold(0, (total, item) => total + item.quantity);

  static double _total(List<BillItem> items) =>
      items.fold(0, (total, item) => total + item.total);
}

class _Pill extends StatelessWidget {
  const _Pill({
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

class _ItemRows extends StatelessWidget {
  const _ItemRows({required this.items});

  final List<BillItem> items;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(20).toList(growable: false);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'PARTICULARS',
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 54,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.right,
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.right,
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          for (final item in shown) ...[
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    item.particulars,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 54,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatQuantity(item.quantity),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(item.total),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (items.length > shown.length) ...[
            const Divider(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing the first ${shown.length} of ${items.length} lines',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

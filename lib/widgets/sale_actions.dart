import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/snackbars.dart';
import '../models/sale.dart';
import '../state/product_scope.dart';
import '../state/sales_scope.dart';

/// Asks before rejecting a bill, then restores its quantities to stock.
Future<void> discardSaleWithConfirmation(
  BuildContext context,
  Sale sale,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _DiscardBillDialog(sale: sale),
  );
  if (confirmed != true || !context.mounted) return;

  final discarded = await SalesScope.of(context)
      .discardSale(saleId: sale.id, productStore: ProductScope.of(context));
  if (!context.mounted) return;

  showBriefSnackBar(
    context,
    discarded == null
        ? 'That bill is no longer in the history.'
        : '${discarded.id} discarded. Products were returned to stock.',
    isError: discarded == null,
  );
}

class _DiscardBillDialog extends StatelessWidget {
  const _DiscardBillDialog({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text(
        'Discard this bill?',
        style: TextStyle(color: AppColors.danger),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sale.id} will be removed from sales history. Because the sale is '
            'being rejected, its products will be added back to stock.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF2D5D2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WARNING: This cannot be undone. All totals and sales '
                    'reports will change, and the bill number will never be '
                    'reused.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-discard-bill-button'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Discard bill'),
        ),
      ],
    );
  }
}

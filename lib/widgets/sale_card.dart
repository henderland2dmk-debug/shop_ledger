import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../core/snackbars.dart';
import '../models/sale.dart';
import '../services/bill_pdf_service.dart';
import 'surface_card.dart';

/// One completed bill. Used in the customer list and customer detail screens.
class SaleCard extends StatelessWidget {
  const SaleCard({super.key, required this.sale, required this.onDiscard});

  final Sale sale;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sale.id, style: textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      formatDateTime(sale.soldAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatMoney(sale.totalAmount),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                      width: 52,
                      child: Text(
                        'QTY',
                        textAlign: TextAlign.right,
                        style: textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        'RATE',
                        textAlign: TextAlign.right,
                        style: textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 84,
                      child: Text(
                        'TOTAL',
                        textAlign: TextAlign.right,
                        style: textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                for (final item in sale.items) ...[
                  const Divider(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          item.particulars,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: _RightText(
                          formatQuantity(item.quantity),
                          style: textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        child: _RightText(
                          formatMoney(item.rate),
                          style: textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 84,
                        child: _RightText(
                          formatMoney(item.total),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _printSale(context, sale),
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('Print'),
              ),
              OutlinedButton.icon(
                onPressed: () => _downloadSale(context, sale),
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text('PDF'),
              ),
              OutlinedButton.icon(
                key: Key('discard-bill-${sale.id}'),
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Discard bill'),
              ),
              Text(
                '${formatQuantity(sale.totalQuantity)} units sold',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _printSale(BuildContext context, Sale sale) async {
    try {
      await Printing.layoutPdf(
        name: 'Bill ${sale.id}',
        onLayout: (_) => buildBillPdf(sale),
      );
    } catch (_) {
      if (context.mounted) {
        showBriefSnackBar(
          context,
          'Printing is not available here.',
          isError: true,
        );
      }
    }
  }

  Future<void> _downloadSale(BuildContext context, Sale sale) async {
    try {
      final bytes = await buildBillPdf(sale);
      await Printing.sharePdf(bytes: bytes, filename: '${sale.id}.pdf');
    } catch (_) {
      if (context.mounted) {
        showBriefSnackBar(
          context,
          'The PDF could not be downloaded.',
          isError: true,
        );
      }
    }
  }
}

class _RightText extends StatelessWidget {
  const _RightText(this.text, {this.style});

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

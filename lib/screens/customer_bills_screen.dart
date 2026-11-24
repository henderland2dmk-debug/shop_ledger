import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/customer_bill_group.dart';
import '../state/sales_scope.dart';
import '../widgets/page_width.dart';
import '../widgets/sale_actions.dart';
import '../widgets/sale_card.dart';
import '../widgets/surface_card.dart';

/// Every saved bill belonging to one customer, newest first.
class CustomerBillsScreen extends StatelessWidget {
  const CustomerBillsScreen({super.key, required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
    final salesStore = SalesScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(customerName)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: salesStore,
          builder: (context, _) {
            final sales = salesStore.salesForCustomer(customerName);
            final group = CustomerBillGroup(
              customerName: customerName,
              sales: sales,
            );

            return SingleChildScrollView(
              key: const Key('customer-bills-list'),
              padding: const EdgeInsets.only(bottom: 36),
              child: PageWidth(
                maxWidth: 980,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      customerName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All bills recorded under this customer.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    SurfaceCard(
                      color: AppColors.softGreen,
                      borderColor: const Color(0xFFD6E6CC),
                      padding: const EdgeInsets.all(18),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _Summary(
                            label: 'Bills',
                            value: group.billCount.toString(),
                          ),
                          _Summary(
                            label: 'Units',
                            value: formatQuantity(group.totalQuantity),
                          ),
                          _Summary(
                            label: 'Total',
                            value: formatMoney(group.totalAmount),
                            highlight: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (sales.isEmpty)
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 24,
                        ),
                        child: Text(
                          'No bills left for this customer.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (final sale in sales) ...[
                        SaleCard(
                          sale: sale,
                          onDiscard: () =>
                              discardSaleWithConfirmation(context, sale),
                        ),
                        const SizedBox(height: 14),
                      ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primaryDark : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

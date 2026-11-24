import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/customer_keys.dart';
import '../core/formatters.dart';
import '../core/snackbars.dart';
import '../models/customer_bill_group.dart';
import '../state/sales_scope.dart';
import '../state/sales_store.dart';
import '../widgets/page_width.dart';
import '../widgets/sale_actions.dart';
import '../widgets/sale_card.dart';
import '../widgets/surface_card.dart';
import 'customer_bills_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesStore = SalesScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales history'),
        actions: [
          ListenableBuilder(
            listenable: salesStore,
            builder: (context, _) => salesStore.sales.isNotEmpty
                ? IconButton(
                    key: const Key('clear-sales-history-button'),
                    onPressed: () => _clearHistory(context, salesStore),
                    tooltip: 'Clear sales history',
                    color: AppColors.danger,
                    icon: const Icon(Icons.delete_forever_rounded),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: salesStore,
          builder: (context, _) {
            final search = normalizeCustomerName(_query);
            final groups = salesStore.customerBillGroups
                .where(
                  (group) =>
                      normalizeCustomerName(group.customerName)
                          .contains(search),
                )
                .toList(growable: false);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 36),
              child: PageWidth(
                maxWidth: 980,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Customer bills',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bills are kept under each customer. Search by name to '
                      'open their full history.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const Key('sales-customer-search-field'),
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        labelText: 'Search by customer name',
                        hintText: 'e.g. Ramesh Kumar',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                key: const Key('clear-customer-search'),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SalesStats(salesStore: salesStore),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            groups.isEmpty
                                ? 'No customers found'
                                : '${groups.length} customer(s) · '
                                      '${salesStore.saleCount} bill(s) sold',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (salesStore.sales.isEmpty)
                      const _EmptyHistory()
                    else if (groups.isEmpty)
                      _NoCustomerMatches(name: _query.trim())
                    else
                      for (final group in groups) ...[
                        _CustomerCard(
                          group: group,
                          onDiscard: () => discardSaleWithConfirmation(
                            context,
                            group.latestSale,
                          ),
                          onViewAll: () => _openCustomer(group),
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

  void _openCustomer(CustomerBillGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerBillsScreen(customerName: group.customerName),
      ),
    );
  }

  Future<void> _clearHistory(
    BuildContext context,
    SalesStore salesStore,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ClearSalesDialog(saleCount: salesStore.saleCount),
    );
    if (confirmed != true || !context.mounted) return;

    final count = await salesStore.clearSales();
    if (!context.mounted) return;

    showBriefSnackBar(
      context,
      count == 1
          ? '1 bill cleared from sales history.'
          : '$count bills cleared from sales history.',
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.group,
    required this.onDiscard,
    required this.onViewAll,
  });

  final CustomerBillGroup group;
  final VoidCallback onDiscard;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initial = group.customerName.trim().isEmpty
        ? '?'
        : group.customerName.trim()[0].toUpperCase();

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.softGreen,
                foregroundColor: AppColors.primaryDark,
                child: Text(initial, style: textTheme.titleMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.customerName,
                      key: Key(
                        'customer-name-${normalizeCustomerName(group.customerName).replaceAll(' ', '-')}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.billCount} bill(s) · '
                      '${formatQuantity(group.totalQuantity)} units',
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
                  formatMoney(group.totalAmount),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                'LATEST BILL',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SaleCard(sale: group.latestSale, onDiscard: onDiscard),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key(
                'view-customer-bills-${normalizeCustomerName(group.customerName).replaceAll(' ', '-')}',
              ),
              onPressed: onViewAll,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View all bills from this customer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCustomerMatches extends StatelessWidget {
  const _NoCustomerMatches({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      child: Column(
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 36,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'No customer named “$name”',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Check the spelling or clear the search to see every customer.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ClearSalesDialog extends StatefulWidget {
  const _ClearSalesDialog({required this.saleCount});

  final int saleCount;

  @override
  State<_ClearSalesDialog> createState() => _ClearSalesDialogState();
}

class _ClearSalesDialogState extends State<_ClearSalesDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text(
        'Clear sales history?',
        style: TextStyle(color: AppColors.danger),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete ${widget.saleCount} bill(s) from '
            'your sales history.',
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
                    'WARNING: Once the sales history is deleted, you cannot '
                    'retreat or recover those bills and totals. Your current '
                    'stock is not changed.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: const Key('clear-sales-understood-checkbox'),
                value: _understood,
                onChanged: (value) =>
                    setState(() => _understood = value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'I understand this cannot be undone.',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-clear-sales-button'),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Delete all history'),
        ),
      ],
    );
  }
}

class _SalesStats extends StatelessWidget {
  const _SalesStats({required this.salesStore});

  final SalesStore salesStore;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatCard(
            label: 'Sold today',
            amount: salesStore.soldToday,
            units: salesStore.unitsToday,
            count: salesStore.salesSince(salesStore.startOfToday),
            highlight: true,
          ),
          _StatCard(
            label: 'This week',
            amount: salesStore.soldThisWeek,
            units: salesStore.unitsThisWeek,
            count: salesStore.salesSince(salesStore.startOfWeek),
          ),
          _StatCard(
            label: 'This month',
            amount: salesStore.soldThisMonth,
            units: salesStore.unitsThisMonth,
            count: salesStore.salesSince(salesStore.startOfMonth),
          ),
          _StatCard(
            label: 'All time',
            amount: salesStore.totalSales,
            units: salesStore.totalUnitsSold,
            count: salesStore.saleCount,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.units,
    required this.count,
    this.highlight = false,
  });

  final String label;
  final double amount;
  final double units;
  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 176,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? AppColors.softGreen : const Color(0xFFFAFBF8),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: highlight ? const Color(0xFFD6E6CC) : AppColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCompactMoney(amount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppColors.primaryDark : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$count bill(s) · ${formatQuantity(units)} units',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.softLime,
      borderColor: const Color(0xFFDCE9C8),
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 40,
            color: Color(0xFF4E7A21),
          ),
          const SizedBox(height: 14),
          Text('No sales yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Create a bill from the home page. Once you sell it, every item '
            'and total will appear here under its customer.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

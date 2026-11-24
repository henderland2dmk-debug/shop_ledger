import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../core/snackbars.dart';
import '../models/product.dart';
import '../models/product_form_result.dart';
import '../state/product_scope.dart';
import '../state/product_store.dart';
import '../state/sales_scope.dart';
import '../widgets/page_width.dart';
import '../widgets/surface_card.dart';
import 'add_products_screen.dart';
import 'product_form_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ProductScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available stock'),
        actions: [
          IconButton(
            key: const Key('stock-add-button'),
            onPressed: _openAddProducts,
            tooltip: 'Add products',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => store.products.isNotEmpty
                ? IconButton(
                    key: const Key('clear-stock-button'),
                    onPressed: _clearStock,
                    tooltip: 'Clear all stock',
                    color: AppColors.danger,
                    icon: const Icon(Icons.delete_forever_rounded),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final filtered = _filter(store.products);
            final textTheme = Theme.of(context).textTheme;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 36),
              child: PageWidth(
                maxWidth: 1120,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StockSummary(store: store),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('stock-search-field'),
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search by product, product ID or serial no.',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _clearSearch,
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _countLabel(store, filtered),
                            style: textTheme.titleSmall,
                          ),
                        ),
                        if (store.products.isNotEmpty)
                          Text(
                            'Sorted by serial no.',
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (store.products.isEmpty)
                      _EmptyStock(onAdd: _openAddProducts)
                    else if (filtered.isEmpty)
                      _NoSearchResults(query: _query, onClear: _clearSearch)
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 820) {
                            return Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < filtered.length;
                                  index++
                                ) ...[
                                  if (index > 0) const SizedBox(height: 12),
                                  _StockMobileTile(
                                    product: filtered[index],
                                    onManage: () =>
                                        _openManager(filtered[index]),
                                  ),
                                ],
                              ],
                            );
                          }

                          return _StockTable(
                            products: filtered,
                            onManage: _openManager,
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Product> _filter(List<Product> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return products;

    return products
        .where((product) {
          return product.particulars.toLowerCase().contains(query) ||
              product.id.toLowerCase().contains(query) ||
              product.serialNo.toString() == query;
        })
        .toList(growable: false);
  }

  String _countLabel(ProductStore store, List<Product> filtered) {
    if (store.products.isEmpty) return 'Your stock';
    if (_query.trim().isEmpty) {
      return store.products.length == 1
          ? '1 product in stock'
          : '${store.products.length} products in stock';
    }
    return '${filtered.length} of ${store.products.length} shown';
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _openAddProducts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddProductsScreen()),
    );
  }

  Future<void> _openManager(Product product) async {
    final result = await Navigator.of(context).push<ProductFormResult>(
      MaterialPageRoute<ProductFormResult>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
    if (!mounted || result == null) return;

    if (result.isDeleted) {
      showBriefSnackBar(context, '${result.deleted!.id} deleted from stock.');
      return;
    }
    showBriefSnackBar(context, '${result.saved!.id} updated.');
  }

  Future<void> _clearStock() async {
    final store = ProductScope.of(context);
    final salesStore = SalesScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ClearStockDialog(productCount: store.products.length),
    );
    if (confirmed != true || !mounted) return;

    final count = await store.clearProducts();
    await salesStore.clearBill();
    if (!mounted) return;

    showBriefSnackBar(
      context,
      count == 1
          ? '1 product cleared from stock.'
          : '$count products cleared from stock.',
    );
  }
}

class _StockSummary extends StatelessWidget {
  const _StockSummary({required this.store});

  final ProductStore store;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Total products',
                    value: store.products.length.toString(),
                    compact: compact,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _SummaryStat(
                    label: compact ? 'Units' : 'Units in stock',
                    value: formatQuantity(store.totalQuantity),
                    compact: compact,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _SummaryStat(
                    label: 'Stock value',
                    value: formatMoney(store.stockValue),
                    shortValue: formatCompactMoney(store.stockValue),
                    compact: compact,
                    highlight: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClearStockDialog extends StatefulWidget {
  const _ClearStockDialog({required this.productCount});

  final int productCount;

  @override
  State<_ClearStockDialog> createState() => _ClearStockDialogState();
}

class _ClearStockDialogState extends State<_ClearStockDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text(
        'Clear all stock?',
        style: TextStyle(color: AppColors.danger),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete ${widget.productCount} product(s) '
            'from your stock.',
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
                    'WARNING: Once the stock is completely deleted, you '
                    'cannot retreat or recover that stock data. Past sales '
                    'and bills will remain in your sales history.',
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
                key: const Key('clear-stock-understood-checkbox'),
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
          key: const Key('confirm-clear-stock-button'),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Delete all stock'),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.compact,
    this.shortValue,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? shortValue;
  final bool compact;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final displayed = compact ? (shortValue ?? value) : value;

    return Tooltip(
      message: value,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 20,
          vertical: compact ? 16 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayed,
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 19 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: highlight ? AppColors.primaryDark : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({required this.products, required this.onManage});

  final List<Product> products;
  final ValueChanged<Product> onManage;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _StockTableHeader(),
          for (var index = 0; index < products.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 20, endIndent: 20),
            _StockTableRow(
              product: products[index],
              onManage: () => onManage(products[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockTableHeader extends StatelessWidget {
  const _StockTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFFAFBF8),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('S.NO', style: style)),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: Text('PARTICULARS', style: style)),
          Expanded(
            flex: 2,
            child: Text('RATE', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text('QTY', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text('TOTAL', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text('ACTION', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _StockTableRow extends StatelessWidget {
  const _StockTableRow({required this.product, required this.onManage});

  final Product product;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onManage,
      hoverColor: AppColors.softGreen.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                product.serialNo.toString(),
                style: textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.particulars,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  _CodeChip(text: product.id),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatMoney(product.rate),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatQuantity(product.quantity),
                textAlign: TextAlign.right,
                maxLines: 1,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatMoney(product.total),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('manage-${product.id}'),
                  onPressed: onManage,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Manage'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockMobileTile extends StatelessWidget {
  const _StockMobileTile({required this.product, required this.onManage});

  final Product product;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'S.NO',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 7.5,
                        letterSpacing: 0.6,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      product.serialNo.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.particulars,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    _CodeChip(text: product.id),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MobileMetric(
                      label: 'RATE',
                      value: formatMoney(product.rate),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _MobileMetric(
                      label: 'QUANTITY',
                      value: formatQuantity(product.quantity),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _MobileMetric(
                      label: 'TOTAL',
                      value: formatMoney(product.total),
                      highlight: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Updated ${formatDate(product.updatedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                key: Key('manage-${product.id}'),
                onPressed: onManage,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Manage product'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileMetric extends StatelessWidget {
  const _MobileMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontSize: 9, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primaryDark : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStock extends StatelessWidget {
  const _EmptyStock({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No products in stock yet',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'Add your first product manually, or import your full product '
              'list from an Excel sheet.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add products'),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(
            'No products match “${query.trim()}”',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different product name, product ID or serial number.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onClear, child: const Text('Clear search')),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5EF),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

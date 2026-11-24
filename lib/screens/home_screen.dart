import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../state/product_scope.dart';
import '../state/product_store.dart';
import '../state/sales_scope.dart';
import '../state/sales_store.dart';
import '../widgets/app_logo.dart';
import '../widgets/page_width.dart';
import '../widgets/surface_card.dart';
import 'add_products_screen.dart';
import 'bill_screen.dart';
import 'sales_history_screen.dart';
import 'stock_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProductScope.of(context);
    final salesStore = SalesScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: salesStore,
              builder: (context, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: PageWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),
                        const _HomeHeader(),
                        const SizedBox(height: 20),
                        const _HeroCopy(),
                        const SizedBox(height: 18),
                        _StatsPanel(store: store),
                        const SizedBox(height: 22),
                        Text(
                          'Quick actions',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _ActionGrid(
                          store: store,
                          salesStore: salesStore,
                          onViewStock: () =>
                              _open(context, const StockScreen()),
                          onAddProducts: () =>
                              _open(context, const AddProductsScreen()),
                          onSell: () => _open(context, const BillScreen()),
                        ),
                        const SizedBox(height: 20),
                        _SalesSnapshot(
                          salesStore: salesStore,
                          onViewAll: () =>
                              _open(context, const SalesHistoryScreen()),
                        ),
                        const SizedBox(height: 16),
                        const _SavedLocallyNote(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            const AppLogo(size: 40),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mano Agency',
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text('Inventory & billing', style: textTheme.bodySmall),
              ],
            ),
            const Spacer(),
            if (constraints.maxWidth >= 460) const _SavedPill(),
          ],
        );
      },
    );
  }
}

class _SavedPill extends StatelessWidget {
  const _SavedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E6CF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.primary),
          SizedBox(width: 6),
          Text(
            'Saved locally',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your shop, in order.',
              style: compact
                  ? textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    )
                  : textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Add stock, keep quantities accurate and create bills in one '
                  'place.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.store});

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
                  child: _Stat(
                    label: 'Products',
                    value: store.products.length.toString(),
                    compact: compact,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Stat(
                    label: compact ? 'Units' : 'Units in stock',
                    value: formatQuantity(store.totalQuantity),
                    compact: compact,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Stat(
                    label: 'Stock value',
                    value: formatMoney(store.stockValue),
                    shortValue: formatCompactMoney(store.stockValue),
                    compact: compact,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.compact,
    this.shortValue,
  });

  final String label;
  final String value;
  final String? shortValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayed = compact ? (shortValue ?? value) : value;

    return Tooltip(
      message: value,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: compact ? 12 : 18,
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
                  ?.copyWith(letterSpacing: 0.7, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayed,
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 17 : 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.store,
    required this.salesStore,
    required this.onViewStock,
    required this.onAddProducts,
    required this.onSell,
  });

  final ProductStore store;
  final SalesStore salesStore;
  final VoidCallback onViewStock;
  final VoidCallback onAddProducts;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final stockTile = _CompactActionTile(
      icon: Icons.inventory_2_rounded,
      iconBackground: AppColors.softGreen,
      iconColor: AppColors.primary,
      title: 'View available stock',
      detail: store.isEmpty
          ? 'No products yet'
          : '${store.products.length} products · ${formatMoney(store.stockValue)}',
      onTap: onViewStock,
      actionKey: const Key('home-view-stock'),
    );

    final addTile = _CompactActionTile(
      icon: Icons.add_box_rounded,
      iconBackground: AppColors.softLime,
      iconColor: const Color(0xFF4E7A21),
      title: 'Add products to stock',
      detail: 'Manual entry or Excel import',
      onTap: onAddProducts,
      actionKey: const Key('home-add-products'),
    );

    final sellCard = _ActionCard(
      icon: Icons.receipt_long_rounded,
      iconBackground: const Color(0xFFEDF1FA),
      iconColor: const Color(0xFF315B9A),
      title: 'Sell products / create a bill',
      description:
          'Build a bill with + buttons or an Excel list, then print or save '
          'a PDF. Selling updates stock automatically.',
      footnote: salesStore.saleCount == 0
          ? (store.isEmpty ? 'Add stock before selling' : 'Ready to sell')
          : '${salesStore.saleCount} sale(s) · ${formatMoney(salesStore.totalSales)} sold',
      onTap: onSell,
      actionKey: const Key('home-sell-products'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              stockTile,
              const SizedBox(height: 10),
              addTile,
              const SizedBox(height: 14),
              sellCard,
            ],
          );
        }

        if (constraints.maxWidth < 1040) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: stockTile),
                    const SizedBox(width: 12),
                    Expanded(child: addTile),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              sellCard,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 350,
                child: Column(
                  children: [
                    Expanded(child: stockTile),
                    const SizedBox(height: 10),
                    Expanded(child: addTile),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: sellCard),
            ],
          ),
        );
      },
    );
  }
}

class _CompactActionTile extends StatelessWidget {
  const _CompactActionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.onTap,
    required this.actionKey,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final Key actionKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      key: actionKey,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _SalesSnapshot extends StatelessWidget {
  const _SalesSnapshot({required this.salesStore, required this.onViewAll});

  final SalesStore salesStore;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales overview',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const Key('home-view-sales'),
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = [
                _SalesStat(
                  label: 'Today',
                  value: formatCompactMoney(salesStore.soldToday),
                  detail:
                      '${salesStore.salesSince(salesStore.startOfToday)} bill(s)',
                ),
                _SalesStat(
                  label: 'This week',
                  value: formatCompactMoney(salesStore.soldThisWeek),
                  detail:
                      '${salesStore.salesSince(salesStore.startOfWeek)} bill(s)',
                ),
                _SalesStat(
                  label: 'This month',
                  value: formatCompactMoney(salesStore.soldThisMonth),
                  detail:
                      '${salesStore.salesSince(salesStore.startOfMonth)} bill(s)',
                ),
              ];

              final gap = constraints.maxWidth < 620 ? 8.0 : 20.0;
              return Row(
                children: [
                  for (var index = 0; index < stats.length; index++) ...[
                    if (index > 0) SizedBox(width: gap),
                    Expanded(child: stats[index]),
                  ],
                ],
              );
            },
          ),
          if (salesStore.recentSales.isEmpty) ...[
            const SizedBox(height: 10),
            Text('No sales recorded yet.', style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SalesStat extends StatelessWidget {
  const _SalesStat({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 0.7,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.footnote,
    required this.onTap,
    required this.actionKey,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String description;
  final String footnote;
  final VoidCallback onTap;
  final Key actionKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      key: actionKey,
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  size: 17,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  footnote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedLocallyNote extends StatelessWidget {
  const _SavedLocallyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: AppColors.muted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Saved privately on this device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

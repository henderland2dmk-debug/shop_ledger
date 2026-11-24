import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/core/app_theme.dart';
import 'package:shop_ledger/screens/customer_bills_screen.dart';
import 'package:shop_ledger/screens/sales_history_screen.dart';
import 'package:shop_ledger/state/product_scope.dart';
import 'package:shop_ledger/state/product_store.dart';
import 'package:shop_ledger/state/sales_scope.dart';
import 'package:shop_ledger/state/sales_store.dart';

Widget wrap(ProductStore store, SalesStore salesStore, Widget screen) {
  return ProductScope(
    store: store,
    child: SalesScope(
      store: salesStore,
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
}

void setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('sales history clears only after the warning is confirmed', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(900, 1000));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    final salesStore = SalesStore(preferences);
    final product = await store.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 3,
    );
    await salesStore.addToBill(product, quantity: 2);
    await salesStore.commitSale(productStore: store);

    await tester.pumpWidget(
      wrap(store, salesStore, const SalesHistoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No sales yet'), findsNothing);
    expect(find.byKey(const Key('clear-sales-history-button')), findsOneWidget);
    expect(find.textContaining('cannot retreat or recover'), findsNothing);

    await tester.tap(find.byKey(const Key('clear-sales-history-button')));
    await tester.pumpAndSettle();

    expect(find.text('Clear sales history?'), findsOneWidget);
    expect(
      find.textContaining('cannot retreat or recover those bills'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-clear-sales-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('clear-sales-understood-checkbox')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-clear-sales-button')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('confirm-clear-sales-button')));
    await tester.pumpAndSettle();

    expect(salesStore.sales, isEmpty);
    expect(salesStore.totalSales, 0);
    expect(store.products.single.quantity, 1);
    expect(find.text('No sales yet'), findsOneWidget);
    expect(find.byKey(const Key('clear-sales-history-button')), findsNothing);
  });

  testWidgets('a wrong bill can be discarded from its card', (tester) async {
    setSurfaceSize(tester, const Size(900, 1200));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    final salesStore = SalesStore(preferences);
    final product = await store.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 5,
    );
    await salesStore.addToBill(product, quantity: 2);
    final sale = await salesStore.commitSale(productStore: store);
    expect(store.products.single.quantity, 3);

    await tester.pumpWidget(
      wrap(store, salesStore, const SalesHistoryScreen()),
    );
    await tester.pumpAndSettle();

    final discard = find.byKey(Key('discard-bill-${sale!.id}'));
    await tester.ensureVisible(discard);
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be undone'), findsNothing);

    await tester.tap(discard);
    await tester.pumpAndSettle();

    expect(find.text('Discard this bill?'), findsOneWidget);
    expect(find.textContaining('added back to stock'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-discard-bill-button')));
    await tester.pumpAndSettle();

    expect(salesStore.sales, isEmpty);
    expect(salesStore.totalSales, 0);
    expect(store.products.single.quantity, 5);
    expect(find.text('No sales yet'), findsOneWidget);
    expect(find.byKey(Key('discard-bill-${sale.id}')), findsNothing);
  });

  test('sales are grouped under normalised customer names', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    final salesStore = SalesStore(preferences);
    final product = await store.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 10,
    );

    for (final customer in ['Ramesh Kumar', 'ramesh  kumar', 'Sita Devi']) {
      await salesStore.setCustomerName(customer);
      await salesStore.addToBill(product, quantity: 1);
      await salesStore.commitSale(productStore: store);
    }

    final groups = salesStore.customerBillGroups;
    expect(groups, hasLength(2));
    expect(groups.map((group) => group.customerName), contains('Ramesh Kumar'));
    expect(groups.map((group) => group.customerName), contains('Sita Devi'));
    expect(
      groups
          .firstWhere((group) => group.customerName == 'Ramesh Kumar')
          .billCount,
      2,
    );
    expect(salesStore.customerNames, contains('Ramesh Kumar'));
  });

  testWidgets(
    'history groups by customer, searches and opens all their bills',
    (tester) async {
      setSurfaceSize(tester, const Size(900, 1500));
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ProductStore(preferences);
      final salesStore = SalesStore(preferences);
      final product = await store.addProduct(
        particulars: 'Soap',
        rate: 10,
        quantity: 10,
      );

      Future<String> sell(String customer) async {
        await salesStore.setCustomerName(customer);
        await salesStore.addToBill(product, quantity: 1);
        final sale = await salesStore.commitSale(productStore: store);
        return sale!.id;
      }

      final oldRameshBill = await sell('Ramesh Kumar');
      await sell('Sita Devi');
      final latestRameshBill = await sell('Ramesh Kumar');

      await tester.pumpWidget(
        wrap(store, salesStore, const SalesHistoryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer bills'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Sita Devi'), findsOneWidget);
      expect(find.text(oldRameshBill), findsNothing);
      expect(find.text(latestRameshBill), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('sales-customer-search-field')),
        'Sita',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sita Devi'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNothing);

      await tester.tap(find.byKey(const Key('clear-customer-search')));
      await tester.pumpAndSettle();

      final viewAll = find.byKey(const Key('view-customer-bills-ramesh-kumar'));
      await tester.ensureVisible(viewAll);
      await tester.pumpAndSettle();
      await tester.tap(viewAll);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerBillsScreen), findsOneWidget);
      expect(find.text(oldRameshBill), findsOneWidget);
      expect(find.text(latestRameshBill), findsOneWidget);
      expect(find.text('Sita Devi'), findsNothing);
    },
  );
}

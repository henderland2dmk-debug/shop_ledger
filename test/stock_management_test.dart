import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/core/app_theme.dart';
import 'package:shop_ledger/core/snackbars.dart';
import 'package:shop_ledger/screens/stock_screen.dart';
import 'package:shop_ledger/state/product_scope.dart';
import 'package:shop_ledger/state/product_store.dart';
import 'package:shop_ledger/state/sales_scope.dart';
import 'package:shop_ledger/state/sales_store.dart';

Future<(ProductStore, SalesStore)> createStores() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return (ProductStore(preferences), SalesStore(preferences));
}

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
  testWidgets('a product can be deleted from its manage screen', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(900, 1000));
    final (store, salesStore) = await createStores();
    final product = await store.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 5,
    );
    await salesStore.addToBill(product, quantity: 2);

    await tester.pumpWidget(wrap(store, salesStore, const StockScreen()));
    await tester.pumpAndSettle();

    final manage = find.byKey(Key('manage-${product.id}'));
    await tester.ensureVisible(manage);
    await tester.pumpAndSettle();
    await tester.tap(manage);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-product-button')), findsOneWidget);
    expect(find.text('Danger zone'), findsNothing);
    expect(find.textContaining('cannot recover it afterwards'), findsNothing);

    await tester.tap(find.byKey(const Key('delete-product-button')));
    await tester.pumpAndSettle();

    expect(find.text('Delete product?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsWidgets);
    expect(
      find.byKey(const Key('confirm-delete-product-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirm-delete-product-button')));
    await tester.pumpAndSettle();

    expect(store.products, isEmpty);
    expect(salesStore.draftItems, isEmpty);
    expect(find.text('No products in stock yet'), findsOneWidget);
    expect(find.byKey(const Key('clear-stock-button')), findsNothing);
  });

  testWidgets('clearing stock warns first and needs an acknowledgement', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(900, 1000));
    final (store, salesStore) = await createStores();
    await store.addProduct(particulars: 'Soap', rate: 10);
    await store.addProduct(particulars: 'Rice', rate: 60);
    await salesStore.setCustomerName('Test customer');
    await salesStore.addToBill(store.products.first);

    await tester.pumpWidget(wrap(store, salesStore, const StockScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear-stock-button')), findsOneWidget);
    expect(find.text('Clear all stock'), findsNothing);
    expect(
      find.textContaining('cannot undo this or recover the stock data'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('clear-stock-button')));
    await tester.pumpAndSettle();

    expect(find.text('Clear all stock?'), findsOneWidget);
    expect(
      find.textContaining('cannot retreat or recover that stock data'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-clear-stock-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('clear-stock-understood-checkbox')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-clear-stock-button')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('confirm-clear-stock-button')));
    await tester.pumpAndSettle();

    expect(store.products, isEmpty);
    expect(salesStore.draftItems, isEmpty);
    expect(salesStore.draftCustomerName, isEmpty);
    expect(find.text('No products in stock yet'), findsOneWidget);
    expect(find.byKey(const Key('clear-stock-button')), findsNothing);
  });

  testWidgets('brief snack bars disappear on their own', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('show-message'),
              onPressed: () => showBriefSnackBar(context, 'Saved.'),
              child: const Text('Show message'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('show-message')));
    await tester.pump();

    expect(find.text('Saved.'), findsOneWidget);
    expect(briefSnackBarDuration, const Duration(seconds: 2));

    // Advance in small steps so the SnackBar timer is given a chance to fire.
    for (var step = 0; step < 30; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.text('Saved.'), findsNothing);
  });
}

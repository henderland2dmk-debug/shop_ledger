import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/app.dart';
import 'package:shop_ledger/state/product_store.dart';
import 'package:shop_ledger/state/sales_store.dart';

Future<(ProductStore, SalesStore)> createStores() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return (ProductStore(preferences), SalesStore(preferences));
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
  testWidgets('home shows both options and opens an empty stock page', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(390, 844));
    final (store, salesStore) = await createStores();

    await tester.pumpWidget(
      ShopLedgerApp(store: store, salesStore: salesStore),
    );
    await tester.pumpAndSettle();

    expect(find.text('View available stock'), findsOneWidget);
    expect(find.text('Add products to stock'), findsOneWidget);

    final viewStock = find.byKey(const Key('home-view-stock'));
    await tester.ensureVisible(viewStock);
    await tester.pumpAndSettle();
    await tester.tap(viewStock);
    await tester.pumpAndSettle();

    expect(find.text('Available stock'), findsOneWidget);
    expect(find.text('No products in stock yet'), findsOneWidget);
    expect(find.text('Add products'), findsOneWidget);
  });

  testWidgets('a product can be added manually with automatic defaults', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(900, 1200));
    final (store, salesStore) = await createStores();

    await tester.pumpWidget(
      ShopLedgerApp(store: store, salesStore: salesStore),
    );
    await tester.pumpAndSettle();

    final addProducts = find.byKey(const Key('home-add-products'));
    await tester.ensureVisible(addProducts);
    await tester.pumpAndSettle();
    await tester.tap(addProducts);
    await tester.pumpAndSettle();

    expect(find.text('Build your stock list'), findsOneWidget);

    final manualAdd = find.byKey(const Key('manual-add-button'));
    await tester.ensureVisible(manualAdd);
    await tester.pumpAndSettle();
    await tester.tap(manualAdd);
    await tester.pumpAndSettle();

    expect(find.text('New product'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-product-button')));
    await tester.pumpAndSettle();
    expect(find.text('Particulars is required'), findsOneWidget);
    expect(find.text('Rate is required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('particulars-field')),
      'Detergent powder',
    );
    await tester.enterText(find.byKey(const Key('rate-field')), '125.50');
    await tester.enterText(find.byKey(const Key('quantity-field')), '2');
    await tester.pump();

    expect(find.text('₹251.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-product-button')));
    await tester.pumpAndSettle();

    expect(store.products, hasLength(1));
    expect(store.products.single.id, 'PRD-0001');
    expect(store.products.single.quantity, 2);
    expect(store.products.single.total, 251);
    expect(find.text('“Detergent powder” added as PRD-0001.'), findsOneWidget);

    final viewStock = find.byKey(const Key('recent-view-stock'));
    await tester.ensureVisible(viewStock);
    await tester.pumpAndSettle();
    await tester.tap(viewStock);
    await tester.pumpAndSettle();

    expect(find.text('Available stock'), findsOneWidget);
    expect(find.text('Detergent powder'), findsOneWidget);
    expect(find.text('PRD-0001'), findsWidgets);
  });

  testWidgets('rate and quantity can be managed from the stock list', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(1200, 1000));
    final (store, salesStore) = await createStores();
    await store.addProduct(particulars: 'Sunflower oil', rate: 50, quantity: 2);

    await tester.pumpWidget(
      ShopLedgerApp(store: store, salesStore: salesStore),
    );
    await tester.pumpAndSettle();

    final viewStock = find.byKey(const Key('home-view-stock'));
    await tester.ensureVisible(viewStock);
    await tester.pumpAndSettle();
    await tester.tap(viewStock);
    await tester.pumpAndSettle();

    expect(find.text('Sunflower oil'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manage-PRD-0001')));
    await tester.pumpAndSettle();

    expect(find.text('Manage product'), findsOneWidget);
    expect(find.text('PRODUCT ID'), findsOneWidget);
    expect(find.text('PRD-0001'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('rate-field')), '150');
    await tester.enterText(find.byKey(const Key('quantity-field')), '3');
    await tester.tap(find.byKey(const Key('save-product-button')));
    await tester.pumpAndSettle();

    expect(store.products.single.rate, 150);
    expect(store.products.single.quantity, 3);
    expect(store.products.single.total, 450);
    expect(find.text('PRD-0001 updated.'), findsOneWidget);
    expect(find.text('₹450.00'), findsWidgets);
  });
}

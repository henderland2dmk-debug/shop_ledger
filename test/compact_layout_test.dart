import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/core/app_theme.dart';
import 'package:shop_ledger/screens/add_products_screen.dart';
import 'package:shop_ledger/screens/home_screen.dart';
import 'package:shop_ledger/screens/product_form_screen.dart';
import 'package:shop_ledger/screens/stock_screen.dart';
import 'package:shop_ledger/services/excel_import_service.dart';
import 'package:shop_ledger/state/product_scope.dart';
import 'package:shop_ledger/state/product_store.dart';
import 'package:shop_ledger/state/sales_scope.dart';
import 'package:shop_ledger/state/sales_store.dart';
import 'package:shop_ledger/widgets/import_preview_dialog.dart';

Future<(ProductStore, SalesStore)> createStoreWithProduct() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = ProductStore(preferences);
  await store.addProduct(
    particulars: 'A very long product name that should wrap on a phone',
    rate: 123456.5,
    quantity: 1234.5,
  );
  return (store, SalesStore(preferences));
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
  testWidgets('home, add, stock and manage screens fit a small phone', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(360, 800));
    final (store, salesStore) = await createStoreWithProduct();

    await tester.pumpWidget(wrap(store, salesStore, const HomeScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(store, salesStore, const AddProductsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Recently added'), findsOneWidget);

    final product = store.products.single;
    await tester.pumpWidget(wrap(store, salesStore, const StockScreen()));
    await tester.pumpAndSettle();
    expect(find.text(product.particulars), findsOneWidget);
    expect(find.text('Manage product'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      wrap(store, salesStore, ProductFormScreen(product: product)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manage product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import preview dialog fits a small phone', (tester) async {
    setSurfaceSize(tester, const Size(360, 800));

    final result = ImportResult(
      fileName: 'a-very-long-file-name-for-the-shop-stock.xlsx',
      rows: [
        ImportRow(
          sourceRow: 2,
          particulars: 'A very long product name that needs to wrap nicely',
          rate: 123456.5,
          quantity: 12.5,
          total: null,
          serialNo: 1,
          errors: const [],
        ),
        ImportRow(
          sourceRow: 3,
          particulars: 'Tea',
          rate: 250.5,
          quantity: null,
          total: null,
          serialNo: 2,
          errors: const [],
        ),
        const ImportRow(
          sourceRow: 4,
          particulars: 'Missing rate',
          rate: null,
          quantity: null,
          total: null,
          serialNo: null,
          errors: ['Rate is required'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ImportPreviewDialog(result: result)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review import'), findsOneWidget);
    expect(find.text('2 products ready'), findsOneWidget);
    expect(find.textContaining('1 row will be skipped'), findsOneWidget);
    expect(find.textContaining('Row 4: Rate is required'), findsOneWidget);
    expect(find.byKey(const Key('confirm-import-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

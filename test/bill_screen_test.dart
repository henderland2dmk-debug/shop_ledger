import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/core/app_theme.dart';
import 'package:shop_ledger/screens/bill_screen.dart';
import 'package:shop_ledger/state/product_scope.dart';
import 'package:shop_ledger/state/product_store.dart';
import 'package:shop_ledger/state/sales_scope.dart';
import 'package:shop_ledger/state/sales_store.dart';

void setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('repeated + taps build a bill and selling updates stock', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final products = ProductStore(preferences);
    final sales = SalesStore(preferences);
    await products.addProduct(particulars: 'Soap', rate: 10, quantity: 3);

    await tester.pumpWidget(
      ProductScope(
        store: products,
        child: SalesScope(
          store: sales,
          child: MaterialApp(theme: AppTheme.light, home: const BillScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Build a sale bill'), findsOneWidget);

    final addButton = find.byKey(const Key('bill-add-PRD-0001'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(sales.draftQuantity, 2);
    expect(sales.draftTotal, 20);
    expect(find.text('₹20.00'), findsWidgets);

    final sellButton = find.byKey(const Key('confirm-sale-button'));
    await tester.ensureVisible(sellButton);
    await tester.tap(sellButton);
    await tester.pumpAndSettle();

    expect(find.text('Confirm sale'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-sale-dialog-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sale completed'), findsOneWidget);
    expect(products.products.single.quantity, 1);
    expect(sales.saleCount, 1);
    expect(sales.draftItems, isEmpty);
  });

  testWidgets('previous customers can be selected from the customer field', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(900, 1100));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final products = ProductStore(preferences);
    final sales = SalesStore(preferences);
    final product = await products.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 5,
    );

    await sales.setCustomerName('Ramesh Kumar');
    await sales.addToBill(product, quantity: 1);
    await sales.commitSale(productStore: products);

    await tester.pumpWidget(
      ProductScope(
        store: products,
        child: SalesScope(
          store: sales,
          child: MaterialApp(theme: AppTheme.light, home: const BillScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('bill-customer-picker'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();

    expect(find.text('Previous customers'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('bill-customer-option-ramesh-kumar')),
    );
    await tester.pumpAndSettle();

    final customerField = tester.widget<TextField>(
      find.byKey(const Key('bill-customer-field')),
    );
    expect(customerField.controller?.text, 'Ramesh Kumar');
    expect(sales.draftCustomerName, 'Ramesh Kumar');
  });
}

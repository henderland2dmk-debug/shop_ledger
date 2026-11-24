import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/state/product_store.dart';
import 'package:shop_ledger/state/sales_store.dart';

Future<(ProductStore, SalesStore)> createStores() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return (ProductStore(preferences), SalesStore(preferences));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a completed bill reduces stock and appears in sales history', () async {
    final (products, sales) = await createStores();
    final product = await products.addProduct(
      particulars: 'Sugar',
      rate: 50,
      quantity: 5,
    );

    await sales.addToBill(product, quantity: 2);
    await sales.setCustomerName('Ramesh');
    final sale = await sales.commitSale(productStore: products);

    expect(sale, isNotNull);
    expect(sale!.id, 'BILL-0001');
    expect(sale.customerName, 'Ramesh');
    expect(sale.totalAmount, 100);
    expect(sales.sales, hasLength(1));
    expect(sales.totalSales, 100);
    expect(sales.soldToday, 100);
    expect(sales.unitsToday, 2);
    expect(sales.draftItems, isEmpty);
    expect(products.products.single.quantity, 3);
    expect(products.products.single.total, 150);
  });

  test('clearing sales persists and never reuses a bill number', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final products = ProductStore(preferences);
    final sales = SalesStore(preferences);
    final product = await products.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 3,
    );

    await sales.addToBill(product, quantity: 1);
    await sales.commitSale(productStore: products);

    final count = await sales.clearSales();

    expect(count, 1);
    expect(sales.sales, isEmpty);
    expect(sales.totalSales, 0);

    final reloaded = SalesStore(preferences);
    expect(reloaded.sales, isEmpty);
    expect(reloaded.saleCount, 0);

    await sales.addToBill(product, quantity: 1);
    final next = await sales.commitSale(productStore: products);
    expect(next?.id, 'BILL-0002');
  });

  test('discarding a bill restores stock and removes it from totals', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final products = ProductStore(preferences);
    final sales = SalesStore(preferences);
    final product = await products.addProduct(
      particulars: 'Sugar',
      rate: 50,
      quantity: 5,
    );

    await sales.addToBill(product, quantity: 2);
    final sale = await sales.commitSale(productStore: products);
    expect(sale, isNotNull);
    expect(products.products.single.quantity, 3);
    expect(products.products.single.total, 150);

    final discarded = await sales.discardSale(
      saleId: sale!.id,
      productStore: products,
    );

    expect(discarded?.id, 'BILL-0001');
    expect(sales.sales, isEmpty);
    expect(sales.totalSales, 0);
    expect(sales.unitsToday, 0);
    expect(products.products.single.quantity, 5);
    expect(products.products.single.total, 250);
    expect(products.products.single.id, product.id);
    expect(products.products.single.serialNo, product.serialNo);

    final reloadedSales = SalesStore(preferences);
    final reloadedProducts = ProductStore(preferences);
    expect(reloadedSales.sales, isEmpty);
    expect(reloadedProducts.products.single.quantity, 5);

    await sales.addToBill(product, quantity: 1);
    final next = await sales.commitSale(productStore: products);
    expect(next?.id, 'BILL-0002');
  });

  test(
    'discarding a bill recreates a product deleted after the sale',
    () async {
      final (products, sales) = await createStores();
      final product = await products.addProduct(
        particulars: 'Soap',
        rate: 10,
        quantity: 4,
      );
      await sales.addToBill(product, quantity: 2);
      final sale = await sales.commitSale(productStore: products);
      await products.deleteProduct(product.id);
      expect(products.products, isEmpty);

      await sales.discardSale(saleId: sale!.id, productStore: products);

      expect(products.products, hasLength(1));
      expect(products.products.single.id, product.id);
      expect(products.products.single.particulars, 'Soap');
      expect(products.products.single.quantity, 2);
      expect(products.products.single.total, 20);
    },
  );

  test('repeated taps merge into one bill line', () async {
    final (products, sales) = await createStores();
    final product = await products.addProduct(
      particulars: 'Tea',
      rate: 20,
      quantity: 5,
    );

    await sales.addToBill(product);
    await sales.addToBill(product);
    await sales.addToBill(product);

    expect(sales.draftItems, hasLength(1));
    expect(sales.draftQuantity, 3);
    expect(sales.draftTotal, 60);
  });
}

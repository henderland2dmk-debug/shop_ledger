import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/models/bill_item.dart';
import 'package:shop_ledger/models/product_draft.dart';
import 'package:shop_ledger/state/product_store.dart';

Future<ProductStore> createStore() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ProductStore(preferences);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'adds products with automatic quantity, totals and identifiers',
    () async {
      final store = await createStore();

      final first = await store.addProduct(particulars: 'Soap', rate: 40);
      expect(first.id, 'PRD-0001');
      expect(first.serialNo, 1);
      expect(first.quantity, 1);
      expect(first.total, 40);

      final second = await store.addProduct(
        particulars: 'Cooking oil',
        rate: 180.5,
        quantity: 3,
      );
      expect(second.id, 'PRD-0002');
      expect(second.serialNo, 2);
      expect(second.total, 541.5);

      expect(store.products.length, 2);
      expect(store.stockValue, 581.5);
      expect(store.totalQuantity, 4);
    },
  );

  test('updates rate and quantity and recalculates the total', () async {
    final store = await createStore();
    final product = await store.addProduct(
      particulars: 'Rice',
      rate: 60,
      quantity: 2,
    );

    final updated = await store.updateProduct(
      id: product.id,
      particulars: 'Basmati rice',
      rate: 75,
      quantity: 4,
    );

    expect(updated, isNotNull);
    expect(updated!.particulars, 'Basmati rice');
    expect(updated.rate, 75);
    expect(updated.quantity, 4);
    expect(updated.total, 300);
    expect(updated.id, product.id);
    expect(updated.serialNo, product.serialNo);
  });

  test(
    'keeps imported serial numbers unique and totals when provided',
    () async {
      final store = await createStore();

      final added = await store.addProducts(const [
        ProductDraft(particulars: 'Sugar', rate: 50, quantity: 2, serialNo: 5),
        ProductDraft(particulars: 'Tea', rate: 200, serialNo: 5),
        ProductDraft(particulars: 'Salt', rate: 20, total: 25),
      ]);

      expect(added.map((product) => product.serialNo).toList(), [5, 6, 7]);
      expect(store.products.map((product) => product.serialNo).toList(), [
        5,
        6,
        7,
      ]);
      expect(added[0].total, 100);
      expect(added[1].quantity, 1);
      expect(added[2].total, 25);
      expect(added.map((product) => product.id).toSet().length, 3);
    },
  );

  test('products and the ID sequence survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    await store.addProduct(particulars: 'Flour', rate: 45, quantity: 2);

    final reloaded = ProductStore(preferences);
    expect(reloaded.products.length, 1);
    expect(reloaded.products.single.particulars, 'Flour');
    expect(reloaded.products.single.total, 90);

    final next = await reloaded.addProduct(particulars: 'Dal', rate: 120);
    expect(next.id, 'PRD-0002');
    expect(next.serialNo, 2);
  });

  test('ignores drafts without a particular or a valid rate', () async {
    final store = await createStore();

    final added = await store.addProducts(const [
      ProductDraft(particulars: '   ', rate: 50),
      ProductDraft(particulars: 'Good product', rate: 25),
    ]);

    expect(added.length, 1);
    expect(added.single.particulars, 'Good product');
  });

  test('matching products merge quantity and total without a new ID', () async {
    final store = await createStore();
    final first = await store.addProduct(
      particulars: 'Soap',
      rate: 40,
      quantity: 2,
    );

    final merged = await store.addProduct(
      particulars: '  SOAP  ',
      rate: 50,
      quantity: 3,
      total: 160,
    );

    expect(store.products, hasLength(1));
    expect(merged.id, first.id);
    expect(merged.serialNo, first.serialNo);
    expect(merged.quantity, 5);
    expect(merged.total, 240);
    expect(merged.rate, 48);
  });

  test('deleting one product persists and never reuses its ID', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    final first = await store.addProduct(particulars: 'Soap', rate: 10);
    final second = await store.addProduct(particulars: 'Rice', rate: 60);

    final removed = await store.deleteProduct(first.id);

    expect(removed?.id, first.id);
    expect(store.products.map((product) => product.id), [second.id]);
    expect(await store.deleteProduct(first.id), isNull);

    final reloaded = ProductStore(preferences);
    expect(reloaded.products.map((product) => product.id), [second.id]);

    final next = await reloaded.addProduct(particulars: 'Dal', rate: 120);
    expect(next.id, 'PRD-0003');
  });

  test('clearing stock persists and keeps the ID sequence', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    await store.addProduct(particulars: 'Soap', rate: 10);
    await store.addProduct(particulars: 'Rice', rate: 60);

    final count = await store.clearProducts();

    expect(count, 2);
    expect(store.isEmpty, isTrue);
    expect(store.stockValue, 0);
    expect(await store.clearProducts(), 0);

    final reloaded = ProductStore(preferences);
    expect(reloaded.isEmpty, isTrue);

    final next = await reloaded.addProduct(particulars: 'Dal', rate: 120);
    expect(next.id, 'PRD-0003');
  });

  test('selling removes exact quantities and blocks overselling', () async {
    final store = await createStore();
    final product = await store.addProduct(
      particulars: 'Soap',
      rate: 10,
      quantity: 5,
    );

    await store.sellProducts([BillItem.fromProduct(product, quantity: 2)]);

    final remaining = store.products.single;
    expect(remaining.quantity, 3);
    expect(remaining.total, 30);
    expect(remaining.rate, 10);

    expect(
      () => store.sellProducts([BillItem.fromProduct(product, quantity: 9)]),
      throwsA(isA<StockShortfallException>()),
    );
  });
}

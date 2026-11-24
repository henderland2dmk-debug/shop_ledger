import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_ledger/screens/ocr_review_screen.dart';
import 'package:shop_ledger/services/ocr/ocr_text_parser.dart';
import 'package:shop_ledger/state/product_store.dart';

void main() {
  testWidgets('scanned bill rows are edited separately and confirmed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProductStore(preferences);
    await store.addProduct(particulars: 'Soap', rate: 10, quantity: 3);
    final product = store.products.single;

    final row = OcrDraftRow(
      id: 'row-1',
      sourceLine: 1,
      particulars: 'Soap',
      rate: 10,
      quantity: 3,
      total: 30,
      productId: product.id,
    );
    List<OcrDraftRow>? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open-review'),
                onPressed: () async {
                  confirmed = await Navigator.of(context)
                      .push<List<OcrDraftRow>>(
                        MaterialPageRoute<List<OcrDraftRow>>(
                          builder: (_) => OcrReviewScreen(
                            mode: OcrReviewMode.bill,
                            rows: [row],
                            imageName: 'bill.jpg',
                            products: store.products,
                            existingBillQuantities: {product.id: 1},
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-review')));
    await tester.pumpAndSettle();

    expect(find.text('Review scanned bill'), findsOneWidget);
    expect(find.text('ROW 1'), findsOneWidget);
    expect(find.textContaining('Only 2 available'), findsOneWidget);

    final confirm = find.byKey(const Key('ocr-confirm-button'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    final quantityField = find.byKey(const Key('ocr-quantity-row-1'));
    await tester.ensureVisible(quantityField);
    await tester.enterText(quantityField, '2');
    await tester.pumpAndSettle();

    expect(find.textContaining('Only 2 available'), findsNothing);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed!.single.quantity, 2);
    expect(confirmed!.single.productId, product.id);
  });
}

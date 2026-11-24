import 'package:flutter_test/flutter_test.dart';
import 'package:shop_ledger/models/product.dart';
import 'package:shop_ledger/services/ocr/ocr_text_parser.dart';

Product product(String id, String name) {
  return Product(
    id: id,
    serialNo: 1,
    particulars: name,
    rate: 10,
    quantity: 5,
    total: 50,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  const parser = OcrTextParser();

  test('reads a headed bill in the expected column order', () {
    final result = parser.parse(
      'Mano Agency\n'
      'S.No Rate Particulars Qty Total\n'
      '1 120 Sugar 2 240\n'
      '2 250.50 Tea 1 ₹250.50\n'
      'Grand total 490.50',
      imageName: 'bill.jpg',
      products: [product('PRD-0001', 'Sugar')],
    );

    expect(result.headerDetected, isTrue);
    expect(result.rows, hasLength(2));
    expect(result.rows.first.particulars, 'Sugar');
    expect(result.rows.first.rate, 120);
    expect(result.rows.first.quantity, 2);
    expect(result.rows.first.total, 240);
    expect(result.rows.first.serialNo, 1);
    expect(result.rows.first.productId, 'PRD-0001');
    expect(result.rows.last.particulars, 'Tea');
    expect(result.rows.last.rate, 250.5);
    expect(result.rows.last.total, 250.5);
    expect(result.issueCount, 0);
  });

  test('reads unheaded rows with defaults and matches products', () {
    final result = parser.parse(
      'Soap 50 3 150\nDetergent 120 2',
      imageName: 'paper.png',
      products: [product('PRD-0002', 'soap')],
    );

    expect(result.headerDetected, isFalse);
    expect(result.rows, hasLength(2));
    expect(result.rows.first.particulars, 'Soap');
    expect(result.rows.first.productId, 'PRD-0002');
    expect(result.rows.first.rate, 50);
    expect(result.rows.first.quantity, 3);
    expect(result.rows.first.total, 150);
    expect(result.rows.last.particulars, 'Detergent');
    expect(result.rows.last.rate, 120);
    expect(result.rows.last.quantity, 2);
    expect(result.rows.last.total, isNull);
  });

  test('keeps product codes in the name and flags unreadable names', () {
    final result = parser.parse(
      'Rate Particulars Qty Total\n50 ABC 123 2 100\n4',
      imageName: 'codes.jpg',
    );

    expect(result.rows, hasLength(2));
    expect(result.rows.first.particulars, 'ABC 123');
    expect(result.rows.first.rate, 50);
    expect(result.rows.first.quantity, 2);
    expect(result.rows.first.total, 100);
    expect(result.rows.last.particulars, isEmpty);
    expect(result.rows.last.needsAttention, isTrue);
    expect(result.rows.last.note, contains('Name was not read'));
  });
}

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_ledger/models/bill_item.dart';
import 'package:shop_ledger/models/product.dart';
import 'package:shop_ledger/services/bill_import_service.dart';

Uint8List billSheetBytes(List<List<CellValue?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(excel.encode()!);
}

Product product({
  required String id,
  required int serialNo,
  required String particulars,
  required double rate,
  required double quantity,
}) {
  final now = DateTime.now();
  return Product(
    id: id,
    serialNo: serialNo,
    particulars: particulars,
    rate: rate,
    quantity: quantity,
    total: rate * quantity,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('matches stock rows and skips unknown or over-quantity rows', () {
    final bytes = billSheetBytes([
      [
        TextCellValue('Serial no'),
        TextCellValue('Rate'),
        TextCellValue('Particulars'),
        TextCellValue('Quantity'),
        TextCellValue('Total'),
      ],
      [
        IntCellValue(1),
        IntCellValue(50),
        TextCellValue('Sugar'),
        IntCellValue(2),
        IntCellValue(100),
      ],
      [
        IntCellValue(2),
        IntCellValue(20),
        TextCellValue('Tea'),
        IntCellValue(3),
        IntCellValue(60),
      ],
      [
        IntCellValue(3),
        IntCellValue(30),
        TextCellValue('Salt'),
        IntCellValue(1),
        IntCellValue(30),
      ],
    ]);

    final parsed = BillImportService(
      products: [
        product(
          id: 'PRD-0001',
          serialNo: 1,
          particulars: 'Sugar',
          rate: 50,
          quantity: 5,
        ),
        product(
          id: 'PRD-0002',
          serialNo: 2,
          particulars: 'Tea',
          rate: 20,
          quantity: 1,
        ),
      ],
      currentBill: [
        BillItem(
          productId: 'PRD-0001',
          serialNo: 1,
          particulars: 'Sugar',
          rate: 50,
          quantity: 2,
        ),
      ],
    ).parse(bytes, fileName: 'bill.xlsx');

    expect(parsed.itemCount, 1);
    expect(parsed.items.single.particulars, 'Sugar');
    expect(parsed.items.single.quantity, 2);
    expect(parsed.issueCount, 2);
    expect(
      parsed.issues.map((issue) => issue.reason),
      contains('Only 1 left in stock'),
    );
    expect(
      parsed.issues.map((issue) => issue.reason),
      contains('Not found in the current stock'),
    );
  });
}

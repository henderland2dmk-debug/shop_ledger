import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_ledger/services/excel_import_service.dart';

Uint8List workbookBytes(List<List<CellValue?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(excel.encode()!);
}

void main() {
  const service = ExcelImportService();

  test('reads the expected columns, applies defaults and flags bad rows', () {
    final bytes = workbookBytes([
      [
        TextCellValue('Serial no'),
        TextCellValue('Rate'),
        TextCellValue('Particulars'),
        TextCellValue('Quantity'),
        TextCellValue('Total'),
      ],
      [
        IntCellValue(1),
        IntCellValue(120),
        TextCellValue('Sugar'),
        IntCellValue(2),
        DoubleCellValue(240),
      ],
      [IntCellValue(2), TextCellValue('₹250.50'), TextCellValue('Tea')],
      [IntCellValue(3), null, TextCellValue('Missing rate')],
      [IntCellValue(4), IntCellValue(10), null],
    ]);

    final result = service.parse(bytes, fileName: 'stock.xlsx');

    expect(result.rows, hasLength(4));
    expect(result.validCount, 2);
    expect(result.invalidCount, 2);
    expect(result.validRows.first.particulars, 'Sugar');
    expect(result.validRows.first.rate, 120);
    expect(result.validRows.first.quantity, 2);
    expect(result.validRows.first.total, 240);
    expect(result.validRows.first.serialNo, 1);
    expect(result.validRows.last.particulars, 'Tea');
    expect(result.validRows.last.rate, 250.5);
    expect(result.validRows.last.quantity, isNull);
    expect(result.validRows.last.total, isNull);
    expect(result.invalidRows.first.errors, contains('Rate is required'));
    expect(result.invalidRows.last.errors, contains('Particulars is required'));
    expect(result.invalidRows.first.sourceRow, 4);
  });

  test('finds a header row below a title and accepts common aliases', () {
    final bytes = workbookBytes([
      [TextCellValue('My shop stock')],
      [
        TextCellValue('S.No'),
        TextCellValue('Price'),
        TextCellValue('Item'),
        TextCellValue('Qty'),
        TextCellValue('Amount'),
      ],
      [
        IntCellValue(7),
        DoubleCellValue(99.25),
        TextCellValue('Coffee'),
        IntCellValue(3),
        null,
      ],
    ]);

    final result = service.parse(bytes, fileName: 'aliases.xlsx');

    expect(result.validCount, 1);
    expect(result.validRows.single.particulars, 'Coffee');
    expect(result.validRows.single.rate, 99.25);
    expect(result.validRows.single.quantity, 3);
    expect(result.validRows.single.serialNo, 7);
    expect(result.validRows.single.calculatedTotal, 297.75);
  });

  test('accepts numbered headers from the requested format', () {
    final bytes = workbookBytes([
      [
        TextCellValue('1. Serial no'),
        TextCellValue('2. Rate'),
        TextCellValue('3. Particulars'),
        TextCellValue('4. Quantity'),
        TextCellValue('5. Total'),
      ],
      [
        IntCellValue(1),
        IntCellValue(80),
        TextCellValue('Brush'),
        IntCellValue(1),
        IntCellValue(80),
      ],
    ]);

    final result = service.parse(bytes, fileName: 'numbered.xlsx');

    expect(result.validCount, 1);
    expect(result.validRows.single.particulars, 'Brush');
    expect(result.validRows.single.serialNo, 1);
  });

  test('throws a friendly error when the header is missing', () {
    final bytes = workbookBytes([
      [TextCellValue('Sugar'), IntCellValue(100)],
    ]);

    expect(
      () => service.parse(bytes, fileName: 'bad.xlsx'),
      throwsA(isA<ImportException>()),
    );
  });

  test('throws a friendly error for an unreadable file', () {
    expect(
      () => service.parse(
        Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'broken.xlsx',
      ),
      throwsA(isA<ImportException>()),
    );
  });
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart';

/// A problem with the uploaded workbook that should be shown to the user.
class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One data row from the uploaded sheet.
class ImportRow {
  const ImportRow({
    required this.sourceRow,
    required this.particulars,
    required this.rate,
    required this.quantity,
    required this.total,
    required this.serialNo,
    required this.errors,
    this.productId,
  });

  /// Row number as it appears in Excel (1-based, including the header).
  final int sourceRow;

  final String particulars;
  final double? rate;
  final double? quantity;
  final double? total;
  final int? serialNo;
  final String? productId;
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  double get calculatedTotal => total ?? (rate ?? 0) * (quantity ?? 1);
}

/// Result of reading a product sheet.
class ImportResult {
  const ImportResult({required this.fileName, required this.rows});

  final String fileName;
  final List<ImportRow> rows;

  List<ImportRow> get validRows =>
      rows.where((row) => row.isValid).toList(growable: false);

  List<ImportRow> get invalidRows =>
      rows.where((row) => !row.isValid).toList(growable: false);

  int get validCount => validRows.length;

  int get invalidCount => invalidRows.length;
}

/// Reads product sheets with the columns: Serial no, Rate, Particulars,
/// Quantity and Total.
///
/// Only Particulars and Rate are mandatory. Missing quantity defaults to 1 and
/// a missing total is calculated when the product is stored.
class ExcelImportService {
  const ExcelImportService();

  static const expectedColumns = [
    'Serial no',
    'Rate',
    'Particulars',
    'Quantity',
    'Total',
  ];

  static const _aliases = <String, Set<String>>{
    'productId': {'product id', 'productid', 'id', 'code', 'sku'},
    'serialNo': {
      'serial no',
      'serial number',
      'serialno',
      's no',
      'sno',
      'sl no',
      'slno',
      'sr no',
      'srno',
      'no',
    },
    'rate': {'rate', 'price', 'unit rate', 'unit price', 'rate per unit'},
    'particulars': {
      'particulars',
      'particular',
      'particulars of goods',
      'product',
      'product name',
      'product particulars',
      'item',
      'item name',
      'item particulars',
      'description',
    },
    'quantity': {
      'quantity',
      'qty',
      'qty available',
      'available quantity',
      'stock',
      'stock qty',
      'available stock',
      'in stock',
    },
    'total': {
      'total',
      'amount',
      'total amount',
      'total price',
      'total value',
      'value',
    },
  };

  ImportResult parse(Uint8List bytes, {required String fileName}) {
    late final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const ImportException(
        'This file could not be read. Please upload a valid .xlsx workbook.',
      );
    }

    if (workbook.tables.isEmpty) {
      throw const ImportException('The workbook does not contain any sheets.');
    }

    ImportException? lastError;
    for (final sheet in workbook.tables.values) {
      if (sheet.rows.isEmpty) continue;
      try {
        final rows = _parseSheet(sheet);
        return ImportResult(fileName: fileName, rows: rows);
      } on ImportException catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        const ImportException(
          'The workbook is empty. Add your products below the header row and try again.',
        );
  }

  List<ImportRow> _parseSheet(Sheet sheet) {
    final rows = sheet.rows;

    _Header? header;
    var headerRowIndex = -1;
    final searchLimit = math.min(rows.length, 20);
    for (var index = 0; index < searchLimit; index++) {
      final detected = _detectHeader(rows[index]);
      if (detected != null) {
        header = detected;
        headerRowIndex = index;
        break;
      }
    }

    if (header == null) {
      throw const ImportException(
        'We could not find the required columns. The sheet needs a header row '
        'with Particulars and Rate (plus Serial no, Quantity and Total).',
      );
    }

    final parsedRows = <ImportRow>[];
    for (var index = headerRowIndex + 1; index < rows.length; index++) {
      final row = rows[index];
      final hasContent = row.any((cell) => _cellText(cell) != null);
      if (!hasContent) continue;
      parsedRows.add(_parseRow(row, header, index + 1));
    }

    if (parsedRows.isEmpty) {
      throw const ImportException(
        'No product rows were found below the header row.',
      );
    }

    return parsedRows;
  }

  _Header? _detectHeader(List<Data?> row) {
    final columnByField = <String, int>{};

    for (var column = 0; column < row.length; column++) {
      final label = _normalize(_cellText(row[column]));
      if (label.isEmpty) continue;

      for (final entry in _aliases.entries) {
        if (entry.value.contains(label) &&
            !columnByField.containsKey(entry.key)) {
          columnByField[entry.key] = column;
          break;
        }
      }
    }

    final particulars = columnByField['particulars'];
    final rate = columnByField['rate'];
    if (particulars == null || rate == null) return null;

    return _Header(
      particulars: particulars,
      rate: rate,
      productId: columnByField['productId'],
      serialNo: columnByField['serialNo'],
      quantity: columnByField['quantity'],
      total: columnByField['total'],
    );
  }

  ImportRow _parseRow(List<Data?> row, _Header header, int sourceRow) {
    final particulars =
        _cellText(_cellAt(row, header.particulars))?.trim() ?? '';
    final rateText = _cellText(_cellAt(row, header.rate));
    final rate = _parseNumber(rateText);
    final quantity = _parseOptionalNonNegative(
      _cellText(_cellAt(row, header.quantity)),
    );
    final total = _parseOptionalNonNegative(
      _cellText(_cellAt(row, header.total)),
    );

    final productIdText = _cellText(_cellAt(row, header.productId))?.trim();
    final productId = (productIdText == null || productIdText.isEmpty)
        ? null
        : productIdText;

    final serialValue = _parseNumber(_cellText(_cellAt(row, header.serialNo)))
        ?.round();
    final serialNo = (serialValue != null && serialValue > 0)
        ? serialValue
        : null;

    final errors = <String>[];
    if (particulars.isEmpty) {
      errors.add('Particulars is required');
    }
    if (rateText == null || rateText.trim().isEmpty) {
      errors.add('Rate is required');
    } else if (rate == null) {
      errors.add('Rate must be a number');
    } else if (rate < 0) {
      errors.add('Rate cannot be negative');
    }

    return ImportRow(
      sourceRow: sourceRow,
      particulars: particulars,
      rate: rate,
      quantity: quantity,
      total: total,
      serialNo: serialNo,
      productId: productId,
      errors: errors,
    );
  }

  static Data? _cellAt(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return row[index];
  }

  static String? _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null || value is FormulaCellValue) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _normalize(String? value) {
    if (value == null) return '';
    var normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    // Sheets are often numbered as "1. Serial no", "2. Rate", ...
    normalized = normalized.replaceFirst(RegExp(r'^\d+\s*'), '');
    return normalized;
  }

  static double? _parseNumber(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    // Invoice style values such as "₹1,250/-" are common in shop ledgers.
    text = text.replaceAll(RegExp(r'/-\s*$'), '');
    text = text.replaceAll(RegExp(r'[,\s]'), '');
    text = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (text.isEmpty || text == '-' || text == '.') return null;

    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return null;
    return value;
  }

  static double? _parseOptionalNonNegative(String? raw) {
    final value = _parseNumber(raw);
    if (value == null || value < 0) return null;
    return value;
  }
}

class _Header {
  const _Header({
    required this.particulars,
    required this.rate,
    this.productId,
    this.serialNo,
    this.quantity,
    this.total,
  });

  final int particulars;
  final int rate;
  final int? productId;
  final int? serialNo;
  final int? quantity;
  final int? total;
}

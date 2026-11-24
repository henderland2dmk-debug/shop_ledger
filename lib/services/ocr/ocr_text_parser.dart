import '../../core/product_keys.dart';
import '../../models/product.dart';

/// One editable row produced from scanned text.
class OcrDraftRow {
  OcrDraftRow({
    required this.id,
    required this.sourceLine,
    required this.particulars,
    required this.rate,
    required this.quantity,
    this.total,
    this.serialNo,
    this.productId,
    this.note,
  });

  final String id;
  final int sourceLine;
  final String particulars;
  final double rate;
  final double quantity;
  final double? total;
  final int? serialNo;
  final String? productId;
  final String? note;

  bool get needsAttention =>
      note != null ||
      particulars.trim().isEmpty ||
      rate < 0 ||
      quantity <= 0 ||
      (total != null && total! < 0);

  double get lineTotal => total ?? rate * quantity;

  OcrDraftRow copyWith({
    String? particulars,
    double? rate,
    double? quantity,
    double? total,
    int? serialNo,
    String? productId,
    String? note,
    bool clearTotal = false,
    bool clearProductId = false,
    bool clearNote = false,
  }) {
    return OcrDraftRow(
      id: id,
      sourceLine: sourceLine,
      particulars: particulars ?? this.particulars,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      total: clearTotal ? null : total ?? this.total,
      serialNo: serialNo ?? this.serialNo,
      productId: clearProductId ? null : productId ?? this.productId,
      note: clearNote ? null : note ?? this.note,
    );
  }
}

/// The rows read from one scanned picture.
class OcrParseResult {
  const OcrParseResult({
    required this.rows,
    required this.imageName,
    required this.headerDetected,
  });

  final List<OcrDraftRow> rows;
  final String imageName;
  final bool headerDetected;

  int get rowCount => rows.length;

  int get issueCount => rows.where((row) => row.needsAttention).length;
}

/// Where each numeric column appeared in the detected header line.
class _HeaderLayout {
  const _HeaderLayout({
    required this.numericColumns,
    required this.particularsPosition,
  });

  final List<(int position, String label)> numericColumns;
  final int? particularsPosition;

  List<String> get columns =>
      numericColumns.map((column) => column.$2).toList(growable: false);

  int? positionOf(String label) => numericColumns
      .where((column) => column.$2 == label)
      .map((column) => column.$1)
      .firstOrNull;
}

/// Turns OCR text such as `1  Soap  50  2  100` into editable rows.
///
/// The scanner is never trusted blindly: every row can be changed or removed
/// before it is added to stock or to a bill.
class OcrTextParser {
  const OcrTextParser();

  static final RegExp _number = RegExp(r'\d+(?:,\d{3})*(?:\.\d+)?');
  static final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

  OcrParseResult parse(
    String rawText, {
    required String imageName,
    List<Product> products = const [],
  }) {
    final lines = rawText
        .split(_lineBreak)
        .map(_clean)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final headerIndex = lines.indexWhere(_looksLikeHeader);
    final header = headerIndex == -1 ? null : lines[headerIndex];
    final layout = header == null ? null : _readHeader(header);

    final rows = <OcrDraftRow>[];
    var lineNumber = 0;
    for (final line in lines) {
      lineNumber++;
      if (lineNumber == headerIndex + 1) continue;
      if (_isSummaryLine(line)) continue;

      final row = _parseLine(
        line: line,
        sourceLine: lineNumber,
        layout: layout,
        products: products,
      );
      if (row != null) rows.add(row);
    }

    return OcrParseResult(
      rows: rows,
      imageName: imageName,
      headerDetected: header != null,
    );
  }

  String _clean(String line) {
    return line
        .replaceAll(RegExp(r'[₹]|Rs\.?|INR'), ' ')
        .replaceAll('/-', ' ')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _looksLikeHeader(String line) {
    final lower = line.toLowerCase();
    const markers = <String>[
      'particular',
      'rate',
      'qty',
      'quantity',
      'total',
      'serial',
      's no',
      's.no',
      'sno',
    ];
    final matches = markers.where(lower.contains).length;
    return matches >= 3 ||
        (lower.contains('particular') &&
            (lower.contains('rate') || lower.contains('total')));
  }

  _HeaderLayout _readHeader(String header) {
    final lower = header.toLowerCase();
    const labels = <String, List<String>>{
      'serialNo': [
        'serial no',
        'serial number',
        's no',
        's.no',
        'sno',
        'sl no',
      ],
      'rate': ['rate', 'price'],
      'quantity': ['quantity', 'qty'],
      'total': ['total', 'amount'],
    };
    final positioned = <(int, String)>[];
    for (final entry in labels.entries) {
      for (final label in entry.value) {
        final index = lower.indexOf(label);
        if (index != -1) {
          positioned.add((index, entry.key));
          break;
        }
      }
    }
    positioned.sort((a, b) => a.$1.compareTo(b.$1));

    final particularsIndex = lower.indexOf('particular');
    return _HeaderLayout(
      numericColumns: positioned,
      particularsPosition: particularsIndex == -1 ? null : particularsIndex,
    );
  }

  bool _isSummaryLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('grand total') ||
        lower.contains('sub total') ||
        lower.contains('subtotal') ||
        lower.contains('total amount') ||
        RegExp(r'^total[\s:.-]').hasMatch(lower);
  }

  OcrDraftRow? _parseLine({
    required String line,
    required int sourceLine,
    required _HeaderLayout? layout,
    required List<Product> products,
  }) {
    final matches = _number.allMatches(line).toList(growable: false);
    if (matches.isEmpty) return null;

    final columns = _alignColumns(
      layout?.columns ?? _defaultColumns(matches.length),
      matches.length,
    );
    if (columns.isEmpty) return null;

    // OCR sometimes reads a product code as a number. The header tells us
    // which numeric columns sit before and after the product name, so those
    // digits stay in the name while the real columns are read from the edges.
    final valueMatches = _selectValueMatches(matches, columns, layout);
    final numbers = valueMatches
        .map((match) => double.tryParse(match.group(0)!.replaceAll(',', '')))
        .whereType<double>()
        .toList(growable: false);
    if (numbers.isEmpty) return null;

    final particulars = _extractParticulars(line, matches, valueMatches);
    final values = <String, double>{};
    for (var index = 0; index < numbers.length; index++) {
      values[columns[index]] = numbers[index];
    }

    final rate = values['rate'];
    var quantity = values['quantity'] ?? 1;
    if (quantity <= 0) quantity = 1;
    final scannedTotal = values['total'];
    final resolvedRate =
        rate ??
        (scannedTotal != null && quantity > 0 ? scannedTotal / quantity : -1);
    final serialValue = values['serialNo']?.toInt();

    String? note;
    if (particulars.isEmpty) note = 'Name was not read. Please enter it.';
    if (resolvedRate < 0) note ??= 'Rate was not read. Please enter it.';

    final id =
        'ocr-$sourceLine-${numbers.length}-${particulars.hashCode.abs()}';
    return OcrDraftRow(
      id: id,
      sourceLine: sourceLine,
      particulars: particulars,
      rate: resolvedRate < 0 ? 0 : resolvedRate,
      quantity: quantity,
      total: scannedTotal,
      serialNo: serialValue,
      productId: _matchProduct(
        particulars: particulars,
        serialNo: serialValue,
        products: products,
      )?.id,
      note: note,
    );
  }

  List<String> _defaultColumns(int count) {
    if (count >= 4) return const ['serialNo', 'rate', 'quantity', 'total'];
    if (count == 3) return const ['rate', 'quantity', 'total'];
    if (count == 2) return const ['rate', 'quantity'];
    if (count == 1) return const ['rate'];
    return const <String>[];
  }

  List<String> _alignColumns(List<String> columns, int count) {
    if (count <= 0) return const <String>[];
    if (count == 1) return const ['rate'];
    if (columns.length <= count) return columns;

    var aligned = List<String>.from(columns);
    var missing = aligned.length - count;
    if (aligned.first == 'serialNo' && missing > 0) {
      aligned = aligned.sublist(1);
      missing--;
    }
    if (aligned.isNotEmpty && aligned.last == 'total' && missing > 0) {
      aligned = aligned.sublist(0, aligned.length - 1);
      missing--;
    }
    if (aligned.length == count) return aligned;
    return aligned.sublist(aligned.length - count);
  }

  List<RegExpMatch> _selectValueMatches(
    List<RegExpMatch> matches,
    List<String> columns,
    _HeaderLayout? layout,
  ) {
    if (matches.length <= columns.length) return matches;

    final particularsPosition = layout?.particularsPosition;
    if (particularsPosition == null) {
      return matches.sublist(matches.length - columns.length);
    }

    final before = columns.where((column) {
      final position = layout!.positionOf(column);
      return position != null && position < particularsPosition;
    }).length;
    final after = columns.length - before;
    if (before <= 0 || after <= 0) {
      return matches.sublist(matches.length - columns.length);
    }

    return [...matches.take(before), ...matches.skip(matches.length - after)];
  }

  String _extractParticulars(
    String line,
    List<RegExpMatch> allMatches,
    List<RegExpMatch> valueMatches,
  ) {
    final valueStarts = valueMatches.map((match) => match.start).toSet();
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in allMatches) {
      if (!valueStarts.contains(match.start)) continue;
      if (match.start > cursor) {
        buffer.write(line.substring(cursor, match.start));
      }
      cursor = match.end;
    }
    if (cursor < line.length) buffer.write(line.substring(cursor));

    return buffer
        .toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9&/.\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Product? _matchProduct({
    required String particulars,
    required int? serialNo,
    required List<Product> products,
  }) {
    if (serialNo != null) {
      for (final product in products) {
        if (product.serialNo == serialNo) return product;
      }
    }

    final key = normalizeProductName(particulars);
    if (key.isEmpty) return null;
    for (final product in products) {
      if (normalizeProductName(product.particulars) == key) return product;
    }
    return null;
  }
}

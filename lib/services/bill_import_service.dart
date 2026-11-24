import 'dart:typed_data';

import '../core/formatters.dart';
import '../core/product_keys.dart';
import '../models/bill_item.dart';
import '../models/product.dart';
import 'excel_import_service.dart';

/// Why one row of a bill sheet could not be added.
class BillImportIssue {
  const BillImportIssue({
    required this.sourceRow,
    required this.particulars,
    required this.reason,
  });

  final int sourceRow;
  final String particulars;
  final String reason;
}

/// Bill lines that are ready to add, plus the rows that were skipped.
class BillImportResult {
  const BillImportResult({
    required this.fileName,
    required this.items,
    required this.issues,
  });

  final String fileName;
  final List<BillItem> items;
  final List<BillImportIssue> issues;

  int get itemCount => items.length;
  int get issueCount => issues.length;
}

/// Reads an item list and matches every row against the current stock.
///
/// The sheet uses the same columns as stock import. Product ID and serial no
/// are optional helpers; particulars are used when neither is supplied.
class BillImportService {
  const BillImportService({
    required this.products,
    this.currentBill = const [],
  });

  final List<Product> products;
  final List<BillItem> currentBill;

  BillImportResult parse(Uint8List bytes, {required String fileName}) {
    final parsed = const ExcelImportService().parse(bytes, fileName: fileName);
    final planned = <String, double>{};
    for (final item in currentBill) {
      planned[item.productId] = (planned[item.productId] ?? 0) + item.quantity;
    }

    final items = <BillItem>[];
    final issues = <BillImportIssue>[];

    for (final row in parsed.rows) {
      if (!row.isValid) {
        issues.add(
          BillImportIssue(
            sourceRow: row.sourceRow,
            particulars: row.particulars.isEmpty ? '—' : row.particulars,
            reason: row.errors.join(' · '),
          ),
        );
        continue;
      }

      final product = _matchProduct(row);
      if (product == null) {
        issues.add(
          BillImportIssue(
            sourceRow: row.sourceRow,
            particulars: row.particulars,
            reason: 'Not found in the current stock',
          ),
        );
        continue;
      }

      final quantity = row.quantity ?? 1;
      if (quantity <= 0 || !quantity.isFinite) {
        issues.add(
          BillImportIssue(
            sourceRow: row.sourceRow,
            particulars: row.particulars,
            reason: 'Quantity must be greater than zero',
          ),
        );
        continue;
      }

      final alreadyPlanned = planned[product.id] ?? 0;
      final available = product.quantity - alreadyPlanned;
      if (quantity > available + 0.0000001) {
        issues.add(
          BillImportIssue(
            sourceRow: row.sourceRow,
            particulars: row.particulars,
            reason:
                'Only ${formatQuantity(available > 0 ? available : 0)} left in stock',
          ),
        );
        continue;
      }

      final rate = row.rate ?? product.rate;
      items.add(
        BillItem(
          productId: product.id,
          serialNo: product.serialNo,
          particulars: product.particulars,
          rate: rate,
          quantity: quantity,
        ),
      );
      planned[product.id] = alreadyPlanned + quantity;
    }

    return BillImportResult(fileName: fileName, items: items, issues: issues);
  }

  Product? _matchProduct(ImportRow row) {
    if (row.productId != null) {
      final wantedId = row.productId!.toLowerCase();
      for (final product in products) {
        if (product.id.toLowerCase() == wantedId) return product;
      }
    }

    if (row.serialNo != null) {
      for (final product in products) {
        if (product.serialNo == row.serialNo) return product;
      }
    }

    for (final product in products) {
      if (isSameProduct(product.particulars, row.particulars)) return product;
    }
    return null;
  }
}

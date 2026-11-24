import 'package:flutter/foundation.dart';

import '../core/customer_keys.dart';
import 'bill_item.dart';

/// A completed sale. The stock has already been reduced when this exists.
@immutable
class Sale {
  const Sale({
    required this.id,
    required this.soldAt,
    required this.customerName,
    required this.items,
  });

  final String id;
  final DateTime soldAt;
  final String customerName;
  final List<BillItem> items;

  double get totalAmount =>
      items.fold(0, (runningTotal, item) => runningTotal + item.total);

  double get totalQuantity =>
      items.fold(0, (runningTotal, item) => runningTotal + item.quantity);

  int get lineCount => items.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'soldAt': soldAt.toIso8601String(),
      'customerName': customerName,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <BillItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(BillItem.fromJson(item));
        }
      }
    }

    return Sale(
      id: (json['id'] as String?) ?? '',
      soldAt: DateTime.tryParse('${json['soldAt']}') ?? DateTime.now(),
      customerName: (json['customerName'] as String?)?.trim().isEmpty ?? true
          ? walkInCustomer
          : (json['customerName'] as String).trim(),
      items: items,
    );
  }
}

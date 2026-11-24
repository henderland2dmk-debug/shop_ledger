import 'package:flutter/foundation.dart';

import 'product.dart';

/// One line on a bill. It keeps a snapshot of the product at the time it was
/// added so old sales never change when the stock rate or name is edited.
@immutable
class BillItem {
  const BillItem({
    required this.productId,
    required this.serialNo,
    required this.particulars,
    required this.rate,
    required this.quantity,
  });

  factory BillItem.fromProduct(Product product, {double quantity = 1}) {
    return BillItem(
      productId: product.id,
      serialNo: product.serialNo,
      particulars: product.particulars,
      rate: product.rate,
      quantity: quantity,
    );
  }

  final String productId;
  final int serialNo;
  final String particulars;
  final double rate;
  final double quantity;

  double get total => rate * quantity;

  BillItem copyWith({double? rate, double? quantity}) {
    return BillItem(
      productId: productId,
      serialNo: serialNo,
      particulars: particulars,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'serialNo': serialNo,
      'particulars': particulars,
      'rate': rate,
      'quantity': quantity,
    };
  }

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      productId: (json['productId'] as String?) ?? '',
      serialNo: _asInt(json['serialNo']),
      particulars: (json['particulars'] as String?)?.trim() ?? '',
      rate: _asDouble(json['rate']),
      quantity: _asDouble(json['quantity'], fallback: 1),
    );
  }

  static double _asDouble(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

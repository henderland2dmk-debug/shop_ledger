import 'package:flutter/foundation.dart';

/// A single item held in the shop's stock.
@immutable
class Product {
  const Product({
    required this.id,
    required this.serialNo,
    required this.particulars,
    required this.rate,
    required this.quantity,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Permanent, automatically generated identifier (for example `PRD-0001`).
  final String id;

  /// Running number shown in the stock ledger.
  final int serialNo;

  final String particulars;
  final double rate;
  final double quantity;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product copyWith({
    String? particulars,
    double? rate,
    double? quantity,
    double? total,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
      serialNo: serialNo,
      particulars: particulars ?? this.particulars,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serialNo': serialNo,
      'particulars': particulars,
      'rate': rate,
      'quantity': quantity,
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      serialNo: _asInt(json['serialNo']),
      particulars: (json['particulars'] as String?)?.trim() ?? '',
      rate: _asDouble(json['rate']),
      quantity: _asDouble(json['quantity'], fallback: 1),
      total: _asDouble(json['total']),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
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

  static DateTime _asDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

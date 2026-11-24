import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatters.dart';
import '../core/product_keys.dart';
import '../models/bill_item.dart';
import '../models/product.dart';
import '../models/product_draft.dart';

/// Raised when a bill asks for more stock than is currently available.
class StockShortfallException implements Exception {
  const StockShortfallException(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

/// Holds the shop's products and stores them locally on the device.
///
/// Products are kept ordered by their visible serial number. The permanent
/// product ID is unrelated to the serial number and is never reused.
class ProductStore extends ChangeNotifier {
  ProductStore(this._preferences) {
    _restore();
  }

  static const _productsKey = 'shop_ledger.products.v1';
  static const _sequenceKey = 'shop_ledger.product_sequence.v1';
  static const _quantityTolerance = 0.0000001;

  final SharedPreferences _preferences;
  final List<Product> _products = [];
  int _nextProductNumber = 1;

  List<Product> get products => List.unmodifiable(_products);

  bool get isEmpty => _products.isEmpty;

  double get stockValue => _products.fold(
    0,
    (runningTotal, product) => runningTotal + product.total,
  );

  double get totalQuantity => _products.fold(
    0,
    (runningQuantity, product) => runningQuantity + product.quantity,
  );

  /// Adds a single product and returns the stored product.
  Future<Product> addProduct({
    required String particulars,
    required double rate,
    double quantity = 1,
    double? total,
    int? serialNo,
  }) async {
    final added = await addProducts([
      ProductDraft(
        particulars: particulars,
        rate: rate,
        quantity: quantity,
        total: total,
        serialNo: serialNo,
      ),
    ]);
    if (added.isEmpty) {
      throw ArgumentError('A product needs particulars and a valid rate.');
    }
    return added.first;
  }

  /// Adds every valid draft.
  ///
  /// A draft whose particulars match a product already in stock does not get a
  /// new ID. Its quantity and total are added to the existing product instead.
  Future<List<Product>> addProducts(Iterable<ProductDraft> drafts) async {
    final usedSerials = _products.map((product) => product.serialNo).toSet();
    var nextAutoSerial = usedSerials.isEmpty
        ? 1
        : usedSerials.reduce(math.max) + 1;

    final byName = <String, Product>{
      for (final product in _products)
        normalizeProductName(product.particulars): product,
    };

    final now = DateTime.now();
    final stored = <Product>[];

    for (final draft in drafts) {
      final particulars = draft.particulars.trim();
      final rate = draft.rate;
      if (particulars.isEmpty || !rate.isFinite || rate < 0) {
        continue;
      }

      final quantity = _validQuantity(draft.quantity);
      final total =
          (draft.total != null && draft.total!.isFinite && draft.total! >= 0)
          ? draft.total!
          : rate * quantity;

      final key = normalizeProductName(particulars);
      final existing = byName[key];
      if (existing != null) {
        final mergedQuantity = existing.quantity + quantity;
        final mergedTotal = existing.total + total;
        final mergedRate = mergedQuantity > 0
            ? mergedTotal / mergedQuantity
            : existing.rate;

        final merged = existing.copyWith(
          rate: mergedRate,
          quantity: mergedQuantity,
          total: mergedTotal,
          updatedAt: now,
        );
        final index = _products.indexWhere(
          (product) => product.id == existing.id,
        );
        if (index != -1) {
          _products[index] = merged;
        }
        byName[key] = merged;
        stored.add(merged);
        continue;
      }

      var serialNo = draft.serialNo;
      if (serialNo == null || serialNo <= 0 || usedSerials.contains(serialNo)) {
        while (usedSerials.contains(nextAutoSerial)) {
          nextAutoSerial++;
        }
        serialNo = nextAutoSerial;
      }
      usedSerials.add(serialNo);
      if (serialNo >= nextAutoSerial) {
        nextAutoSerial = serialNo + 1;
      }

      final product = Product(
        id: _generateProductId(),
        serialNo: serialNo,
        particulars: particulars,
        rate: rate,
        quantity: quantity,
        total: total,
        createdAt: now,
        updatedAt: now,
      );
      _products.add(product);
      byName[key] = product;
      stored.add(product);
    }

    if (stored.isEmpty) return const [];

    _sortProducts();
    await _persist();
    notifyListeners();
    return stored;
  }

  /// Finds a product by its visible particulars, ignoring case and spacing.
  Product? findByParticulars(String particulars) {
    final key = normalizeProductName(particulars);
    if (key.isEmpty) return null;
    for (final product in _products) {
      if (normalizeProductName(product.particulars) == key) return product;
    }
    return null;
  }

  Product? findById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// Updates the editable fields of a product. The total is always
  /// recalculated from the new rate and quantity.
  Future<Product?> updateProduct({
    required String id,
    required String particulars,
    required double rate,
    required double quantity,
  }) async {
    final trimmed = particulars.trim();
    if (trimmed.isEmpty ||
        !rate.isFinite ||
        rate < 0 ||
        !quantity.isFinite ||
        quantity < 0) {
      return null;
    }

    final index = _products.indexWhere((product) => product.id == id);
    if (index == -1) return null;

    final updated = _products[index].copyWith(
      particulars: trimmed,
      rate: rate,
      quantity: quantity,
      total: rate * quantity,
      updatedAt: DateTime.now(),
    );
    _products[index] = updated;
    await _persist();
    notifyListeners();
    return updated;
  }

  /// Permanently removes one product from stock.
  ///
  /// The permanent ID sequence is not rewound, so an ID is never reused for a
  /// different product. Past sales are stored separately and are not touched.
  Future<Product?> deleteProduct(String id) async {
    final index = _products.indexWhere((product) => product.id == id);
    if (index == -1) return null;

    final removed = _products.removeAt(index);
    await _persist();
    notifyListeners();
    return removed;
  }

  /// Permanently removes every product from stock.
  ///
  /// Returns the number of products that were removed. Past sales are kept.
  Future<int> clearProducts() async {
    if (_products.isEmpty) return 0;

    final count = _products.length;
    _products.clear();
    await _persist();
    notifyListeners();
    return count;
  }

  /// Human-readable problems that would make a bill impossible to sell.
  List<String> checkStockAvailability(Iterable<BillItem> items) {
    final requested = <String, double>{};
    final labels = <String, String>{};

    for (final item in items) {
      if (item.quantity <= 0) continue;
      requested[item.productId] =
          (requested[item.productId] ?? 0) + item.quantity;
      labels[item.productId] = item.particulars;
    }

    final problems = <String>[];
    for (final entry in requested.entries) {
      final product = findById(entry.key);
      if (product == null) {
        problems.add(
          '${labels[entry.key] ?? entry.key} is no longer in stock.',
        );
      } else if (entry.value > product.quantity + _quantityTolerance) {
        problems.add(
          '${product.particulars}: only ${formatQuantity(product.quantity)} '
          'available (${formatQuantity(entry.value)} on bill).',
        );
      }
    }
    return problems;
  }

  /// Deducts the sold quantities from stock and returns the changed products.
  Future<List<Product>> sellProducts(Iterable<BillItem> items) async {
    final problems = checkStockAvailability(items);
    if (problems.isNotEmpty) {
      throw StockShortfallException(problems);
    }

    final now = DateTime.now();
    final sold = <Product>[];

    for (final item in items) {
      if (item.quantity <= 0) continue;
      final index = _products.indexWhere(
        (product) => product.id == item.productId,
      );
      if (index == -1) continue;

      final product = _products[index];
      final remainingQuantity = math
          .max(0, product.quantity - item.quantity)
          .toDouble();
      final remainingTotal = math.max(0, product.total - item.total).toDouble();
      final remainingRate = remainingQuantity > _quantityTolerance
          ? remainingTotal / remainingQuantity
          : product.rate;

      final updated = product.copyWith(
        rate: remainingRate,
        quantity: remainingQuantity,
        total: remainingTotal,
        updatedAt: now,
      );
      _products[index] = updated;
      sold.add(updated);
    }

    if (sold.isEmpty) return const [];
    await _persist();
    notifyListeners();
    return sold;
  }

  /// Reverses a rejected sale by putting its quantities back into stock.
  ///
  /// Existing products keep their ID and serial number; their quantity and
  /// total are increased and the rate is recalculated as a weighted average.
  /// If a product was deleted after the sale, it is recreated from the sale
  /// snapshot so the rejected goods are not lost.
  Future<List<Product>> restoreProducts(
    Iterable<BillItem> items, {
    DateTime? restoredAt,
  }) async {
    final now = restoredAt ?? DateTime.now();
    final usedSerials = _products.map((product) => product.serialNo).toSet();
    var nextAutoSerial = usedSerials.isEmpty
        ? 1
        : usedSerials.reduce(math.max) + 1;
    final restored = <Product>[];

    for (final item in items) {
      if (item.quantity <= 0 ||
          !item.quantity.isFinite ||
          !item.rate.isFinite ||
          item.rate < 0) {
        continue;
      }

      final index = _products.indexWhere(
        (product) => product.id == item.productId,
      );
      if (index != -1) {
        final product = _products[index];
        final quantity = product.quantity + item.quantity;
        final total = product.total + item.total;
        final updated = product.copyWith(
          rate: quantity > _quantityTolerance ? total / quantity : product.rate,
          quantity: quantity,
          total: total,
          updatedAt: now,
        );
        _products[index] = updated;
        restored.add(updated);
        continue;
      }

      var serialNo = item.serialNo;
      if (serialNo <= 0 || usedSerials.contains(serialNo)) {
        while (usedSerials.contains(nextAutoSerial)) {
          nextAutoSerial++;
        }
        serialNo = nextAutoSerial;
      }
      usedSerials.add(serialNo);
      if (serialNo >= nextAutoSerial) nextAutoSerial = serialNo + 1;

      final id = item.productId.isNotEmpty
          ? item.productId
          : _generateProductId();
      final recreated = Product(
        id: id,
        serialNo: serialNo,
        particulars: item.particulars.isEmpty
            ? 'Restored product'
            : item.particulars,
        rate: item.rate,
        quantity: item.quantity,
        total: item.total,
        createdAt: now,
        updatedAt: now,
      );
      _products.add(recreated);
      restored.add(recreated);

      final match = RegExp(r'^PRD-(\d+)$').firstMatch(id);
      final number = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
      if (number >= _nextProductNumber) _nextProductNumber = number + 1;
    }

    if (restored.isEmpty) return const [];

    _sortProducts();
    await _persist();
    notifyListeners();
    return restored;
  }

  void _restore() {
    final raw = _preferences.getString(_productsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _products.add(Product.fromJson(item));
            }
          }
        }
      } catch (_) {
        _products.clear();
      }
    }

    _sortProducts();

    _nextProductNumber = _preferences.getInt(_sequenceKey) ?? 1;
    for (final product in _products) {
      final match = RegExp(r'^PRD-(\d+)$').firstMatch(product.id);
      final number = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
      if (number >= _nextProductNumber) {
        _nextProductNumber = number + 1;
      }
    }
  }

  String _generateProductId() {
    late String id;
    do {
      id = 'PRD-${_nextProductNumber.toString().padLeft(4, '0')}';
      _nextProductNumber++;
    } while (_products.any((product) => product.id == id));
    return id;
  }

  static double _validQuantity(double? quantity) {
    if (quantity == null || !quantity.isFinite || quantity < 0) return 1;
    return quantity;
  }

  void _sortProducts() {
    _products.sort((a, b) => a.serialNo.compareTo(b.serialNo));
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(
      _products.map((product) => product.toJson()).toList(),
    );
    await _preferences.setString(_productsKey, encoded);
    await _preferences.setInt(_sequenceKey, _nextProductNumber);
  }
}

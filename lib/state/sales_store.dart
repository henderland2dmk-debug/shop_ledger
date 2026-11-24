import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/customer_keys.dart';
import '../models/bill_item.dart';
import '../models/customer_bill_group.dart';
import '../models/product.dart';
import '../models/sale.dart';
import 'product_store.dart';

/// Holds the bill being prepared and every completed sale.
///
/// The draft bill is persisted too, so it survives a page reload or app
/// restart. Completing a sale asks [ProductStore] to reduce the stock first.
class SalesStore extends ChangeNotifier {
  SalesStore(this._preferences) {
    _restore();
  }

  static const _salesKey = 'shop_ledger.sales.v1';
  static const _draftKey = 'shop_ledger.bill_draft.v1';
  static const _customerKey = 'shop_ledger.bill_customer.v1';
  static const _sequenceKey = 'shop_ledger.sale_sequence.v1';
  static const _quantityTolerance = 0.0000001;

  final SharedPreferences _preferences;
  final List<Sale> _sales = [];
  final List<BillItem> _draftItems = [];
  String _draftCustomerName = '';
  int _nextSaleNumber = 1;

  List<Sale> get sales => List.unmodifiable(_sales);
  List<BillItem> get draftItems => List.unmodifiable(_draftItems);

  String get draftCustomerName => _draftCustomerName;

  bool get hasDraftItems => _draftItems.isNotEmpty;

  int get draftLineCount => _draftItems.length;

  double get draftQuantity =>
      _draftItems.fold(0, (runningTotal, item) => runningTotal + item.quantity);

  double get draftTotal =>
      _draftItems.fold(0, (runningTotal, item) => runningTotal + item.total);

  double get totalSales =>
      _sales.fold(0, (runningTotal, sale) => runningTotal + sale.totalAmount);

  double get totalUnitsSold =>
      _sales.fold(0, (runningTotal, sale) => runningTotal + sale.totalQuantity);

  int get saleCount => _sales.length;

  List<Sale> get recentSales => _sales.take(5).toList(growable: false);

  /// Every saved bill grouped under its customer, newest customer first.
  List<CustomerBillGroup> get customerBillGroups {
    final grouped = <String, List<Sale>>{};
    final displayNames = <String, String>{};
    for (final sale in _sales.reversed) {
      // Keep the name from the customer's first bill as the stable label even
      // if a later bill uses different capitalisation or spacing.
      displayNames.putIfAbsent(
        normalizeCustomerName(sale.customerName),
        () => sale.customerName,
      );
    }
    for (final sale in _sales) {
      grouped
          .putIfAbsent(normalizeCustomerName(sale.customerName), () => [])
          .add(sale);
    }

    final groups =
        grouped.entries
            .map(
              (entry) => CustomerBillGroup(
                customerName:
                    displayNames[entry.key] ?? entry.value.first.customerName,
                sales: List<Sale>.unmodifiable(entry.value),
              ),
            )
            .toList()
          ..sort((a, b) => b.latestSaleAt.compareTo(a.latestSaleAt));
    return List<CustomerBillGroup>.unmodifiable(groups);
  }

  /// Named customers that already have at least one saved bill.
  ///
  /// The generic walk-in label is omitted because it is not a real customer.
  List<String> get customerNames {
    final walkInKey = normalizeCustomerName(walkInCustomer);
    return customerBillGroups
        .where(
          (group) => normalizeCustomerName(group.customerName) != walkInKey,
        )
        .map((group) => group.customerName)
        .toList(growable: false);
  }

  List<Sale> salesForCustomer(String customerName) {
    final key = normalizeCustomerName(customerName);
    return List<Sale>.unmodifiable(
      _sales.where((sale) => normalizeCustomerName(sale.customerName) == key),
    );
  }

  double quantityInBill(String productId) => _draftItems
      .where((item) => item.productId == productId)
      .fold(0, (runningTotal, item) => runningTotal + item.quantity);

  double amountSince(DateTime start) => _sales
      .where((sale) => !sale.soldAt.isBefore(start))
      .fold(0, (runningTotal, sale) => runningTotal + sale.totalAmount);

  double unitsSince(DateTime start) => _sales
      .where((sale) => !sale.soldAt.isBefore(start))
      .fold(0, (runningTotal, sale) => runningTotal + sale.totalQuantity);

  int salesSince(DateTime start) =>
      _sales.where((sale) => !sale.soldAt.isBefore(start)).length;

  DateTime get startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get startOfWeek {
    final today = startOfToday;
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime get startOfMonth {
    final today = startOfToday;
    return DateTime(today.year, today.month);
  }

  double get soldToday => amountSince(startOfToday);
  double get soldThisWeek => amountSince(startOfWeek);
  double get soldThisMonth => amountSince(startOfMonth);

  double get unitsToday => unitsSince(startOfToday);
  double get unitsThisWeek => unitsSince(startOfWeek);
  double get unitsThisMonth => unitsSince(startOfMonth);

  /// Adds one unit of [product] to the bill. Repeated taps add more units.
  Future<void> addToBill(Product product, {double quantity = 1}) async {
    await addBillItems([BillItem.fromProduct(product, quantity: quantity)]);
  }

  /// Adds or merges bill lines. Repeated products keep one line with the
  /// combined quantity and a weighted rate.
  Future<void> addBillItems(Iterable<BillItem> items) async {
    for (final incoming in items) {
      if (incoming.productId.isEmpty ||
          incoming.quantity <= 0 ||
          !incoming.quantity.isFinite ||
          !incoming.rate.isFinite ||
          incoming.rate < 0) {
        continue;
      }

      final index = _draftItems.indexWhere(
        (item) => item.productId == incoming.productId,
      );
      if (index == -1) {
        _draftItems.add(incoming);
        continue;
      }

      final existing = _draftItems[index];
      final quantity = existing.quantity + incoming.quantity;
      final total = existing.total + incoming.total;
      _draftItems[index] = existing.copyWith(
        quantity: quantity,
        rate: quantity > 0 ? total / quantity : existing.rate,
      );
    }

    await _persistDraft();
    notifyListeners();
  }

  Future<void> setBillQuantity(String productId, double quantity) async {
    final index = _draftItems.indexWhere((item) => item.productId == productId);
    if (index == -1) return;

    if (quantity <= _quantityTolerance) {
      _draftItems.removeAt(index);
    } else {
      _draftItems[index] = _draftItems[index].copyWith(quantity: quantity);
    }
    await _persistDraft();
    notifyListeners();
  }

  Future<void> changeBillQuantity(String productId, double delta) async {
    final index = _draftItems.indexWhere((item) => item.productId == productId);
    if (index == -1) return;
    await setBillQuantity(productId, _draftItems[index].quantity + delta);
  }

  Future<void> removeFromBill(String productId) async {
    await removeProductsFromBill([productId]);
  }

  /// Removes bill lines for products that are no longer in stock.
  Future<void> removeProductsFromBill(Iterable<String> productIds) async {
    final ids = productIds.toSet();
    if (ids.isEmpty ||
        !_draftItems.any((item) => ids.contains(item.productId))) {
      return;
    }
    _draftItems.removeWhere((item) => ids.contains(item.productId));
    await _persistDraft();
    notifyListeners();
  }

  Future<void> clearBill() async {
    if (_draftItems.isEmpty && _draftCustomerName.isEmpty) return;
    _draftItems.clear();
    _draftCustomerName = '';
    await _persistDraft();
    notifyListeners();
  }

  /// Permanently removes every completed sale from the history.
  ///
  /// Stock and the current bill are left untouched. The bill number sequence
  /// is not rewound, so an old BILL number is never reused.
  Future<int> clearSales() async {
    if (_sales.isEmpty) return 0;

    final count = _sales.length;
    _sales.clear();
    await _persistSales();
    notifyListeners();
    return count;
  }

  /// Rejects one saved bill: removes it from the history and restores its
  /// quantities to stock. The bill number is never reused.
  ///
  /// Returns the discarded sale, or `null` when the ID was not found.
  Future<Sale?> discardSale({
    required String saleId,
    required ProductStore productStore,
  }) async {
    final index = _sales.indexWhere((sale) => sale.id == saleId);
    if (index == -1) return null;

    final sale = _sales[index];
    await productStore.restoreProducts(sale.items, restoredAt: sale.soldAt);

    _sales.removeAt(index);
    await _persistSales();
    notifyListeners();
    return sale;
  }

  Future<void> setCustomerName(String name) async {
    final trimmed = name.trim();
    if (trimmed == _draftCustomerName) return;
    _draftCustomerName = trimmed;
    await _preferences.setString(_customerKey, trimmed);
    notifyListeners();
  }

  /// Sells the current bill, reduces stock and records the sale.
  Future<Sale?> commitSale({required ProductStore productStore}) async {
    if (_draftItems.isEmpty) return null;

    final items = List<BillItem>.from(_draftItems);
    final sale = Sale(
      id: _generateSaleId(),
      soldAt: DateTime.now(),
      customerName: _draftCustomerName.isEmpty
          ? walkInCustomer
          : _draftCustomerName,
      items: items,
    );

    await productStore.sellProducts(items);

    _sales.insert(0, sale);
    _draftItems.clear();
    _draftCustomerName = '';
    await Future.wait([_persistSales(), _persistDraft()]);
    notifyListeners();
    return sale;
  }

  void _restore() {
    final rawSales = _preferences.getString(_salesKey);
    if (rawSales != null) {
      try {
        final decoded = jsonDecode(rawSales);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final sale = Sale.fromJson(item);
              if (sale.id.isNotEmpty) _sales.add(sale);
            }
          }
        }
      } catch (_) {
        _sales.clear();
      }
    }
    _sales.sort((a, b) => b.soldAt.compareTo(a.soldAt));

    _nextSaleNumber = _preferences.getInt(_sequenceKey) ?? 1;
    for (final sale in _sales) {
      final match = RegExp(r'^BILL-(\d+)$').firstMatch(sale.id);
      final number = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
      if (number >= _nextSaleNumber) {
        _nextSaleNumber = number + 1;
      }
    }

    final rawDraft = _preferences.getString(_draftKey);
    if (rawDraft != null) {
      try {
        final decoded = jsonDecode(rawDraft);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _draftItems.add(BillItem.fromJson(item));
            }
          }
        }
      } catch (_) {
        _draftItems.clear();
      }
    }
    _draftCustomerName = _preferences.getString(_customerKey)?.trim() ?? '';
  }

  String _generateSaleId() {
    late String id;
    do {
      id = 'BILL-${_nextSaleNumber.toString().padLeft(4, '0')}';
      _nextSaleNumber++;
    } while (_sales.any((sale) => sale.id == id));
    return id;
  }

  Future<void> _persistDraft() async {
    await Future.wait([
      _preferences.setString(
        _draftKey,
        jsonEncode(_draftItems.map((item) => item.toJson()).toList()),
      ),
      _preferences.setString(_customerKey, _draftCustomerName),
    ]);
  }

  Future<void> _persistSales() async {
    await Future.wait([
      _preferences.setString(
        _salesKey,
        jsonEncode(_sales.map((sale) => sale.toJson()).toList()),
      ),
      _preferences.setInt(_sequenceKey, _nextSaleNumber),
    ]);
  }
}

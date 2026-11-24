import 'sale.dart';

/// All bills stored under one customer, newest first.
class CustomerBillGroup {
  const CustomerBillGroup({required this.customerName, required this.sales});

  final String customerName;
  final List<Sale> sales;

  Sale get latestSale => sales.first;

  DateTime get latestSaleAt => latestSale.soldAt;

  int get billCount => sales.length;

  double get totalAmount =>
      sales.fold(0, (runningTotal, sale) => runningTotal + sale.totalAmount);

  double get totalQuantity =>
      sales.fold(0, (runningTotal, sale) => runningTotal + sale.totalQuantity);
}

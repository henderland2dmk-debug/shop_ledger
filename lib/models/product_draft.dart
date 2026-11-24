/// Input used when adding one or more products.
///
/// Quantity, total and serial number are optional because the store fills in
/// sensible values for them.
class ProductDraft {
  const ProductDraft({
    required this.particulars,
    required this.rate,
    this.quantity,
    this.total,
    this.serialNo,
  });

  final String particulars;
  final double rate;
  final double? quantity;
  final double? total;
  final int? serialNo;
}

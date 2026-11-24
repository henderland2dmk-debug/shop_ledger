/// Default customer used when no name is entered on a bill.
const String walkInCustomer = 'Walk-in customer';

/// Normalises customer names for grouping and searching.
String normalizeCustomerName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

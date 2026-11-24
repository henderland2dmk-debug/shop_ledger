/// Normalises product names so "Red  Chilli Powder" and "red chilli powder"
/// are treated as the same stock item.
String normalizeProductName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Whether two particulars strings refer to the same product.
bool isSameProduct(String first, String second) =>
    normalizeProductName(first) == normalizeProductName(second);

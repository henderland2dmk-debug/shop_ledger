import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

final NumberFormat _compactMoneyFormat = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 1,
);

final NumberFormat _wholeMoneyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final NumberFormat _plainMoneyFormat = NumberFormat('#,##0.00', 'en_IN');
final NumberFormat _quantityFormat = NumberFormat('#,##0.###', 'en_IN');
final DateFormat _dateFormat = DateFormat('d MMM yyyy');
final DateFormat _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

/// Full currency value, for example `₹1,240.50`.
String formatMoney(num value) => _moneyFormat.format(value);

/// Currency value without a symbol, used inside generated PDFs.
String formatPlainMoney(num value) => _plainMoneyFormat.format(value);

/// Short currency value for tight spaces, for example `₹12.4K`.
String formatCompactMoney(num value) {
  if (value == 0) return '₹0';
  if (value.abs() < 1000) {
    return value == value.roundToDouble()
        ? _wholeMoneyFormat.format(value)
        : formatMoney(value);
  }
  return _compactMoneyFormat.format(value);
}

/// Quantities are shown without trailing zeroes (`2`, `2.5`).
String formatQuantity(num value) => _quantityFormat.format(value);

/// Plain number used while pre-filling form fields.
String formatEditableNumber(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}

String formatDate(DateTime date) => _dateFormat.format(date);

String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

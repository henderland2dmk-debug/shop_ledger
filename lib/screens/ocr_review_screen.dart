import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../core/product_keys.dart';
import '../models/product.dart';
import '../services/ocr/ocr_text_parser.dart';
import '../widgets/page_width.dart';
import '../widgets/surface_card.dart';

enum OcrReviewMode { stock, bill }

/// Shows every row read by the scanner so the user can correct it before any
/// product is changed. Nothing is saved until **Confirm** is pressed.
class OcrReviewScreen extends StatefulWidget {
  const OcrReviewScreen({
    super.key,
    required this.mode,
    required this.rows,
    required this.imageName,
    required this.products,
    this.existingNames = const <String>{},
    this.existingBillQuantities = const <String, double>{},
  });

  final OcrReviewMode mode;
  final List<OcrDraftRow> rows;
  final String imageName;
  final List<Product> products;
  final Set<String> existingNames;

  /// Quantities already in the current bill, used to prevent overselling.
  final Map<String, double> existingBillQuantities;

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  static const _quantityTolerance = 0.0000001;

  late List<OcrDraftRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List<OcrDraftRow>.from(widget.rows);
  }

  bool get _isBill => widget.mode == OcrReviewMode.bill;

  bool get _hasUnmatchedProduct =>
      _isBill &&
      _rows.any((row) => row.productId == null || row.productId!.isEmpty);

  bool get _canConfirm {
    if (_rows.isEmpty || _rows.any((row) => row.needsAttention)) return false;
    if (_hasUnmatchedProduct) return false;
    if (!_isBill) return true;
    return _rows.every((row) => _stockIssue(row, _plannedThrough(row)) == null);
  }

  int get _duplicateCount {
    if (_isBill) return 0;

    final known = <String>{...widget.existingNames};
    var count = 0;
    for (final row in _rows) {
      final key = normalizeProductName(row.particulars);
      if (key.isEmpty) continue;
      if (known.contains(key)) count++;
      known.add(key);
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final planned = <String, double>{...widget.existingBillQuantities};
    final stockIssues = <String?>[
      for (final row in _rows) ...[_isBill ? _stockIssue(row, planned) : null],
    ];
    for (var index = 0; index < _rows.length; index++) {
      _updatePlanned(planned, _rows[index]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isBill ? 'Review scanned bill' : 'Review scanned stock'),
        actions: [
          TextButton(
            key: const Key('ocr-cancel-button'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: PageWidth(
                  maxWidth: 980,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Check the scanned list',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These rows came from ${widget.imageName}. Nothing is '
                        'added until you confirm.',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      _ReviewNotice(
                        icon: Icons.fact_check_outlined,
                        color: AppColors.primary,
                        text: _isBill
                            ? 'Match every row to a stock product. Repeated '
                                  'products are combined into one bill line.'
                            : 'Rows with the same name as an existing product '
                                  'increase its quantity and total. Its ID stays '
                                  'the same.',
                      ),
                      if (_duplicateCount > 0) ...[
                        const SizedBox(height: 8),
                        _ReviewNotice(
                          icon: Icons.merge_type_rounded,
                          color: const Color(0xFF8A5A00),
                          text:
                              '$_duplicateCount row(s) will merge into products '
                              'already in stock, including other rows in this scan.',
                        ),
                      ],
                      if (_rows.isEmpty) ...[
                        const SizedBox(height: 20),
                        SurfaceCard(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'No product rows were found in that picture. '
                              'Try a clearer photo or add the products manually.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                      for (var index = 0; index < _rows.length; index++) ...[
                        const SizedBox(height: 12),
                        _EditableRow(
                          row: _rows[index],
                          mode: widget.mode,
                          products: widget.products,
                          index: index,
                          stockIssue: stockIssues[index],
                          onChanged: (updated) => setState(() {
                            _rows[index] = updated;
                          }),
                          onRemove: () => setState(() => _rows.removeAt(index)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('ocr-add-row-button'),
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add a row'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: PageWidth(
                maxWidth: 980,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_rows.length} row(s) · ${formatMoney(_rows.fold(0.0, (sum, row) => sum + (row.needsAttention ? 0 : row.lineTotal)))}',
                        style: textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      key: const Key('ocr-confirm-button'),
                      onPressed: _canConfirm ? _confirm : null,
                      icon: const Icon(Icons.check_rounded, size: 19),
                      label: Text(_isBill ? 'Add to bill' : 'Add to stock'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addRow() {
    setState(() {
      _rows.add(
        OcrDraftRow(
          id: 'ocr-manual-${DateTime.now().microsecondsSinceEpoch}',
          sourceLine: _rows.length + 1,
          particulars: '',
          rate: 0,
          quantity: 1,
          note: 'New row — fill in the details.',
        ),
      );
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(List<OcrDraftRow>.from(_rows));
  }

  /// Quantities reserved by the current bill and earlier scanned rows.
  Map<String, double> _plannedThrough(OcrDraftRow target) {
    final planned = <String, double>{...widget.existingBillQuantities};
    for (final row in _rows) {
      if (row.id == target.id) break;
      _updatePlanned(planned, row);
    }
    return planned;
  }

  Map<String, double> _updatePlanned(
    Map<String, double> planned,
    OcrDraftRow row,
  ) {
    final id = row.productId;
    if (id != null && id.isNotEmpty) {
      planned[id] = (planned[id] ?? 0) + row.quantity;
    }
    return planned;
  }

  String? _stockIssue(OcrDraftRow row, Map<String, double> planned) {
    if (!_isBill) return null;

    final id = row.productId;
    if (id == null || id.isEmpty) return 'Select a stock product.';

    Product? product;
    for (final candidate in widget.products) {
      if (candidate.id == id) {
        product = candidate;
        break;
      }
    }
    if (product == null) return 'That product is no longer in stock.';

    final available = product.quantity - (planned[id] ?? 0);
    if (row.quantity > available + _quantityTolerance) {
      final left = available > 0 ? available : 0;
      return 'Only ${formatQuantity(left)} available, including the current bill.';
    }
    return null;
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF8),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.row,
    required this.mode,
    required this.products,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    this.stockIssue,
  });

  final OcrDraftRow row;
  final OcrReviewMode mode;
  final List<Product> products;
  final int index;
  final ValueChanged<OcrDraftRow> onChanged;
  final VoidCallback onRemove;
  final String? stockIssue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasIssue = row.note != null || stockIssue != null;

    return SurfaceCard(
      borderColor: hasIssue ? AppColors.danger : AppColors.line,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'ROW ${index + 1}',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('ocr-remove-row-${row.id}'),
                onPressed: onRemove,
                tooltip: 'Remove row',
                color: AppColors.danger,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          if (hasIssue) ...[
            const SizedBox(height: 2),
            if (row.note != null)
              Text(
                row.note!,
                style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            if (stockIssue != null)
              Text(
                stockIssue!,
                style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            const SizedBox(height: 10),
          ],
          if (mode == OcrReviewMode.bill) ...[
            DropdownButtonFormField<String>(
              key: Key('ocr-product-${row.id}'),
              initialValue: row.productId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Stock product',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select a product'),
                ),
                for (final product in products)
                  DropdownMenuItem<String>(
                    value: product.id,
                    child: Text(
                      '${product.particulars} · ${product.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                final product = products
                    .where((candidate) => candidate.id == value)
                    .firstOrNull;
                onChanged(
                  row.copyWith(
                    productId: value,
                    particulars: product?.particulars ?? row.particulars,
                    clearProductId: value == null,
                    clearNote: true,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            key: Key('ocr-particulars-${row.id}'),
            initialValue: row.particulars,
            decoration: const InputDecoration(
              labelText: 'Particulars',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              final match = mode == OcrReviewMode.bill
                  ? products
                        .where(
                          (product) =>
                              normalizeProductName(product.particulars) ==
                              normalizeProductName(value),
                        )
                        .firstOrNull
                  : null;
              onChanged(
                row.copyWith(
                  particulars: value,
                  productId: mode == OcrReviewMode.bill
                      ? match?.id
                      : row.productId,
                  clearProductId: mode == OcrReviewMode.bill && match == null,
                  clearNote: true,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                _NumberField(
                  key: Key('ocr-rate-${row.id}'),
                  label: 'Rate',
                  value: row.rate,
                  onChanged: (value) =>
                      onChanged(row.copyWith(rate: value, clearNote: true)),
                ),
                _NumberField(
                  key: Key('ocr-quantity-${row.id}'),
                  label: 'Quantity',
                  value: row.quantity,
                  onChanged: (value) =>
                      onChanged(row.copyWith(quantity: value, clearNote: true)),
                ),
                _NumberField(
                  key: Key('ocr-total-${row.id}'),
                  label: 'Total (optional)',
                  value: row.total,
                  allowEmpty: true,
                  onChanged: (value) => onChanged(
                    row.copyWith(total: value, clearTotal: value == null),
                  ),
                ),
              ];

              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    for (final field in fields) ...[
                      field,
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: fields[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowEmpty = false,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == null ? '' : _format(value!),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (text) {
        final cleaned = text.replaceAll(',', '').trim();
        if (cleaned.isEmpty) {
          onChanged(allowEmpty ? null : -1);
          return;
        }
        onChanged(double.tryParse(cleaned) ?? -1);
      },
    );
  }

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

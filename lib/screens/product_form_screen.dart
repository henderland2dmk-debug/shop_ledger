import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../core/snackbars.dart';
import '../models/product.dart';
import '../models/product_form_result.dart';
import '../state/product_scope.dart';
import '../state/sales_scope.dart';
import '../widgets/page_width.dart';
import '../widgets/surface_card.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// When supplied, the form edits this product instead of adding a new one.
  final Product? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _particularsController;
  late final TextEditingController _rateController;
  late final TextEditingController _quantityController;
  bool _saving = false;
  bool _deleting = false;

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.]'),
  );
  static final _numberLengthFormatter = LengthLimitingTextInputFormatter(18);

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _particularsController = TextEditingController(
      text: product?.particulars ?? '',
    );
    _rateController = TextEditingController(
      text: product == null ? '' : formatEditableNumber(product.rate),
    );
    _quantityController = TextEditingController(
      text: product == null ? '' : formatEditableNumber(product.quantity),
    );
  }

  @override
  void dispose() {
    _particularsController.dispose();
    _rateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final textTheme = Theme.of(context).textTheme;
    final duplicate = isEditing
        ? null
        : ProductScope.of(context)
              .findByParticulars(_particularsController.text.trim());

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Manage product' : 'Add product'),
        actions: [
          if (isEditing)
            IconButton(
              key: const Key('delete-product-button'),
              onPressed: _deleting ? null : _confirmDelete,
              tooltip: 'Delete product',
              color: AppColors.danger,
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.danger,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: PageWidth(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isEditing) ...[
                    _ProductIdentityCard(product: widget.product!),
                    const SizedBox(height: 16),
                  ],
                  SurfaceCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isEditing ? 'Product details' : 'New product',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fields marked * are required.',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          key: const Key('particulars-field'),
                          controller: _particularsController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Particulars *',
                            hintText: 'e.g. Amul Butter 500 g',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Particulars is required';
                            }
                            return null;
                          },
                        ),
                        if (duplicate != null) ...[
                          const SizedBox(height: 12),
                          _DuplicateProductCard(product: duplicate),
                        ],
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final rateField = _buildRateField();
                            final quantityField = _buildQuantityField();

                            if (constraints.maxWidth < 460) {
                              return Column(
                                children: [
                                  rateField,
                                  const SizedBox(height: 16),
                                  quantityField,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: rateField),
                                const SizedBox(width: 14),
                                Expanded(child: quantityField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _TotalPreview(
                          total: _previewTotal,
                          rate: _previewRate,
                          quantity: _previewQuantity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('save-product-button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.check_rounded : Icons.add_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : isEditing
                          ? 'Save changes'
                          : 'Add product',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isEditing
                        ? 'Product ID and serial number stay the same. The total '
                              'is recalculated whenever rate or quantity changes.'
                        : 'A unique product ID and serial number are generated '
                              'automatically. If the name already exists, the '
                              'quantity and total are added to that product.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRateField() {
    return TextFormField(
      key: const Key('rate-field'),
      controller: _rateController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [_decimalFormatter, _numberLengthFormatter],
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Rate *',
        hintText: '0.00',
        prefixText: '₹ ',
        prefixStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return 'Rate is required';
        final rate = double.tryParse(text);
        if (rate == null || !rate.isFinite) return 'Enter a valid rate';
        if (rate < 0) return 'Rate cannot be negative';
        return null;
      },
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      key: const Key('quantity-field'),
      controller: _quantityController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [_decimalFormatter, _numberLengthFormatter],
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) => _save(),
      decoration: const InputDecoration(
        labelText: 'Quantity',
        hintText: '1',
        helperText: 'Optional — defaults to 1',
        suffixText: 'units',
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final quantity = double.tryParse(text);
        if (quantity == null || !quantity.isFinite) {
          return 'Enter a valid quantity';
        }
        if (quantity < 0) return 'Quantity cannot be negative';
        return null;
      },
    );
  }

  double? get _previewRate {
    final text = _rateController.text.trim();
    if (text.isEmpty) return null;
    final rate = double.tryParse(text);
    if (rate == null || !rate.isFinite || rate < 0) return null;
    return rate;
  }

  double? get _previewQuantity {
    final text = _quantityController.text.trim();
    if (text.isEmpty) return 1;
    final quantity = double.tryParse(text);
    if (quantity == null || !quantity.isFinite || quantity < 0) return null;
    return quantity;
  }

  double? get _previewTotal {
    final rate = _previewRate;
    final quantity = _previewQuantity;
    if (rate == null || quantity == null) return null;
    return rate * quantity;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final store = ProductScope.of(context);
    final particulars = _particularsController.text.trim();
    final rate = double.parse(_rateController.text.trim());
    final quantityText = _quantityController.text.trim();
    final quantity = quantityText.isEmpty ? 1.0 : double.parse(quantityText);

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final Product saved;
      if (widget.product == null) {
        saved = await store.addProduct(
          particulars: particulars,
          rate: rate,
          quantity: quantity,
        );
      } else {
        final updated = await store.updateProduct(
          id: widget.product!.id,
          particulars: particulars,
          rate: rate,
          quantity: quantity,
        );
        if (updated == null) {
          throw StateError('The product could not be found.');
        }
        saved = updated;
      }

      if (!mounted) return;
      Navigator.of(context).pop(ProductFormResult.saved(saved));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showBriefSnackBar(
        context,
        'Could not save the product. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete() async {
    if (_deleting || widget.product == null) return;
    final product = widget.product!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete product?',
          style: TextStyle(color: AppColors.danger),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“${product.particulars}” (${product.id}) will be permanently '
              'removed from your stock.',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF2D5D2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This cannot be undone. Once deleted, the stock data for '
                      'this product cannot be recovered. Past sales and bills '
                      'stay in your history.',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-product-button'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete product'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final productStore = ProductScope.of(context);
    final salesStore = SalesScope.of(context);
    setState(() => _deleting = true);
    try {
      final removed = await productStore.deleteProduct(product.id);
      if (removed == null) {
        throw StateError('The product could not be found.');
      }
      await salesStore.removeProductsFromBill([product.id]);
      if (!mounted) return;
      Navigator.of(context).pop(ProductFormResult.deleted(removed));
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showBriefSnackBar(
        context,
        'Could not delete the product. Please try again.',
        isError: true,
      );
    }
  }
}

class _DuplicateProductCard extends StatelessWidget {
  const _DuplicateProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softLime,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE9C8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.merge_type_rounded,
            size: 20,
            color: Color(0xFF4E7A21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Already in stock',
                  style: textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF355C17),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${product.id} · ${formatQuantity(product.quantity)} units. '
                  'Saving will add the new quantity and total to this product '
                  'instead of creating a new ID.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductIdentityCard extends StatelessWidget {
  const _ProductIdentityCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      color: AppColors.softGreen,
      borderColor: const Color(0xFFD6E6CC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRODUCT ID',
                  style: textTheme.labelSmall?.copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  product.id,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SERIAL NO.',
                style: textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 3),
              Text(
                product.serialNo.toString(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalPreview extends StatelessWidget {
  const _TotalPreview({
    required this.total,
    required this.rate,
    required this.quantity,
  });

  final double? total;
  final double? rate;
  final double? quantity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasTotal = total != null;
    final formula = hasTotal
        ? '${formatMoney(rate!)} × ${formatQuantity(quantity!)}'
        : 'Rate × quantity';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E7CE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'AUTO-CALCULATED TOTAL',
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  formula,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    hasTotal ? formatMoney(total!) : '—',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: hasTotal ? AppColors.primaryDark : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../core/product_keys.dart';
import '../core/snackbars.dart';
import '../models/product.dart';
import '../models/product_draft.dart';
import '../models/product_form_result.dart';
import '../services/excel_import_service.dart';
import '../services/ocr/ocr_service.dart';
import '../services/ocr/ocr_text_parser.dart';
import '../state/product_scope.dart';
import '../widgets/import_preview_dialog.dart';
import '../widgets/ocr_source_sheet.dart';
import '../widgets/page_width.dart';
import '../widgets/surface_card.dart';
import 'ocr_review_screen.dart';
import 'product_form_screen.dart';
import 'stock_screen.dart';

class AddProductsScreen extends StatefulWidget {
  const AddProductsScreen({super.key});

  @override
  State<AddProductsScreen> createState() => _AddProductsScreenState();
}

class _AddProductsScreenState extends State<AddProductsScreen> {
  bool _importing = false;
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final store = ProductScope.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add products')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final recent = [...store.products]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: PageWidth(
                maxWidth: 920,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Build your stock list',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Text(
                        'Bring in one item at a time, or import your full '
                        'catalogue. Every product gets a unique ID and its total '
                        'is calculated for you.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ScanCard(scanning: _scanning, onScan: _scanProducts),
                    const SizedBox(height: 16),
                    _ImportCard(
                      importing: _importing,
                      onImport: _importFromExcel,
                    ),
                    const SizedBox(height: 22),
                    const _OrDivider(),
                    const SizedBox(height: 22),
                    _ManualAddCard(onAdd: _openManualAdd, enabled: !_importing),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recently added',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            key: const Key('recent-view-stock'),
                            onPressed: _openStock,
                            child: const Text('View stock'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final product in recent.take(3)) ...[
                        _RecentProductTile(
                          product: product,
                          onTap: () => _openManage(product),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _importFromExcel() async {
    if (_importing) return;

    setState(() => _importing = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select product sheet',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final result = const ExcelImportService().parse(
        bytes,
        fileName: file.name,
      );
      if (!mounted) return;

      final store = ProductScope.of(context);
      final knownNames = store.products
          .map((product) => normalizeProductName(product.particulars))
          .toSet();
      var duplicateCount = 0;
      for (final row in result.validRows) {
        final key = normalizeProductName(row.particulars);
        if (knownNames.contains(key)) {
          duplicateCount++;
        } else {
          knownNames.add(key);
        }
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ImportPreviewDialog(
          result: result,
          duplicateCount: duplicateCount,
          note: duplicateCount > 0
              ? 'Rows that match an existing product will increase that '
                    'product’s quantity and total. Its product ID stays the same.'
              : null,
        ),
      );
      if (confirmed != true || !mounted) return;

      final drafts = [
        for (final row in result.validRows)
          ProductDraft(
            particulars: row.particulars,
            rate: row.rate!,
            quantity: row.quantity,
            total: row.total,
            serialNo: row.serialNo,
          ),
      ];

      await store.addProducts(drafts);
      if (!mounted) return;
      _showImportedSnackBar(drafts.length);
    } on ImportException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Something went wrong while importing the sheet. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _scanProducts() async {
    if (_scanning) return;
    final source = await showOcrSourceSheet(context);
    if (source == null || !mounted) return;

    final store = ProductScope.of(context);
    setState(() => _scanning = true);
    try {
      final scan = await scanText(source: source);
      if (scan == null || !mounted) return;

      final result = const OcrTextParser().parse(
        scan.text,
        imageName: scan.imageName,
      );
      if (!mounted) return;
      if (result.rows.isEmpty) {
        _showError(
          'No product rows were found. Try a clearer photo or add manually.',
        );
        return;
      }

      final rows = await Navigator.of(context).push<List<OcrDraftRow>>(
        MaterialPageRoute<List<OcrDraftRow>>(
          builder: (_) => OcrReviewScreen(
            mode: OcrReviewMode.stock,
            rows: result.rows,
            imageName: scan.imageName,
            products: store.products,
            existingNames: store.products
                .map((product) => normalizeProductName(product.particulars))
                .toSet(),
          ),
        ),
      );
      if (rows == null || !mounted || rows.isEmpty) return;

      final drafts = [
        for (final row in rows)
          ProductDraft(
            particulars: row.particulars.trim(),
            rate: row.rate,
            quantity: row.quantity,
            total: row.total,
            serialNo: row.serialNo,
          ),
      ];
      await store.addProducts(drafts);
      if (!mounted) return;
      _showImportedSnackBar(drafts.length);
    } on OcrException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not scan that image. Please try again.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _openManualAdd() async {
    final result = await Navigator.of(context).push<ProductFormResult>(
      MaterialPageRoute<ProductFormResult>(
        builder: (_) => const ProductFormScreen(),
      ),
    );
    if (!mounted || result?.saved == null) return;
    _showAddedSnackBar(result!.saved!);
  }

  Future<void> _openManage(Product product) async {
    final result = await Navigator.of(context).push<ProductFormResult>(
      MaterialPageRoute<ProductFormResult>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
    if (!mounted || result == null) return;

    if (result.isDeleted) {
      showBriefSnackBar(context, '${result.deleted!.id} deleted from stock.');
      return;
    }
    _showUpdatedSnackBar(result.saved!);
  }

  void _openStock() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const StockScreen()));
  }

  void _showAddedSnackBar(Product product) {
    final navigator = Navigator.of(context);
    showBriefSnackBar(
      context,
      '“${product.particulars}” added as ${product.id}.',
      action: SnackBarAction(
        label: 'View stock',
        onPressed: () => navigator.push(
          MaterialPageRoute<void>(builder: (_) => const StockScreen()),
        ),
      ),
    );
  }

  void _showImportedSnackBar(int count) {
    final navigator = Navigator.of(context);
    final label = count == 1
        ? '1 product added or updated.'
        : '$count products added or updated.';

    showBriefSnackBar(
      context,
      label,
      action: SnackBarAction(
        label: 'View stock',
        onPressed: () => navigator.push(
          MaterialPageRoute<void>(builder: (_) => const StockScreen()),
        ),
      ),
    );
  }

  void _showUpdatedSnackBar(Product product) {
    showBriefSnackBar(context, '${product.id} updated.');
  }

  void _showError(String message) {
    showBriefSnackBar(context, message, isError: true);
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.scanning, required this.onScan});

  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      color: const Color(0xFFF3F7EF),
      borderColor: const Color(0xFFD6E6CC),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan a product list', style: textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      'Open the camera or upload a photo of a bill or paper. '
                      'Review every row before adding it to stock.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('scan-stock-button'),
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.photo_camera_outlined, size: 19),
                label: Text(scanning ? 'Reading…' : 'Scan list'),
              ),
              Text(
                'Same columns as Excel: S.no, Rate, Particulars, Qty, Total.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({required this.importing, required this.onImport});

  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import from Excel', style: textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      'Upload an .xlsx sheet with your product list.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPECTED COLUMNS',
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ColumnChip(label: 'Serial no'),
                    _ColumnChip(label: 'Rate', required: true),
                    _ColumnChip(label: 'Particulars', required: true),
                    _ColumnChip(label: 'Quantity'),
                    _ColumnChip(label: 'Total'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Only Particulars and Rate are required. Quantity defaults '
                  'to 1, and Total is calculated automatically when left blank. '
                  'Matching names add to the existing product.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('import-excel-button'),
                onPressed: importing ? null : onImport,
                icon: importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_upload_outlined, size: 19),
                label: Text(
                  importing ? 'Reading sheet…' : 'Upload Excel sheet',
                ),
              ),
              Text(
                'Uses the first sheet in the workbook.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColumnChip extends StatelessWidget {
  const _ColumnChip({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: required ? AppColors.softGreen : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: required ? const Color(0xFFCDDFC3) : AppColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: required ? FontWeight.w700 : FontWeight.w500,
              color: required ? AppColors.primaryDark : AppColors.muted,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 2),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR ADD MANUALLY',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w700),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _ManualAddCard extends StatelessWidget {
  const _ManualAddCard({required this.onAdd, required this.enabled});

  final VoidCallback onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final info = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.softLime,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.add_circle_outline_rounded,
            color: Color(0xFF4E7A21),
            size: 25,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a product manually', style: textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                'Particulars and rate are all you need. Quantity defaults to 1 '
                'and the total is automatic.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );

    final button = OutlinedButton.icon(
      key: const Key('manual-add-button'),
      onPressed: enabled ? onAdd : null,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: const Text('Add product'),
    );

    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 540) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 16), button],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _RecentProductTile extends StatelessWidget {
  const _RecentProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              product.serialNo.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.particulars,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _CodeChip(text: product.id),
                    Text(
                      'Qty ${formatQuantity(product.quantity)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                    Text(
                      'Total ${formatMoney(product.total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5EF),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

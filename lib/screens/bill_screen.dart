import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../core/customer_keys.dart';
import '../core/formatters.dart';
import '../core/snackbars.dart';
import '../models/bill_item.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/bill_import_service.dart';
import '../services/bill_pdf_service.dart';
import '../services/excel_import_service.dart';
import '../services/ocr/ocr_service.dart';
import '../services/ocr/ocr_text_parser.dart';
import '../state/product_scope.dart';
import '../state/product_store.dart';
import '../state/sales_scope.dart';
import '../state/sales_store.dart';
import '../widgets/bill_import_preview_dialog.dart';
import '../widgets/ocr_source_sheet.dart';
import '../widgets/page_width.dart';
import '../widgets/surface_card.dart';
import 'add_products_screen.dart';
import 'ocr_review_screen.dart';
import 'sales_history_screen.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  String _query = '';
  bool _customerInitialized = false;
  bool _importing = false;
  bool _scanning = false;
  bool _busy = false;
  Sale? _completedSale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_customerInitialized) {
      _customerController.text = SalesScope.of(context).draftCustomerName;
      _customerInitialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productStore = ProductScope.of(context);
    final salesStore = SalesScope.of(context);
    final completed = _completedSale;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          completed == null ? 'Create a bill' : 'Bill ${completed.id}',
        ),
        actions: [
          IconButton(
            tooltip: 'Sales history',
            onPressed: _openSalesHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: productStore,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: salesStore,
              builder: (context, _) {
                if (completed != null) {
                  return _CompletedBillView(
                    sale: completed,
                    busy: _busy,
                    onPrint: () => _printBill(completed),
                    onDownload: () => _downloadBill(completed),
                    onNewBill: _startNewBill,
                    onViewHistory: _openSalesHistory,
                  );
                }
                return _buildDraftView(context, productStore, salesStore);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDraftView(
    BuildContext context,
    ProductStore productStore,
    SalesStore salesStore,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filterProducts(productStore.products);
    final items = salesStore.draftItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 36),
      child: PageWidth(
        maxWidth: 1180,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Build a sale bill', style: textTheme.headlineMedium),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(
                'Tap + beside a stock item to add it to the bill. Tap as many '
                'times as you need — every tap adds one more unit.',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 22),
            _BillSummary(
              salesStore: salesStore,
              importing: _importing,
              scanning: _scanning,
              onImport: _importItems,
              onScan: _scanBillItems,
              onPrint: items.isEmpty
                  ? null
                  : () => _printBill(_draftAsSale(items, salesStore)),
              onDownload: items.isEmpty
                  ? null
                  : () => _downloadBill(_draftAsSale(items, salesStore)),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stockPanel = _StockPanel(
                  products: filtered,
                  totalProducts: productStore.products.length,
                  query: _query,
                  searchController: _searchController,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onClearSearch: _clearSearch,
                  quantityInBill: salesStore.quantityInBill,
                  onAdd: _addToBill,
                  onAddProducts: _openAddProducts,
                );

                final billPanel = _BillPanel(
                  items: items,
                  customerController: _customerController,
                  onCustomerChanged: (value) =>
                      unawaited(salesStore.setCustomerName(value)),
                  onPickCustomer: _showCustomerPicker,
                  busy: _busy,
                  onChangeQuantity: (item, delta) =>
                      _changeQuantity(item, delta),
                  onRemove: (item) =>
                      unawaited(salesStore.removeFromBill(item.productId)),
                  onClear: () => unawaited(salesStore.clearBill()),
                  onSell: _sell,
                );

                if (constraints.maxWidth < 940) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stockPanel,
                      const SizedBox(height: 16),
                      billPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: stockPanel),
                    const SizedBox(width: 16),
                    SizedBox(width: 372, child: billPanel),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return products;

    return products
        .where((product) {
          return product.particulars.toLowerCase().contains(query) ||
              product.id.toLowerCase().contains(query) ||
              product.serialNo.toString() == query;
        })
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Sale _draftAsSale(List<BillItem> items, SalesStore salesStore) {
    return Sale(
      id: 'BILL-DRAFT',
      soldAt: DateTime.now(),
      customerName: salesStore.draftCustomerName.isEmpty
          ? walkInCustomer
          : salesStore.draftCustomerName,
      items: items,
    );
  }

  Future<void> _addToBill(Product product) async {
    final salesStore = SalesScope.of(context);
    final inBill = salesStore.quantityInBill(product.id);
    if (product.quantity <= 0 || inBill >= product.quantity) {
      _showMessage('No more ${product.particulars} left in stock.');
      return;
    }
    await salesStore.addToBill(product);
  }

  Future<void> _changeQuantity(BillItem item, double delta) async {
    final productStore = ProductScope.of(context);
    final salesStore = SalesScope.of(context);
    final product = productStore.findById(item.productId);

    if (delta > 0 && product != null) {
      final next = item.quantity + delta;
      if (next > product.quantity) {
        _showMessage('Only ${formatQuantity(product.quantity)} available.');
        return;
      }
    }

    await salesStore.changeBillQuantity(item.productId, delta);
  }

  Future<void> _importItems() async {
    if (_importing) return;
    final productStore = ProductScope.of(context);
    final salesStore = SalesScope.of(context);

    setState(() => _importing = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select bill items sheet',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final result = BillImportService(
        products: productStore.products,
        currentBill: salesStore.draftItems,
      ).parse(bytes, fileName: file.name);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => BillImportPreviewDialog(result: result),
      );
      if (confirmed != true || !mounted) return;

      await salesStore.addBillItems(result.items);
      if (!mounted) return;

      final skipped = result.issueCount == 0
          ? ''
          : ' ${result.issueCount} row(s) skipped.';
      _showMessage('${result.itemCount} line(s) added to the bill.$skipped');
    } on ImportException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not read that sheet. Please try again.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _scanBillItems() async {
    if (_scanning) return;
    final source = await showOcrSourceSheet(context);
    if (source == null || !mounted) return;

    final productStore = ProductScope.of(context);
    final salesStore = SalesScope.of(context);
    setState(() => _scanning = true);
    try {
      final scan = await scanText(source: source);
      if (scan == null || !mounted) return;

      final result = const OcrTextParser().parse(
        scan.text,
        imageName: scan.imageName,
        products: productStore.products,
      );
      if (!mounted) return;
      if (result.rows.isEmpty) {
        _showError(
          'No item rows were found. Try a clearer photo or import a sheet.',
        );
        return;
      }

      final rows = await Navigator.of(context).push<List<OcrDraftRow>>(
        MaterialPageRoute<List<OcrDraftRow>>(
          builder: (_) => OcrReviewScreen(
            mode: OcrReviewMode.bill,
            rows: result.rows,
            imageName: scan.imageName,
            products: productStore.products,
            existingBillQuantities: {
              for (final item in salesStore.draftItems)
                item.productId: salesStore.quantityInBill(item.productId),
            },
          ),
        ),
      );
      if (rows == null || !mounted || rows.isEmpty) return;

      final productsById = {
        for (final product in productStore.products) product.id: product,
      };
      final items = <BillItem>[];
      for (final row in rows) {
        final product = productsById[row.productId];
        if (product == null) continue;
        items.add(
          BillItem(
            productId: product.id,
            serialNo: product.serialNo,
            particulars: product.particulars,
            rate: row.rate,
            quantity: row.quantity,
          ),
        );
      }
      if (items.isEmpty || !mounted) return;

      await salesStore.addBillItems(items);
      if (!mounted) return;
      _showMessage('${rows.length} scanned row(s) added to the bill.');
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

  Future<void> _sell() async {
    if (_busy) return;
    final productStore = ProductScope.of(context);
    final salesStore = SalesScope.of(context);
    if (!salesStore.hasDraftItems) return;

    final problems = productStore.checkStockAvailability(salesStore.draftItems);
    if (problems.isNotEmpty) {
      _showError(problems.first);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _SellConfirmationDialog(salesStore: salesStore),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final sale = await salesStore.commitSale(productStore: productStore);
      if (sale == null) throw StateError('The bill was empty.');
      if (!mounted) return;
      setState(() => _completedSale = sale);
      _customerController.clear();
    } on StockShortfallException catch (error) {
      if (!mounted) return;
      _showError(error.messages.first);
    } catch (_) {
      if (!mounted) return;
      _showError('The sale could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printBill(Sale sale) async {
    try {
      final printed = await Printing.layoutPdf(
        name: 'Bill ${sale.id}',
        onLayout: (_) => buildBillPdf(sale),
      );
      if (!printed && mounted) _showMessage('Print cancelled.');
    } catch (_) {
      if (mounted) _showError('Printing is not available on this device.');
    }
  }

  Future<void> _downloadBill(Sale sale) async {
    try {
      final bytes = await buildBillPdf(sale);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${sale.id}.pdf',
        subject: 'Sale bill ${sale.id}',
      );
    } catch (_) {
      if (mounted) _showError('The PDF could not be downloaded.');
    }
  }

  void _startNewBill() {
    _customerController.clear();
    _searchController.clear();
    setState(() {
      _query = '';
      _completedSale = null;
    });
  }

  void _openAddProducts() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddProductsScreen()));
  }

  void _openSalesHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SalesHistoryScreen()));
  }

  Future<void> _showCustomerPicker() async {
    final salesStore = SalesScope.of(context);
    final walkInKey = normalizeCustomerName(walkInCustomer);
    final customers = salesStore.customerBillGroups
        .where(
          (group) =>
              group.customerName.trim().isNotEmpty &&
              normalizeCustomerName(group.customerName) != walkInKey,
        )
        .toList(growable: false);

    if (customers.isEmpty) {
      _showMessage('No previous customers yet. Type a name to save one.');
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Previous customers',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select one to store this bill under their name.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final group = customers[index];
                      final key = normalizeCustomerName(group.customerName)
                          .replaceAll(' ', '-');
                      return ListTile(
                        key: Key('bill-customer-option-$key'),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.softGreen,
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primary,
                            size: 19,
                          ),
                        ),
                        title: Text(group.customerName),
                        subtitle: Text(
                          '${group.billCount} bill(s) · '
                          '${formatMoney(group.totalAmount)}',
                        ),
                        onTap: () =>
                            Navigator.of(context).pop(group.customerName),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    _customerController.text = selected;
    await salesStore.setCustomerName(selected);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showBriefSnackBar(context, message);
  }

  void _showError(String message) {
    if (!mounted) return;
    showBriefSnackBar(context, message, isError: true);
  }
}

class _BillSummary extends StatelessWidget {
  const _BillSummary({
    required this.salesStore,
    required this.importing,
    required this.scanning,
    required this.onImport,
    required this.onScan,
    required this.onPrint,
    required this.onDownload,
  });

  final SalesStore salesStore;
  final bool importing;
  final bool scanning;
  final VoidCallback onImport;
  final VoidCallback onScan;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.softGreen,
      borderColor: const Color(0xFFD6E6CC),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stats = Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Lines',
                  value: salesStore.draftLineCount.toString(),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _MiniStat(
                  label: 'Units',
                  value: formatQuantity(salesStore.draftQuantity),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _MiniStat(
                  label: 'Bill total',
                  value: formatMoney(salesStore.draftTotal),
                  highlight: true,
                ),
              ),
            ],
          );

          final buttons = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('bill-scan-button'),
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(scanning ? 'Scanning…' : 'Scan list'),
              ),
              OutlinedButton.icon(
                key: const Key('bill-import-button'),
                onPressed: importing ? null : onImport,
                icon: importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(importing ? 'Reading…' : 'Import Excel'),
              ),
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download PDF'),
              ),
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
              ),
            ],
          );

          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [stats, const SizedBox(height: 18), buttons],
            );
          }

          return Row(
            children: [
              Expanded(child: stats),
              const SizedBox(width: 20),
              Flexible(child: buttons),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primaryDark : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockPanel extends StatelessWidget {
  const _StockPanel({
    required this.products,
    required this.totalProducts,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.quantityInBill,
    required this.onAdd,
    required this.onAddProducts,
  });

  final List<Product> products;
  final int totalProducts;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final double Function(String productId) quantityInBill;
  final ValueChanged<Product> onAdd;
  final VoidCallback onAddProducts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Available stock', style: textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Add products to stock',
                onPressed: onAddProducts,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('bill-search-field'),
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search stock by name, ID or serial no.',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            query.trim().isEmpty
                ? '$totalProducts product(s) in stock'
                : '${products.length} of $totalProducts shown',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (totalProducts == 0)
            _EmptyStockPanel(onAddProducts: onAddProducts)
          else if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'Nothing matches “$query”. Try another search.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            )
          else
            for (final product in products) ...[
              _StockAddTile(
                product: product,
                inBill: quantityInBill(product.id),
                onAdd: () => onAdd(product),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _EmptyStockPanel extends StatelessWidget {
  const _EmptyStockPanel({required this.onAddProducts});

  final VoidCallback onAddProducts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.softLime,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 30,
            color: Color(0xFF4E7A21),
          ),
          const SizedBox(height: 10),
          Text(
            'There is no stock to sell yet.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Add products first, then build a bill from them.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAddProducts,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add products'),
          ),
        ],
      ),
    );
  }
}

class _StockAddTile extends StatelessWidget {
  const _StockAddTile({
    required this.product,
    required this.inBill,
    required this.onAdd,
  });

  final Product product;
  final double inBill;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final available = product.quantity - inBill;
    final enabled = available > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              '${product.serialNo}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(formatMoney(product.rate), style: textTheme.bodySmall),
                    Text(
                      '${formatQuantity(available)} available',
                      style: textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? AppColors.primaryDark
                            : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (inBill > 0)
                      Text(
                        '${formatQuantity(inBill)} in bill',
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF4E7A21),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            key: Key('bill-add-${product.id}'),
            onPressed: enabled ? onAdd : null,
            tooltip: 'Add one unit to the bill',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _BillPanel extends StatelessWidget {
  const _BillPanel({
    required this.items,
    required this.customerController,
    required this.onCustomerChanged,
    required this.onPickCustomer,
    required this.busy,
    required this.onChangeQuantity,
    required this.onRemove,
    required this.onClear,
    required this.onSell,
  });

  final List<BillItem> items;
  final TextEditingController customerController;
  final ValueChanged<String> onCustomerChanged;
  final VoidCallback onPickCustomer;
  final bool busy;
  final void Function(BillItem item, double delta) onChangeQuantity;
  final ValueChanged<BillItem> onRemove;
  final VoidCallback onClear;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = items.fold(0.0, (sum, item) => sum + item.total);

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Bill items', style: textTheme.titleLarge)),
              if (items.isNotEmpty)
                TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('bill-customer-field'),
            controller: customerController,
            onChanged: onCustomerChanged,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Customer (optional)',
              hintText: 'e.g. Ramesh Kumar',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              suffixIcon: IconButton(
                key: const Key('bill-customer-picker'),
                tooltip: 'Previous customers',
                color: AppColors.primary,
                onPressed: onPickCustomer,
                icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.softLime,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 30,
                    color: Color(0xFF4E7A21),
                  ),
                  const SizedBox(height: 10),
                  Text('Your bill is empty', style: textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Use + on any stock item, or import an Excel list.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            for (final item in items) ...[
              _BillItemTile(
                item: item,
                onChange: (delta) => onChangeQuantity(item, delta),
                onRemove: () => onRemove(item),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Bill total', style: textTheme.titleMedium)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatMoney(total),
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('confirm-sale-button'),
            onPressed: items.isEmpty || busy ? null : onSell,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sell_outlined),
            label: Text(busy ? 'Selling…' : 'Sell and update stock'),
          ),
          const SizedBox(height: 10),
          Text(
            'The selected quantities are removed from stock only after you '
            'confirm the sale.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BillItemTile extends StatelessWidget {
  const _BillItemTile({
    required this.item,
    required this.onChange,
    required this.onRemove,
  });

  final BillItem item;
  final void Function(double delta) onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.particulars,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatMoney(item.rate)} × ${formatQuantity(item.quantity)}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(item.total),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      onPressed: () => onChange(-1),
                      tooltip: 'Remove one unit',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      formatQuantity(item.quantity),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      onPressed: () => onChange(1),
                      tooltip: 'Add one unit',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                    ),
                  ),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: IconButton(
                      onPressed: onRemove,
                      tooltip: 'Remove line',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SellConfirmationDialog extends StatelessWidget {
  const _SellConfirmationDialog({required this.salesStore});

  final SalesStore salesStore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Confirm sale'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will deduct ${formatQuantity(salesStore.draftQuantity)} units '
            'from your stock and save a permanent bill.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Bill total', style: textTheme.titleSmall),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatMoney(salesStore.draftTotal),
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
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
          key: const Key('confirm-sale-dialog-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes, sell'),
        ),
      ],
    );
  }
}

class _CompletedBillView extends StatelessWidget {
  const _CompletedBillView({
    required this.sale,
    required this.busy,
    required this.onPrint,
    required this.onDownload,
    required this.onNewBill,
    required this.onViewHistory,
  });

  final Sale sale;
  final bool busy;
  final VoidCallback onPrint;
  final VoidCallback onDownload;
  final VoidCallback onNewBill;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 36),
      child: PageWidth(
        maxWidth: 860,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD6E6CC)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sale completed', style: textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          '${sale.id} saved. Stock has been updated.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SurfaceCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bill ${sale.id}',
                          style: textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        formatDateTime(sale.soldAt),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer: ${sale.customerName}',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  for (final item in sale.items) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${formatQuantity(item.quantity)} × ${item.particulars}',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          formatMoney(item.total),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Grand total',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        formatMoney(sale.totalAmount),
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print bill'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Sales history'),
                ),
                TextButton(
                  onPressed: onNewBill,
                  child: const Text('Start a new bill'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

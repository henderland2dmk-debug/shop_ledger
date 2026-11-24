import 'package:flutter/widgets.dart';

import 'product_store.dart';

/// Makes the single [ProductStore] available to every route.
class ProductScope extends InheritedNotifier<ProductStore> {
  const ProductScope({
    super.key,
    required ProductStore store,
    required super.child,
  }) : super(notifier: store);

  static ProductStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProductScope>();
    assert(scope != null, 'No ProductScope found in the widget tree.');
    return scope!.notifier!;
  }
}

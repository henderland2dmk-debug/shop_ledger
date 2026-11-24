import 'package:flutter/widgets.dart';

import 'sales_store.dart';

/// Makes the single [SalesStore] available to every route.
class SalesScope extends InheritedNotifier<SalesStore> {
  const SalesScope({super.key, required SalesStore store, required super.child})
    : super(notifier: store);

  static SalesStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SalesScope>();
    assert(scope != null, 'No SalesScope found in the widget tree.');
    return scope!.notifier!;
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'state/product_scope.dart';
import 'state/product_store.dart';
import 'state/sales_scope.dart';
import 'state/sales_store.dart';

class ShopLedgerApp extends StatelessWidget {
  const ShopLedgerApp({
    super.key,
    required this.store,
    required this.salesStore,
  });

  final ProductStore store;
  final SalesStore salesStore;

  @override
  Widget build(BuildContext context) {
    return ProductScope(
      store: store,
      child: SalesScope(
        store: salesStore,
        child: MaterialApp(
          title: 'Mano Agency',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          scrollBehavior: const _AppScrollBehavior(),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/product_store.dart';
import 'state/sales_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final store = ProductStore(preferences);
  final salesStore = SalesStore(preferences);

  runApp(ShopLedgerApp(store: store, salesStore: salesStore));
}

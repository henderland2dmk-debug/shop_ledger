import 'package:flutter/foundation.dart';

import 'product.dart';

/// What the product form returned when it was closed.
@immutable
class ProductFormResult {
  const ProductFormResult._({this.saved, this.deleted});

  factory ProductFormResult.saved(Product product) =>
      ProductFormResult._(saved: product);

  factory ProductFormResult.deleted(Product product) =>
      ProductFormResult._(deleted: product);

  final Product? saved;
  final Product? deleted;

  bool get isDeleted => deleted != null;
}

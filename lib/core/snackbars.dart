import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Bottom messages should be quick hints, not something the user has to
/// dismiss. Two seconds is long enough to read a short confirmation.
const Duration briefSnackBarDuration = Duration(seconds: 2);

void showBriefSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: isError ? const TextStyle(color: Colors.white) : null,
        ),
        duration: briefSnackBarDuration,
        action: action,
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
}

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The shop's logo, shown as a small rounded tile.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F17211B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        'assets/logo/mano-agency-logo.jpeg',
        fit: BoxFit.cover,
      ),
    );
  }
}

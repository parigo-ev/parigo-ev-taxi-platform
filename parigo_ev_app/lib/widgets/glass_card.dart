import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(24.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.4), // More transparent for authentic glass
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
                color: AppTheme.onSurface.withOpacity(0.1),
                width: 1.5), // Visible glass border
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), // Soft shadow
                blurRadius: 24,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

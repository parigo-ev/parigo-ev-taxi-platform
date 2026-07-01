import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryContainer, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryContainer.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: onPressed,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.onPrimary,
                        letterSpacing: 1.5,
                      ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: AppTheme.onPrimary),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

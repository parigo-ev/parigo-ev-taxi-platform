import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PermissionDisclosureDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const PermissionDisclosureDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
  }) : super(key: key);

  static Future<bool?> show(BuildContext context, {required String title, required String message, required IconData icon}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDisclosureDialog(title: title, message: message, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: AppTheme.primaryContainer, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.nunito(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: AppTheme.onSurfaceVariant,
          fontSize: 15,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryContainer,
            foregroundColor: AppTheme.onPrimaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

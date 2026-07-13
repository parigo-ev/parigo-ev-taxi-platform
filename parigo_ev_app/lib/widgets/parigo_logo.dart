import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
class ParigoLogo extends StatelessWidget {
  final TextStyle? textStyle;
  
  const ParigoLogo({Key? key, this.textStyle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.displayLarge;
    final fontSize = style?.fontSize ?? 48.0;
    
    final gradientStyle = style?.copyWith(
      foreground: Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.primaryContainer, AppTheme.primary],
        ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'PAR',
          style: GoogleFonts.audiowide(textStyle: gradientStyle),
        ),
        Icon(
          Icons.bolt,
          color: AppTheme.primary,
          size: fontSize * 1.1, // slightly larger to match text height
        ),
        Text(
          'GO EV',
          style: GoogleFonts.audiowide(textStyle: gradientStyle),
        ),
      ],
    );
  }
}

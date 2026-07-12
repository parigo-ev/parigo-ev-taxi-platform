import 'package:flutter/material.dart';

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
          'PARIG',
          style: GoogleFonts.audiowide(textStyle: gradientStyle),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'O',
              style: GoogleFonts.audiowide(textStyle: gradientStyle),
            ),
            Icon(
              Icons.bolt,
              color: AppTheme.primary,
              size: fontSize * 0.45, // Fits nicely inside the 'O'
            ),
          ],
        ),
        Text(
          ' EV',
          style: GoogleFonts.audiowide(textStyle: gradientStyle),
        ),
      ],
    );
  }
}

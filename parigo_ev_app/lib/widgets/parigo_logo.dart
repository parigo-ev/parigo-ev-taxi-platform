import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'parigo_icon_i.dart';

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
          colors: [
            Color(0xFF10B981), // Emerald Green
            Color(0xFF059669), // Dark Emerald
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0.0, 0.0, fontSize * 6, fontSize)),
    );

    final double iconSize = fontSize;
    final double iconWidth = iconSize * 1.25;
    final double spacing = fontSize * 0.12;

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'PAR',
              style: GoogleFonts.audiowide(textStyle: gradientStyle),
            ),
            SizedBox(width: iconWidth + spacing * 2),
            Text(
              'GO EV',
              style: GoogleFonts.audiowide(textStyle: gradientStyle),
            ),
          ],
        ),
        ParigoIconI(
          size: iconSize,
          colors: const [
            Color(0xFF10B981), // Emerald Green
            Color(0xFF059669), // Dark Emerald
          ],
        ),
      ],
    );
  }
}


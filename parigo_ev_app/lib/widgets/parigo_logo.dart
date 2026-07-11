import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0.0, 0.0, fontSize * 6.0, fontSize)),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'PARIG',
          style: GoogleFonts.audiowide(textStyle: gradientStyle),
        ),
        SizedBox(width: fontSize * 0.08),
        ParigoIconO(size: fontSize),
        SizedBox(width: fontSize * 0.08),
        Text(
          'EV',
          style: GoogleFonts.audiowide(textStyle: gradientStyle),
        ),
      ],
    );
  }
}

class ParigoIconO extends StatelessWidget {
  final double size;

  const ParigoIconO({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.05, size * 0.82),
      painter: _ParigoIconOPainter(),
    );
  }
}

class _ParigoIconOPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Outer rounded rectangle path
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.25));
    final outerPath = Path()..addRRect(rrect);

    // Inner lightning bolt cutout path
    final w = size.width;
    final h = size.height;
    final boltPath = Path();
    
    // Sharp stylized lightning bolt vertices
    boltPath.moveTo(w * 0.58, h * 0.18);
    boltPath.lineTo(w * 0.68, h * 0.48);
    boltPath.lineTo(w * 0.54, h * 0.48);
    boltPath.lineTo(w * 0.42, h * 0.82);
    boltPath.lineTo(w * 0.32, h * 0.52);
    boltPath.lineTo(w * 0.46, h * 0.52);
    boltPath.close();

    // Create cutout by subtracting bolt path from outer rrect
    final combinedPath = Path.combine(PathOperation.difference, outerPath, boltPath);

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

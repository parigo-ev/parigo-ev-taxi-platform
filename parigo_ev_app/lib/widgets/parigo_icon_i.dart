import 'package:flutter/material.dart';

class ParigoIconI extends StatelessWidget {
  final double size;
  final List<Color>? colors;

  const ParigoIconI({
    Key? key,
    required this.size,
    this.colors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The "I" icon box aspect ratio: width is ~1.2x of the height (font height / size)
    final double computedWidth = size * 1.25;
    final double computedHeight = size * 0.85;

    final defaultColors = colors ?? [
      const Color(0xFF10B981), // Emerald Green
      const Color(0xFF059669), // Dark Emerald
    ];

    return SizedBox(
      width: computedWidth,
      height: computedHeight,
      child: CustomPaint(
        painter: ParigoIconIPainter(
          colors: defaultColors,
        ),
      ),
    );
  }
}

class ParigoIconIPainter extends CustomPainter {
  final List<Color> colors;

  ParigoIconIPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Linear gradient across the diagonal of the icon box
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    // Outer rounded box (capsule) filling the canvas
    final Rect boxRect = Rect.fromLTWH(0, 0, w, h);
    final RRect boxRRect = RRect.fromRectAndRadius(boxRect, Radius.circular(h * 0.22));

    // Lightning bolt cutout coordinates centered in the box
    final double cx = w / 2;
    final double cy = h / 2;
    final double bw = w * 0.40;
    final double bh = h * 0.65;

    final Path boltPath = Path();
    boltPath.moveTo(cx + bw * 0.15, cy - bh * 0.45); // Top right start
    boltPath.lineTo(cx - bw * 0.40, cy + bh * 0.02); // Zig-zag down-left
    boltPath.lineTo(cx - bw * 0.08, cy + bh * 0.02); // Horiz right bend
    boltPath.lineTo(cx - bw * 0.25, cy + bh * 0.45); // Down-left to bottom tip
    boltPath.lineTo(cx + bw * 0.40, cy - bh * 0.02); // Zig-zag up-right
    boltPath.lineTo(cx + bw * 0.08, cy - bh * 0.02); // Horiz left bend
    boltPath.close();

    final Path outerPath = Path()..addRRect(boxRRect);
    final Path combinedPath = Path.combine(PathOperation.difference, outerPath, boltPath);
    
    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

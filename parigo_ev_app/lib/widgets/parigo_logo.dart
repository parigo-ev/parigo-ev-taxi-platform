import 'package:flutter/material.dart';

class ParigoLogo extends StatelessWidget {
  final TextStyle? textStyle;
  
  const ParigoLogo({Key? key, this.textStyle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.displayLarge;
    final fontSize = style?.fontSize ?? 48.0;
    
    // Scale logo height relative to the requested font size
    return Image.asset(
      'assets/images/logo.png',
      height: fontSize * 1.2,
      fit: BoxFit.contain,
    );
  }
}

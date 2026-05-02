import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/bolt.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

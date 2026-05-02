import 'dart:math';

import 'package:flutter/material.dart';

/// Card 3D que vira (flip) entre frente e verso.
///
/// Controlado externamente via [showBack] — o pai decide quando virar
/// (ex: ao clicar). Anima rotação Y de 0 a π.
class FlipCard extends StatelessWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
    this.onTap,
  });

  final Widget front;
  final Widget back;
  final bool showBack;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: showBack ? pi : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (_, value, __) {
          final isBack = value > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _Face(isBack: true, child: back),
                  )
                : _Face(isBack: false, child: front),
          );
        },
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.child, required this.isBack});
  final Widget child;
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBack
              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
              : Colors.white12,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AuraScaffold extends StatelessWidget {
  const AuraScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          const _AuraBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuraBackground extends StatelessWidget {
  const _AuraBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              Color(0xFFE5ECFF),
              Color(0xFFFFF1D6),
            ],
          ),
        ),
        child: Stack(
          children: const [
            _GlowBlob(
              alignment: Alignment(-1.1, -0.9),
              size: 260,
              color: Color(0xFF8FB0FF),
            ),
            _GlowBlob(
              alignment: Alignment(1.1, -0.6),
              size: 220,
              color: Color(0xFFFFC978),
            ),
            _GlowBlob(
              alignment: Alignment(-0.2, 1.1),
              size: 240,
              color: Color(0xFF7DE3C1),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(89),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(102),
              blurRadius: 120,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

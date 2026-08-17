import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

enum LoadingSize { small, medium, large }

class LoadingSpinner extends StatelessWidget {

  final String? message;

  final LoadingSize size;

  final double? strokeWidth;

  final Color? color;

  const LoadingSpinner({
    super.key,
    this.message,
    this.size        = LoadingSize.medium,
    this.strokeWidth,
    this.color,
  });

  double get _spinnerSize {
    switch (size) {
      case LoadingSize.small:  return 20;
      case LoadingSize.medium: return 36;
      case LoadingSize.large:  return 52;
    }
  }

  double get _stroke {
    if (strokeWidth != null) return strokeWidth!;
    switch (size) {
      case LoadingSize.small:  return 2.0;
      case LoadingSize.medium: return 3.0;
      case LoadingSize.large:  return 3.5;
    }
  }

  double get _messageFontSize {
    switch (size) {
      case LoadingSize.small:  return 11;
      case LoadingSize.medium: return 13;
      case LoadingSize.large:  return 15;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Spinner ─────────────────────────────────────
          SizedBox(
            width:  _spinnerSize,
            height: _spinnerSize,
            child: CircularProgressIndicator(
              color:       color ?? AppColors.primary,
              strokeWidth: _stroke,
              // Rounded ends look more polished
              strokeCap: StrokeCap.round,
            ),
          ),

          // ── Message ─────────────────────────────────────
          if (message != null) ...[
            SizedBox(height: size == LoadingSize.small ? 8 : 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   _messageFontSize,
                color:      AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                height:     1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {

  final bool isLoading;

  final Widget child;

  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        child,

        if (isLoading)
          Positioned.fill(
            child: Container(
              color: AppColors.background.withOpacity(0.75),
              child: LoadingSpinner(
                message:     message,
                size:        LoadingSize.large,
              ),
            ),
          ),
      ],
    );
  }
}


class InlineSpinner extends StatelessWidget {

  final double size;

  final Color? color;

  const InlineSpinner({
    super.key,
    this.size  = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child: CircularProgressIndicator(
        color:       color ?? AppColors.primary,
        strokeWidth: 2.0,
        strokeCap:   StrokeCap.round,
      ),
    );
  }
}

class ShimmerBox extends StatefulWidget {
  final double  width;
  final double  height;
  final double  borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true); // pulsing back and forth

    _anim = Tween<double>(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          // Pulses between light and slightly darker
          color: AppColors.secondaryLight.withOpacity(_anim.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Image placeholder
              const ShimmerBox(width: 48, height: 48, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 140, height: 13),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 90, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 11),
          const SizedBox(height: 5),
          const ShimmerBox(width: 180, height: 11),
        ],
      ),
    );
  }
}
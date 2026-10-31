import 'package:flutter/material.dart';

/// Central paths and constants for Food Flow brand assets
class AppBrandAssets {
  static const String wordmarkLogo = 'assets/images/foodflow_wordmark.png';
  static const String iconLogo = 'assets/images/foodflow_icon.png';
}

/// The official Word Mark Logo
/// Displays the complete branded graphic: bowl of food, steam, heart,
/// and the custom "FoodFlow" serif wordmark with the golden leaf accent.
class FoodFlowWordmark extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const FoodFlowWordmark({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      AppBrandAssets.wordmarkLogo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width ?? 180,
          height: height ?? 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF9E6),
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4BC4B), width: 1.2),
          ),
          child: const Text(
            'Food Flow',
            style: TextStyle(
              color: Color(0xFF6B4B03),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    if (boxShadow != null) {
      image = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: image,
      );
    }

    return image;
  }
}

/// The official Food Flow Icon mark
/// Displays the square/rounded emblem containing the hands, warm soup bowl,
/// steam, golden heart, and leaf accent (without the "FoodFlow" text).
class FoodFlowIcon extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;

  const FoodFlowIcon({
    super.key,
    this.size = 38,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.26);

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: effectiveRadius,
        border: border,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: const Color(0xFFFFC107).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Image.asset(
          AppBrandAssets.iconLogo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              color: const Color(0xFFFFC107),
              child: Icon(
                Icons.restaurant_rounded,
                color: Colors.black87,
                size: size * 0.55,
              ),
            );
          },
        ),
      ),
    );
  }
}

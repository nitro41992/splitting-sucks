import 'package:flutter/material.dart';

class SubtotalHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final bool isCollapsed;
  final double subtotal;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  
  // Add new parameters for Neumorphic style
  final bool useNeumorphicStyle;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? accentColor;

  SubtotalHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.isCollapsed,
    required this.subtotal,
    required this.colorScheme,
    required this.textTheme,
    this.useNeumorphicStyle = false,
    this.backgroundColor,
    this.textColor,
    this.accentColor,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate the percentage of shrinking (0.0 to 1.0)
    final double shrinkPercentage = (maxExtent - minExtent) > 0
        ? (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0)
        : 0.0;
    final bool shouldCollapse = shrinkPercentage > 0.5 || isCollapsed;

    // Calculate the current height based on shrink percentage
    // Ensure it's never less than minHeight
    final double currentHeight = (maxHeight - (shrinkOffset)).clamp(minHeight, maxHeight);

    // Use custom colors if provided, otherwise fall back to theme colors
    final Color effectiveBackgroundColor = backgroundColor ?? 
        (shouldCollapse ? colorScheme.surface.withOpacity(0.95) : colorScheme.surfaceVariant.withOpacity(0.8));
    
    final Color effectiveTextColor = textColor ?? colorScheme.onSurface;
    final Color effectiveAccentColor = accentColor ?? colorScheme.primary;

    return SizedBox(
      height: currentHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: currentHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16), // Match card radius
            bottom: Radius.circular(shouldCollapse ? 0 : 16),
          ),
          boxShadow: shouldCollapse
              ? [
                  if (useNeumorphicStyle)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                ]
              : null,
        ),
        child: shouldCollapse
            // Collapsed view - just the subtotal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    key: const ValueKey('subtotal_label_collapsed'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: effectiveTextColor,
                    ),
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    key: const ValueKey('subtotal_amount_collapsed'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: effectiveAccentColor,
                    ),
                  ),
                ],
              )
            // Expanded view - full card with icon
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        color: effectiveAccentColor,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Subtotal',
                        key: const ValueKey('subtotal_label_expanded'),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: effectiveTextColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    key: const ValueKey('subtotal_amount_expanded'),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: effectiveAccentColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SubtotalHeaderDelegate oldDelegate) {
    return isCollapsed != oldDelegate.isCollapsed ||
           subtotal != oldDelegate.subtotal ||
           maxHeight != oldDelegate.maxHeight ||
           minHeight != oldDelegate.minHeight ||
           colorScheme != oldDelegate.colorScheme ||
           textTheme != oldDelegate.textTheme ||
           useNeumorphicStyle != oldDelegate.useNeumorphicStyle ||
           backgroundColor != oldDelegate.backgroundColor ||
           textColor != oldDelegate.textColor ||
           accentColor != oldDelegate.accentColor;
  }
} 
import 'package:flutter/material.dart';

enum NeumorphicType {
  raised,
  inset,
}

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final NeumorphicType type;
  final EdgeInsetsGeometry padding;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const NeumorphicContainer({
    Key? key,
    required this.child,
    this.color = Colors.white,
    this.radius = 12.0,
    this.type = NeumorphicType.raised,
    this.padding = EdgeInsets.zero,
    this.width = double.infinity,
    this.height = double.infinity,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (type == NeumorphicType.raised) {
      return _buildRaisedContainer();
    } else {
      return _buildInsetContainer();
    }
  }

  Widget _buildRaisedContainer() {
    // Raised/Extruded: Soft, diffused shadows
    // box-shadow: 4px 4px 8px rgba(0,0,0,0.06), -3px -3px 6px rgba(255,255,255,0.7)
    final Widget containerWidget = Container(
      width: width != double.infinity ? width : null,
      height: height != double.infinity ? height : null,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) {
      return containerWidget;
    } else {
      return GestureDetector(
        onTap: onTap,
        child: containerWidget,
      );
    }
  }

  Widget _buildInsetContainer() {
    // For Flutter, we need a creative solution for inset shadows
    // Since Flutter doesn't support CSS-style inset shadows directly
    
    // We'll use a stack with a clipped container to simulate the inset effect
    final Widget containerWidget = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width != double.infinity ? width : null,
        height: height != double.infinity ? height : null,
        color: color,
        child: Stack(
          children: [
            // Inset shadow overlay - simulates inner shadows
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.06),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withOpacity(0.1),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: Container(),
              ),
            ),
            
            // Shadow top-left
            Positioned(
              top: 0,
              left: 0,
              right: radius * 2,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.topRight,
                    colors: [
                      Colors.black.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            Positioned(
              top: 0,
              left: 0,
              bottom: radius * 2,
              width: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Shadow bottom-right
            Positioned(
              bottom: 0,
              left: radius * 2,
              right: 0,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            
            Positioned(
              top: radius * 2,
              right: 0,
              bottom: 0,
              width: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            
            // Content with padding
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return containerWidget;
    } else {
      return GestureDetector(
        onTap: onTap,
        child: containerWidget,
      );
    }
  }
}

class NeumorphicIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color iconColor;
  final double iconSize;
  final Color backgroundColor;
  final double radius;
  final NeumorphicType type;
  final double size;

  const NeumorphicIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.iconColor = const Color(0xFF5D737E), // SlateBlue
    this.iconSize = 20,
    this.backgroundColor = Colors.white,
    this.radius = 20,
    this.type = NeumorphicType.raised,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      type: type,
      color: backgroundColor,
      radius: radius,
      width: size,
      height: size,
      onTap: onPressed,
      child: Center(
        child: Icon(
          icon,
          color: onPressed == null 
              ? iconColor.withOpacity(0.5)
              : iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}

class NeumorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;

  const NeumorphicButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.color = Colors.white,
    this.radius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      type: NeumorphicType.raised,
      color: color,
      radius: radius,
      padding: padding,
      onTap: onPressed,
      child: child,
    );
  }
}

class NeumorphicPricePill extends StatelessWidget {
  final double price;
  final Color color;

  const NeumorphicPricePill({
    Key? key,
    required this.price,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(1, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        '\$${price.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class NeumorphicPill extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  const NeumorphicPill({
    Key? key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Represents a styled bottom bar with neumorphic styling
class NeumorphicBottomBar extends StatelessWidget {
  final List<Widget> children;
  final double height;
  
  const NeumorphicBottomBar({
    Key? key,
    required this.children,
    this.height = 72.0,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }
} 
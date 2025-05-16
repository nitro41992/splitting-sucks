import 'package:flutter/material.dart';
import '../../theme/neumorphic_theme.dart';
import 'neumorphic_container.dart';

/// A neumorphic styled avatar widget that displays initials
class NeumorphicAvatar extends StatelessWidget {
  final String text;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;
  
  const NeumorphicAvatar({
    Key? key,
    required this.text,
    this.size = NeumorphicTheme.largeAvatarSize,
    this.backgroundColor = NeumorphicTheme.slateBlue,
    this.textColor = Colors.white,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Get the first character for the avatar display
    final String initial = text.isNotEmpty ? text[0].toUpperCase() : '?';
    
    return NeumorphicContainer(
      type: NeumorphicType.raised,
      color: backgroundColor,
      radius: size / 2, // Make it circular
      width: size,
      height: size,
      onTap: onTap,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.4, // Proportional font size
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// A neumorphic styled edit button for avatars
class NeumorphicEditButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;
  
  const NeumorphicEditButton({
    Key? key,
    required this.onPressed,
    this.size = 28,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return NeumorphicIconButton(
      icon: Icons.edit_outlined,
      iconColor: NeumorphicTheme.slateBlue,
      backgroundColor: Colors.white,
      size: size,
      radius: size / 2,
      type: NeumorphicType.inset,
      onPressed: onPressed,
    );
  }
}

/// A neumorphic styled avatar with edit capability
class EditableNeumorphicAvatar extends StatelessWidget {
  final String text;
  final double size;
  final VoidCallback onEdit;
  
  const EditableNeumorphicAvatar({
    Key? key,
    required this.text,
    required this.onEdit,
    this.size = NeumorphicTheme.largeAvatarSize,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NeumorphicAvatar(
          text: text,
          size: size,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: NeumorphicEditButton(
            onPressed: onEdit,
            size: size * 0.4,
          ),
        ),
      ],
    );
  }
}

/// A neumorphic styled price pill
class NeumorphicPricePill extends StatelessWidget {
  final double price;
  final Color color;
  final double fontSize;
  final bool isPositive;
  
  const NeumorphicPricePill({
    Key? key,
    required this.price,
    this.color = NeumorphicTheme.slateBlue,
    this.fontSize = 14,
    this.isPositive = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final String formattedPrice = isPositive ? '+\$${price.toStringAsFixed(2)}' : '\$${price.toStringAsFixed(2)}';
    
    return NeumorphicPill(
      color: color,
      radius: NeumorphicTheme.pillRadius,
      child: Text(
        formattedPrice,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../../theme/neumorphic_theme.dart';
import 'neumorphic_container.dart';

/// A neumorphic styled avatar widget that displays initials
class NeumorphicAvatar extends StatelessWidget {
  final String? text;
  final Color backgroundColor;
  final Color textColor;
  final double size;
  final VoidCallback? onTap;
  final IconData? icon;
  final double iconSize;
  final Color iconColor;
  
  const NeumorphicAvatar({
    Key? key,
    this.text,
    this.backgroundColor = const Color(0xFF5D737E),
    this.textColor = Colors.white,
    this.size = 40,
    this.onTap,
    this.icon,
    this.iconSize = 20,
    this.iconColor = Colors.white,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final String displayText = text != null && text!.isNotEmpty
        ? text![0].toUpperCase()
        : '?';
    
    return NeumorphicContainer(
      type: NeumorphicType.raised,
      color: backgroundColor,
      radius: size / 2, // Make it circular
      width: size,
      height: size,
      onTap: onTap,
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                color: iconColor,
                size: iconSize,
              )
            : Text(
                displayText,
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
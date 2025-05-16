import 'package:flutter/material.dart';
import 'neumorphic_container.dart';

/// Represents a tab item to display in the NeumorphicTabs widget
class NeumorphicTabItem {
  final String label;
  final IconData? icon;
  
  const NeumorphicTabItem({
    required this.label,
    this.icon,
  });
}

/// A neumorphic-styled tab navigation component
class NeumorphicTabs extends StatefulWidget {
  final List<NeumorphicTabItem> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;
  final Color trackColor;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;

  const NeumorphicTabs({
    Key? key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.trackColor = const Color(0xFFE9ECEF),
    this.selectedColor = const Color(0xFF5D737E), // Slate Blue
    this.selectedTextColor = Colors.white,
    this.unselectedTextColor = const Color(0xFF5D737E), // Slate Blue
  }) : super(key: key);

  @override
  State<NeumorphicTabs> createState() => _NeumorphicTabsState();
}

class _NeumorphicTabsState extends State<NeumorphicTabs> {
  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      type: NeumorphicType.inset,
      color: widget.trackColor,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(
          widget.tabs.length,
          (index) => Expanded(
            child: _buildTabItem(index),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index) {
    final bool isSelected = index == widget.selectedIndex;
    final NeumorphicTabItem tab = widget.tabs[index];

    return GestureDetector(
      onTap: () => widget.onTabSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: isSelected
            ? NeumorphicContainer(
                type: NeumorphicType.raised,
                color: widget.selectedColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildTabContent(tab, isSelected),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildTabContent(tab, isSelected),
              ),
      ),
    );
  }

  Widget _buildTabContent(NeumorphicTabItem tab, bool isSelected) {
    final textColor = isSelected 
        ? widget.selectedTextColor 
        : widget.unselectedTextColor;

    if (tab.icon != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab.icon,
            color: textColor,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            tab.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      return Text(
        tab.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      );
    }
  }
}

/// A pill-shaped neumorphic toggle button for participants
class NeumorphicTogglePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onToggle;

  const NeumorphicTogglePill({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define colors
    final Color slateBlue = const Color(0xFF5D737E);
    
    return GestureDetector(
      onTap: onToggle,
      child: NeumorphicContainer(
        type: isSelected ? NeumorphicType.inset : NeumorphicType.raised,
        color: isSelected ? slateBlue : Colors.white,
        radius: 20, // Pill shape
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) 
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : slateBlue,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
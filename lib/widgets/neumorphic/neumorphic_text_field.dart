import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'neumorphic_container.dart';

class NeumorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Function(String)? onChanged;
  final bool autofocus;
  final int? maxLength;
  final String? prefixText;
  final String? suffixText;
  final bool showCounter;
  final FocusNode? focusNode;

  const NeumorphicTextField({
    Key? key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.autofocus = false,
    this.maxLength,
    this.prefixText,
    this.suffixText,
    this.showCounter = true,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A8A8E), // Medium Grey
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        NeumorphicContainer(
          type: NeumorphicType.inset,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                prefixIcon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  autofocus: autofocus,
                  maxLength: maxLength,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: hintText,
                    prefixText: prefixText,
                    suffixText: suffixText,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    counterText: '', // Remove default counter
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1D1D1F), // Dark Grey
                  ),
                ),
              ),
              if (suffixIcon != null) ...[
                const SizedBox(width: 8),
                suffixIcon!,
              ],
            ],
          ),
        ),
        if (showCounter && maxLength != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return Text(
                  '${value.text.length}/$maxLength',
                  style: TextStyle(
                    fontSize: 12,
                    color: value.text.length > maxLength!
                        ? const Color(0xFFE57373) // Muted Red
                        : const Color(0xFF8A8A8E), // Medium Grey
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
} 
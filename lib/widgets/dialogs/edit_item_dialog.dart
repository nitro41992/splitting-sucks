import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/receipt_item.dart'; // Import ReceiptItem model
import '../../theme/neumorphic_theme.dart';
import '../neumorphic/neumorphic_container.dart';
import '../neumorphic/neumorphic_text_field.dart';

// Define a return type for the dialog
class EditItemResult {
  final String name;
  final double price;

  EditItemResult(this.name, this.price);
}

// --- New StatefulWidget for Dialog Content ---
class _EditItemDialogContent extends StatefulWidget {
  final ReceiptItem initialItem;

  const _EditItemDialogContent({required this.initialItem});

  @override
  _EditItemDialogContentState createState() => _EditItemDialogContentState();
}

class _EditItemDialogContentState extends State<_EditItemDialogContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  static const int maxNameLength = 30;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialItem.name);
    _priceController = TextEditingController(text: widget.initialItem.price.toStringAsFixed(2));
    // Initially validate the price
    _validatePrice(_priceController.text);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Format and validate price input
  void _validatePrice(String value) {
    setState(() {
      if (value.isEmpty) {
        _priceError = 'Price is required';
      } else {
        final price = double.tryParse(value);
        if (price == null) {
          _priceError = 'Invalid price format';
        } else if (price <= 0) {
          _priceError = 'Price must be greater than 0';
        } else {
          _priceError = null;
        }
      }
    });
  }

  // Format the price for display (if needed)
  String _formatPrice(String value) {
    if (value.isEmpty) return value;
    
    // Remove non-numeric characters except decimal point
    String cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Handle multiple decimal points (keep only the first one)
    int firstDecimal = cleanValue.indexOf('.');
    if (firstDecimal != -1) {
      String beforeDecimal = cleanValue.substring(0, firstDecimal + 1);
      String afterDecimal = cleanValue.substring(firstDecimal + 1).replaceAll('.', '');
      // Limit to 2 decimal places
      if (afterDecimal.length > 2) {
        afterDecimal = afterDecimal.substring(0, 2);
      }
      cleanValue = beforeDecimal + afterDecimal;
    }
    
    return cleanValue;
  }

  void _saveChanges() {
    final newName = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final newPrice = double.tryParse(priceText);

    if (newName.isEmpty) {
      setState(() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name'))
      ));
      return;
    }
    
    if (_priceError != null || newPrice == null || newPrice <= 0) {
      setState(() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price'))
      ));
      return;
    }

    Navigator.pop(context, EditItemResult(newName, newPrice)); // Return the new values
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: NeumorphicTheme.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button (Cancel)
                  NeumorphicIconButton(
                    icon: Icons.close,
                    iconColor: NeumorphicTheme.slateBlue,
                    size: 36,
                    iconSize: 20,
                    onPressed: () => Navigator.pop(context, null),
                  ),
                  
                  // Title
                  Text(
                    'Edit Item', 
                    style: NeumorphicTheme.primaryText(
                      size: NeumorphicTheme.titleLarge,
                      weight: FontWeight.w600,
                    ),
                  ),
                  
                  // Empty space to balance layout
                  const SizedBox(width: 36),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Name field
                  NeumorphicTextField(
                    controller: _nameController,
                    labelText: 'Item Name',
                    hintText: 'Enter item name',
                    prefixIcon: Icon(
                      Icons.shopping_bag_outlined,
                      color: NeumorphicTheme.slateBlue,
                      size: 18,
                    ),
                    maxLength: maxNameLength,
                  ),
                  const SizedBox(height: 24),
                  
                  // Price field with Neumorphic styling
                  NeumorphicTextField(
                    controller: _priceController,
                    labelText: 'Price',
                    hintText: '0.00',
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: NeumorphicTheme.slateBlue,
                      size: 18,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (value) {
                      _validatePrice(value);
                    },
                  ),
                  if (_priceError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                      child: Text(
                        _priceError!,
                        style: TextStyle(
                          color: NeumorphicTheme.mutedRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Cancel button
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: NeumorphicTheme.mutedRed,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Save button
                      NeumorphicButton(
                        color: NeumorphicTheme.slateBlue,
                        radius: NeumorphicTheme.buttonRadius,
                        onPressed: _saveChanges,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check, 
                              color: Colors.white, 
                              size: 18
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Save',
                              style: NeumorphicTheme.onAccentText(
                                size: 15, 
                                weight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- End of StatefulWidget ---


Future<EditItemResult?> showEditItemDialog(
  BuildContext context,
  ReceiptItem item,
) async {
  return await showModalBottomSheet<EditItemResult?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditItemDialogContent(initialItem: item),
      );
    },
  );
} 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/receipt_item.dart'; // Import ReceiptItem model

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
          color: Colors.white,
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context, null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF5D737E),
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // Title
                  const Text(
                    'Edit Item', 
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
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
                  // Item Name Label
                  const Text(
                    'Item Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5D737E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Item Name field with Neumorphic styling
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: TextField(
                      key: const ValueKey('editItemDialog_name_field'),
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter item name',
                        hintStyle: TextStyle(
                          color: const Color(0xFF8A8A8E).withOpacity(0.7),
                        ),
                        prefixIcon: const Icon(
                          Icons.fastfood_outlined,
                          color: Color(0xFF5D737E),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF5D737E),
                            width: 1,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        counterText: '${_nameController.text.length}/$maxNameLength',
                      ),
                      maxLength: maxNameLength,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1D1D1F),
                      ),
                      onChanged: (value) => setState(() {}),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price Label
                  const Text(
                    'Price',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5D737E),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price field with Neumorphic styling
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: TextField(
                      key: const ValueKey('editItemDialog_price_field'),
                      controller: _priceController,
                      decoration: InputDecoration(
                        hintText: 'Enter price',
                        hintStyle: TextStyle(
                          color: const Color(0xFF8A8A8E).withOpacity(0.7),
                        ),
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: Color(0xFF5D737E),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF5D737E),
                            width: 1,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        errorText: _priceError,
                        errorStyle: const TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 12,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1D1D1F),
                      ),
                      inputFormatters: [
                        // Allow only numbers and decimal point
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        // Custom formatter to handle decimal formatting
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final formattedValue = _formatPrice(newValue.text);
                          return TextEditingValue(
                            text: formattedValue,
                            selection: TextSelection.collapsed(offset: formattedValue.length),
                          );
                        }),
                      ],
                      onChanged: _validatePrice,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  InkWell(
                    onTap: _saveChanges,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D737E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
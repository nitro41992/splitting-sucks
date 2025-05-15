import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/receipt_item.dart'; // Import ReceiptItem model

// --- New StatefulWidget for Dialog Content ---
class _AddItemDialogContent extends StatefulWidget {
  const _AddItemDialogContent();

  @override
  _AddItemDialogContentState createState() => _AddItemDialogContentState();
}

class _AddItemDialogContentState extends State<_AddItemDialogContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  int _quantity = 1;
  static const int maxNameLength = 30;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController();
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

  void _addItem() {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    if (name.isEmpty) {
      setState(() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name'))
      ));
      return;
    }
    
    if (_priceError != null || price == null || price <= 0) {
      setState(() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price'))
      ));
      return;
    }

    final newItem = ReceiptItem(
      name: name,
      price: price,
      quantity: _quantity,
    );
    Navigator.pop(context, newItem); // Return the new item
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
                  // Close button
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
                    'Add New Item', 
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
                      key: const ValueKey('addItemDialog_name_field'),
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter item name',
                        hintStyle: TextStyle(
                          color: const Color(0xFF8A8A8E).withOpacity(0.7),
                        ),
                        prefixIcon: const Icon(
                          Icons.shopping_bag_outlined,
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
                      key: const ValueKey('addItemDialog_price_field'),
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
                        errorText: _priceError,
                        errorStyle: const TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
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
                  const SizedBox(height: 20),

                  // Quantity Label
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5D737E),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quantity controls with Neumorphic styling
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Minus button
                        InkWell(
                          onTap: _quantity > 1 
                            ? () => setState(() => _quantity--) 
                            : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: _quantity > 1 ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                  spreadRadius: 0,
                                ),
                              ] : null,
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 20,
                              color: _quantity > 1
                                ? const Color(0xFF5D737E)
                                : const Color(0xFF8A8A8E).withOpacity(0.5),
                            ),
                          ),
                        ),
                        
                        // Quantity display
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        
                        // Plus button
                        InkWell(
                          onTap: () => setState(() => _quantity++),
                          borderRadius: BorderRadius.circular(12),
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
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 20,
                              color: Color(0xFF5D737E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Add Item Button
                  InkWell(
                    onTap: _addItem,
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
                            Icons.add_circle_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add Item',
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

Future<ReceiptItem?> showAddItemDialog(BuildContext context) async {
  return await showModalBottomSheet<ReceiptItem?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _AddItemDialogContent(),
      );
    },
  );
} 
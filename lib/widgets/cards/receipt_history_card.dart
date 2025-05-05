import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/receipt_history.dart';

class ReceiptHistoryCard extends StatelessWidget {
  final ReceiptHistory receipt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ReceiptHistoryCard({
    Key? key,
    required this.receipt,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM/dd/yy');
    final formattedDate = dateFormat.format(receipt.createdAt.toDate());
    final isDraft = receipt.status == 'draft';
    
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final formattedTotal = currencyFormat.format(receipt.totalAmount);
    
    // Calculate number of people
    final peopleCount = receipt.people.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt thumbnail or placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[200],
                      child: receipt.imageUri.isNotEmpty
                          ? Image.network(
                              receipt.imageUri,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.receipt,
                                  size: 40,
                                  color: Colors.grey,
                                );
                              },
                            )
                          : const Icon(
                              Icons.receipt,
                              size: 40,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Receipt details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (isDraft)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'DRAFT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  if (isDraft) const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      receipt.restaurantName,
                                      style: theme.textTheme.titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  onTap();
                                } else if (value == 'delete') {
                                  onDelete();
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formattedTotal,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$peopleCount ${peopleCount == 1 ? 'person' : 'people'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
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
      ),
    );
  }
} 
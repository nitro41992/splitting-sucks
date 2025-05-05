import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/receipt_history.dart';
import '../../services/file_helper.dart';

// Global cache for storing converted URLs
// This prevents multiple conversions of the same URL
final Map<String, String> _downloadUrlCache = {};

class ReceiptHistoryCard extends StatefulWidget {
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
  State<ReceiptHistoryCard> createState() => _ReceiptHistoryCardState();
}

class _ReceiptHistoryCardState extends State<ReceiptHistoryCard> {
  // Store the converted URL to avoid repeating the conversion
  String? _cachedDownloadUrl;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Convert the URL early to avoid redoing it on every build
    _convertImageUrl();
  }

  // Convert gs:// URL to https:// URL once and cache it
  Future<void> _convertImageUrl() async {
    if (!mounted || widget.receipt.imageUri.isEmpty) return;

    final String imageUri = widget.receipt.imageUri;

    // Check if we already have this URL converted in our global cache
    if (_downloadUrlCache.containsKey(imageUri)) {
      setState(() {
        _cachedDownloadUrl = _downloadUrlCache[imageUri];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (imageUri.startsWith('gs://')) {
        final downloadUrl = await FileHelper.getDownloadURLFromGsURI(imageUri);
        // Cache the result globally
        _downloadUrlCache[imageUri] = downloadUrl;
        
        if (mounted) {
          setState(() {
            _cachedDownloadUrl = downloadUrl;
            _isLoading = false;
          });
        }
      } else {
        // It's already an HTTP URL
        // We still cache it to avoid any processing
        _downloadUrlCache[imageUri] = imageUri;
        
        setState(() {
          _cachedDownloadUrl = imageUri;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Don't cache errors, so we can retry next time
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM/dd/yy');
    final formattedDate = dateFormat.format(widget.receipt.createdAt.toDate());
    final isDraft = widget.receipt.status == 'draft';
    
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final formattedTotal = currencyFormat.format(widget.receipt.totalAmount);
    
    // Calculate number of people
    final peopleCount = widget.receipt.people.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
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
                      child: _buildThumbnail(),
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
                                      widget.receipt.restaurantName,
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
                                  widget.onTap();
                                } else if (value == 'delete') {
                                  widget.onDelete();
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

  Widget _buildThumbnail() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    } else if (_hasError || _cachedDownloadUrl == null) {
      return const Icon(
        Icons.receipt,
        size: 40,
        color: Colors.grey,
      );
    } else {
      // Use CachedNetworkImage for better caching performance
      return CachedNetworkImage(
        imageUrl: _cachedDownloadUrl!,
        fit: BoxFit.cover,
        // The following parameters significantly improve performance
        memCacheWidth: 140, // Double the display size for better quality
        memCacheHeight: 140,
        // Show a proper placeholder while loading
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
        // Show a fallback icon if the image can't be loaded
        errorWidget: (context, url, error) => const Icon(
          Icons.receipt,
          size: 40,
          color: Colors.grey,
        ),
      );
    }
  }
} 
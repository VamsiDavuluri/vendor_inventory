import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:another_flushbar/flushbar.dart';
import '../api_service.dart';
import 'upload_screen.dart';

class Product {
  final String id;
  final String name;
  final String brand;
  bool hasImages;
  String? coverImageUrl;
  int imageCount;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    this.hasImages = false,
    this.coverImageUrl,
    this.imageCount = 0,
  });
}

class HomeScreen extends StatefulWidget {
  final String vendorId;
  final List<Product> initialProducts;
  const HomeScreen({
    Key? key,
    required this.vendorId,
    required this.initialProducts,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = "";
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _allProducts = widget.initialProducts;
    _filteredProducts = widget.initialProducts;
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    try {
      final List<Product> updatedProducts =
          await ApiService.fetchProductsWithStatus(widget.vendorId);
      if (mounted) {
        setState(() {
          _allProducts = updatedProducts;
          _filterProducts();
        });
      }
    } catch (e) {
      print("Error on refresh: $e");
    }
  }

  Future<void> _navigateToUploadScreen(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadScreen(
          vendorId: widget.vendorId,
          productId: product.id,
          productName: product.name,
        ),
      ),
    );

    if (result is Map<String, dynamic> && mounted) {
      setState(() {
        final productIndex = _allProducts.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          _allProducts[productIndex].coverImageUrl = result['coverImageUrl'];
          _allProducts[productIndex].imageCount = result['imageCount'];
          _allProducts[productIndex].hasImages =
              (result['imageCount'] ?? 0) > 0;
        }
        _filterProducts();
      });

      _showTopFlashbar(
        "Images updated successfully",
        Colors.green,
        Icons.check,
      );
    }

    if (mounted) {
      FocusScope.of(context).unfocus();
      _searchFocus.unfocus();
    }
  }

  void _filterProducts() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = List.from(_allProducts);
      } else {
        _filteredProducts = _allProducts
            .where(
              (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _showTopFlashbar(String message, Color bgColor, IconData icon) {
    Flushbar(
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      icon: Icon(icon, color: Colors.white),
      backgroundColor: bgColor,
      duration: const Duration(seconds: 2),
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Inventory",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: "Search for products...",
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30.0)),
                    borderSide: BorderSide(
                      color: Color(0xFF009EAE),
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _filterProducts();
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshProducts,
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      onTap: () => _navigateToUploadScreen(product),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({Key? key, required this.product, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: product.hasImages && product.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.coverImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: Icon(
                              MaterialCommunityIcons.folder_multiple_image,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        )
                      : Center(
                          child: Icon(
                            MaterialCommunityIcons.folder_multiple_image,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.brand,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

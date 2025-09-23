import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../api_service.dart';
import 'upload_screen.dart';

class Product {
  final String id;
  final String name;
  bool hasImages;
  String? coverImageUrl;
  final int imageCount;
  Product({
    required this.id,
    required this.name,
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

      // The print loop has been removed from here to keep the terminal clean.

      if (mounted) {
        setState(() {
          _allProducts = updatedProducts;
          _filteredProducts = _allProducts
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();
        });
      }
    } catch (e) {
      print("Error on refresh: $e");
    }
  }

  Future<void> _navigateToUploadScreen(Product product) async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadScreen(
          vendorId: widget.vendorId,
          productId: product.id,
          productName: product.name,
        ),
      ),
    );

    if (result == true) {
      await _refreshProducts();
    }

    if (mounted) {
      FocusScope.of(context).unfocus();
      _searchFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
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
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Color(0xFF009EAE),
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _filteredProducts = _allProducts
                        .where(
                          (p) => p.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
                  });
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshProducts,
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
              offset: Offset(0, 4),
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
                          errorWidget: (context, url, error) => Icon(
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
                child: Text(
                  product.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../api_service.dart';
import 'upload_screen.dart';

// Data model for product
class Product {
  final String id;
  final String name;
  bool hasImages;
  Product({required this.id, required this.name, this.hasImages = false});
}

class HomeScreen extends StatefulWidget {
  final String vendorId;
  final List<Product> initialProducts; // It receives the loaded products

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
    // The screen receives its data directly, no need for an initial API call.
    _allProducts = widget.initialProducts;
    _filteredProducts = widget.initialProducts;
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  // This function is now ONLY for pull-to-refresh
  Future<void> _refreshProducts() async {
    try {
      // We re-fetch the entire list and their statuses on refresh
      List<Product> vendorProducts = await ApiService.fetchProductsForVendor(
        widget.vendorId,
      );
      final List<Future<Product>> productStatusFutures = vendorProducts.map((
        product,
      ) async {
        final imageUrls = await ApiService.fetchProductImages(
          widget.vendorId,
          product.id,
        );
        product.hasImages = imageUrls.isNotEmpty;
        return product;
      }).toList();
      final List<Product> updatedProducts = await Future.wait(
        productStatusFutures,
      );

      if (mounted) {
        setState(() {
          _allProducts = updatedProducts;
          // Re-apply the search filter after refreshing
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
      // Optionally show a snackbar on refresh failure
    }
  }

  Future<void> _navigateToUploadScreen(Product product) async {
    final bool? resultHasImages = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadScreen(
          vendorId: widget.vendorId,
          productId: product.id,
          productName: product.name,
        ),
      ),
    );

    if (resultHasImages != null) {
      setState(() {
        product.hasImages = resultHasImages;
      });
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
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
                  borderSide: BorderSide(color: Color(0xFF009EAE), width: 1.5),
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
            SizedBox(height: 16),
            Expanded(
              // The initial loading indicator is no longer needed here.
              child: RefreshIndicator(
                onRefresh: _refreshProducts,
                child: ListView.builder(
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: EdgeInsets.symmetric(vertical: 6),
                      elevation: 0.5,
                      child: ListTile(
                        leading: product.hasImages
                            ? ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    LinearGradient(
                                      colors: [
                                        Color(0xFF02D7C0),
                                        Color(0xFF009EAE),
                                      ],
                                    ).createShader(
                                      Rect.fromLTWH(
                                        0,
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ),
                                    ),
                                child: Icon(
                                  MaterialCommunityIcons.folder,
                                  size: 28,
                                ),
                              )
                            : Icon(
                                MaterialCommunityIcons.folder_outline,
                                color: Colors.grey,
                                size: 28,
                              ),
                        title: Text(
                          product.name,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _navigateToUploadScreen(product),
                      ),
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

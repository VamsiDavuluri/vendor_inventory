import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../api_service.dart';
import 'upload_screen.dart';

// Data model for product
class Product {
  final String id; // productId for backend
  final String name; // productName for display
  bool hasImages;

  Product({required this.id, required this.name, this.hasImages = false});
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;

  // Example product list
  final List<Product> _productList = [
    Product(
      id: "prod_1",
      name: "White & Black Stroke Art Abstract Pattern Shirt",
    ),
    Product(id: "prod_2", name: "Black Liquid Art Aloha Shirt"),
    Product(id: "prod_3", name: "Neon Tropical Pattern Aloha Shirt"),
    Product(id: "prod_4", name: "Modern Abstract Art Aloha Shirt"),
    Product(id: "prod_5", name: "Bright Tropical Print Aloha Shirt"),
    Product(id: "prod_6", name: "Multicoloured Geometric Pattern Aloha Shirt"),
    Product(
      id: "prod_7",
      name: "Blue & Black Abstract Art Pattern Aloha Shirt",
    ),
    Product(id: "prod_8", name: "Abstract Pattern Aloha Shirt"),
    Product(id: "prod_9", name: "Green Abstract Pattern Aloha Shirt"),
    Product(
      id: "prod_10",
      name: "White & Sky Blue Tie Dye Pattern Aloha Shirt",
    ),
    Product(
      id: "prod_11",
      name: "Plain Red & Black Tie Dye Pattern Aloha Shirt",
    ),
    Product(id: "prod_12", name: "Black & White Tie Dye Pattern Aloha Shirt"),
    Product(id: "prod_13", name: "Grey & White Tie Dye Pattern Aloha Shirt"),
  ];

  String _searchQuery = "";
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchProductsAndTheirStatus();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  /// Fetch image status for all products
  Future<void> _fetchProductsAndTheirStatus() async {
    // No need to set loading state here if it's for refresh,
    // the indicator handles the UI. Only on first load.
    if (_allProducts.isEmpty) {
      setState(() => _isLoading = true);
    }

    List<Product> tempProducts = [];

    for (Product product in _productList) {
      try {
        final imageUrls = await ApiService.fetchProductImages(
          "vendor_123",
          product.id,
        );
        final bool hasImages = imageUrls.isNotEmpty;
        tempProducts.add(
          Product(id: product.id, name: product.name, hasImages: hasImages),
        );
      } catch (e) {
        print("Error fetching status for ${product.name}: $e");
        tempProducts.add(
          Product(id: product.id, name: product.name, hasImages: false),
        );
      }
    }

    if (mounted) {
      setState(() {
        _allProducts = tempProducts;
        _filteredProducts = _allProducts;
        _isLoading = false;
      });
    }
  }

  /// Navigate to UploadScreen
  Future<void> _navigateToUploadScreen(Product product) async {
    final bool? resultHasImages = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UploadScreen(productId: product.id, productName: product.name),
      ),
    );

    if (resultHasImages != null) {
      setState(() {
        product.hasImages = resultHasImages;
      });
    }

    // No need to re-fetch everything, the result gives us the new state.
    // await _fetchProductsAndTheirStatus();

    if (mounted) {
      FocusScope.of(context).unfocus();
      _searchFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _filteredProducts = _allProducts
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

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
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchProductsAndTheirStatus,
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
                              // --- UI RESTORATION ---
                              // Using the gradient ShaderMask for folders with images
                              // and a grey outline for empty ones.
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

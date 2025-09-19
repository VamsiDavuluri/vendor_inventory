import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'screens/home_screen.dart'; // Import the Product class

class ApiService {
  static const String baseUrl = "http://192.168.0.121:3000"; // Your IP

  /// NEW METHOD: Fetches the list of products for a specific vendor.
  static Future<List<Product>> fetchProductsForVendor(String vendorId) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId");
    print("➡️ Fetching product list for vendor: $vendorId");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        throw Exception("Vendor not found or has no products.");
      }
      final products = data.map((json) {
        return Product(id: json['id'], name: json['name'], hasImages: false);
      }).toList();
      print("⬅️ Found ${products.length} products.");
      return products;
    } else {
      throw Exception("Failed to fetch products for vendor $vendorId");
    }
  }

  // --- Your other methods remain the same ---

  static Future<List<String>> fetchProductImages(
    String vendorId,
    String productId,
  ) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId");
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body)['images']);
    } else {
      throw Exception("Failed to fetch product images");
    }
  }

  static Future<Map<String, dynamic>> uploadMultipleImages(
    String vendorId,
    String productId,
    String productName,
    List<File> images,
  ) async {
    final uri = Uri.parse("$baseUrl/upload/$vendorId/$productId/$productName");
    var request = http.MultipartRequest("POST", uri);
    for (var imageFile in images) {
      request.files.add(
        await http.MultipartFile.fromPath("files", imageFile.path),
      );
    }
    var response = await request.send();
    if (response.statusCode == 200) {
      return jsonDecode(await response.stream.bytesToString());
    } else {
      throw Exception("Failed to upload images");
    }
  }

  static Future<List<String>> deleteImage(
    String vendorId,
    String productId,
    String imageKey,
  ) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId/$imageKey");
    final response = await http.delete(uri);
    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body)['images']);
    } else {
      throw Exception("Failed to delete image");
    }
  }
}

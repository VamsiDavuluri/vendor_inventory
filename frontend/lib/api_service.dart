import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'screens/home_screen.dart';

class ApiService {
  static const String baseUrl = "http://192.168.0.121:3000";

  /// EFFICIENT METHOD: Fetches the full product list with all data included.
  static Future<List<Product>> fetchProductsWithStatus(String vendorId) async {
    final uri = Uri.parse("$baseUrl/vendor/$vendorId/products-with-status");
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) throw Exception("Vendor not found or has no products.");
      return data
          .map(
            (json) => Product(
              id: json['id'],
              name: json['name'],
              hasImages: json['hasImages'],
              coverImageUrl: json['coverImageUrl'],
              imageCount: json['imageCount'],
            ),
          )
          .toList();
    } else {
      throw Exception("Failed to fetch enriched products for vendor $vendorId");
    }
  }

  /// Fetch a single product's images and optionally log each URL.
  static Future<List<String>> fetchProductImages(
    String vendorId,
    String productId, {
    bool logUrls = false,
  }) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId");
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final images = List<String>.from(jsonDecode(response.body)['images']);
      if (logUrls) {
        print("📥 Fetched ${images.length} images for $productId:");
        for (var i = 0; i < images.length; i++) {
          print("  Image $i: ${images[i]}");
        }
      }
      return images;
    } else {
      throw Exception("Failed to fetch product images for $productId");
    }
  }

  /// Uploads new images, telling the backend which one, if any, is the thumbnail.
  static Future<Map<String, dynamic>> addImages(
    String vendorId,
    String productId,
    List<File> images,
    int? thumbnailIndex,
  ) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId/add-images");
    print("➡️ Uploading ${images.length} images for product: $productId");
    var request = http.MultipartRequest("POST", uri);
    if (thumbnailIndex != null) {
      request.fields['thumbnail_index'] = thumbnailIndex.toString();
    }
    for (var imageFile in images) {
      request.files.add(
        await http.MultipartFile.fromPath("files", imageFile.path),
      );
    }
    var response = await request.send();
    if (response.statusCode == 200) {
      final responseData = jsonDecode(await response.stream.bytesToString());
      if (responseData.containsKey('images')) {
        final returnedUrls = List<String>.from(responseData['images']);
        print(
          "✅ Upload successful. Received ${returnedUrls.length} image URLs for $productId:",
        );
        for (var i = 0; i < returnedUrls.length; i++) {
          print("  Image $i: ${returnedUrls[i]}");
        }
      }
      return responseData;
    } else {
      throw Exception("Failed to add images");
    }
  }

  /// Delete a specific image from a product folder.
  static Future<List<String>> deleteImage(
    String vendorId,
    String productId,
    String imageKey,
  ) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId/$imageKey");
    print("➡️ Deleting image with key: $imageKey");
    final response = await http.delete(uri);
    if (response.statusCode == 200) {
      final images = List<String>.from(jsonDecode(response.body)['images']);
      print("⬅️ Delete successful. ${images.length} images remaining.");
      return images;
    } else {
      throw Exception("Failed to delete image");
    }
  }

  /// Sets a specific image as the primary thumbnail.
  static Future<void> setThumbnail(
    String vendorId,
    String productId,
    String imageKey,
  ) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId/thumbnail");
    print("➡️ Setting thumbnail for product $productId with key: $imageKey");
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageKey': imageKey}),
    );
    if (response.statusCode == 200) {
      print("⬅️ Thumbnail set successfully.");
    } else {
      throw Exception(
        "Failed to set thumbnail. Status code: ${response.statusCode}",
      );
    }
  }
}

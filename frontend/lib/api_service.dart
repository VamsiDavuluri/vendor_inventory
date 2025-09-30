import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'screens/home_screen.dart';

class ApiService {
  static const String baseUrl = "http://192.168.0.121:3000/api";

  /// Utility: Extract S3 key from signed URL
  static String extractS3Key(String signedUrl) {
    final uri = Uri.parse(signedUrl);
    return Uri.decodeComponent(uri.path.substring(1)); // remove leading "/"
  }

  /// Fetch enriched product list
  static Future<List<Product>> fetchProductsWithStatus(String vendorId) async {
    final uri = Uri.parse("$baseUrl/vendor/$vendorId/products-with-status");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) throw Exception("Vendor not found or has no products.");

      return data
          .map(
            (json) => Product(
              // --- MODIFIED: Added fallback values for potentially null strings ---
              id: json['id'] ?? 'Unknown ID',
              name: json['name'] ?? 'Unnamed Product',
              brand: json['brand'] ?? 'Unknown Brand',

              // These fields are handled safely already
              hasImages: json['hasImages'] ?? false,
              coverImageUrl: json['coverImageUrl'],
              imageCount: json['imageCount'] ?? 0,
            ),
          )
          .toList();
    } else {
      throw Exception(
        "Failed to fetch enriched products for vendor $vendorId. Status: ${response.statusCode}",
      );
    }
  }

  // ... (the rest of your ApiService file remains the same) ...

  /// Fetch all product images
  static Future<List<String>> fetchProductImages(
    String vendorId,
    String productId,
  ) async {
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body)['images']);
    } else {
      throw Exception("Failed to fetch product images for $productId");
    }
  }

  /// A single function to handle all image management operations in one call.
  static Future<Map<String, dynamic>> batchUpdateImages({
    required String vendorId,
    required String productId,
    List<File>? imagesToUpload,
    List<String>? urlsToDelete,
    int? newLocalThumbnailIndex,
    String? newNetworkThumbnailUrl,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/products/$vendorId/$productId/manage-images",
    );

    var request = http.MultipartRequest("POST", uri);
    request.fields['action'] = 'batchUpdate';

    if (newLocalThumbnailIndex != null) {
      request.fields['thumbnail_index'] = newLocalThumbnailIndex.toString();
    }
    if (newNetworkThumbnailUrl != null) {
      request.fields['existing_thumbnail_url'] = newNetworkThumbnailUrl;
    }
    if (urlsToDelete != null && urlsToDelete.isNotEmpty) {
      request.fields['urls_to_delete'] = jsonEncode(urlsToDelete);
    }
    if (imagesToUpload != null) {
      for (var imageFile in imagesToUpload) {
        request.files.add(
          await http.MultipartFile.fromPath("files", imageFile.path),
        );
      }
    }

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Failed to update images (status: ${response.statusCode}) - $responseBody",
      );
    }
  }
}

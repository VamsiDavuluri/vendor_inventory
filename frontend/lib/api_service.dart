import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'screens/home_screen.dart';

class ApiService {
  static const String baseUrl = "http://192.168.0.121:3000";

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
              id: json['id'],
              name: json['name'],
              brand: json['brand'],
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

  /// Upload new images
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
      throw Exception("Failed to add images (status: ${response.statusCode})");
    }
  }

  /// Delete a specific image
  static Future<List<String>> deleteImage(
    String vendorId,
    String productId,
    String signedUrl,
  ) async {
    final key = extractS3Key(signedUrl);
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId/$key");

    print("➡️ Deleting image for product: $productId");
    print("   S3 Key: $key");

    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      final images = List<String>.from(jsonDecode(response.body)['images']);
      print(
        "✅ Delete successful. ${images.length} images remain for $productId:",
      );
      for (var i = 0; i < images.length; i++) {
        print("  Image $i: ${images[i]}");
      }
      return images;
    } else {
      throw Exception(
        "Failed to delete image (status: ${response.statusCode})",
      );
    }
  }

  /// Set a specific image as thumbnail
  static Future<void> setThumbnail(
    String vendorId,
    String productId,
    String signedUrl,
  ) async {
    final key = extractS3Key(signedUrl);
    final uri = Uri.parse("$baseUrl/products/$vendorId/$productId/thumbnail");

    print("➡️ Setting thumbnail for product: $productId");
    print("   S3 Key: $key");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageKey': key}),
    );

    if (response.statusCode == 200) {
      print("✅ Thumbnail updated successfully for product: $productId");
    } else {
      throw Exception(
        "Failed to set thumbnail (status: ${response.statusCode})",
      );
    }
  }
}

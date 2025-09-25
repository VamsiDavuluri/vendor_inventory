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

  /// ✅ Manage Images (Upload, Delete, SetThumbnail)
  static Future<List<String>> manageImages({
    required String vendorId,
    required String productId,
    required String action, // "upload", "delete", "setThumbnail"
    List<File>? images,
    int? thumbnailIndex,
    String? signedUrl,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/products/$vendorId/$productId/manage-images",
    );

    // ---------------- Upload ----------------
    if (action == "upload") {
      if (images == null || images.isEmpty) {
        throw Exception("No images provided for upload.");
      }

      print("➡️ Uploading ${images.length} images for product: $productId");

      var request = http.MultipartRequest("POST", uri);
      request.fields['action'] = "upload";
      if (thumbnailIndex != null) {
        request.fields['thumbnail_index'] = thumbnailIndex.toString();
      }

      for (var imageFile in images) {
        request.files.add(
          await http.MultipartFile.fromPath("files", imageFile.path),
        );
      }

      var response = await request.send();
      final responseData = jsonDecode(await response.stream.bytesToString());

      if (response.statusCode == 200) {
        final returnedUrls = List<String>.from(responseData['images']);
        print(
          "✅ Upload successful. Received ${returnedUrls.length} image URLs for $productId:",
        );
        for (var i = 0; i < returnedUrls.length; i++) {
          print("  Image $i: ${returnedUrls[i]}");
        }
        return returnedUrls;
      } else {
        throw Exception(
          "Failed to upload images (status: ${response.statusCode})",
        );
      }
    }
    // ---------------- Delete / SetThumbnail ----------------
    else if (action == "delete" || action == "setThumbnail") {
      if (signedUrl == null)
        throw Exception("signedUrl is required for $action");
      final key = extractS3Key(signedUrl);

      print(
        "➡️ ${action == "delete" ? "Deleting" : "Setting thumbnail"} for product: $productId",
      );
      print("   S3 Key: $key");

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": action, "imageKey": key}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final updatedUrls = List<String>.from(responseData['images']);
        if (action == "delete") {
          print(
            "✅ Delete successful. ${updatedUrls.length} images remain for $productId",
          );
        } else {
          print("✅ Thumbnail updated successfully for $productId");
        }
        return updatedUrls;
      } else {
        throw Exception("Failed to $action (status: ${response.statusCode})");
      }
    }

    throw Exception("Invalid action: $action");
  }
}

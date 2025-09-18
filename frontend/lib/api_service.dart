import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "http://192.168.0.121:3000"; // 🔥 your backend IP

  /// Upload multiple images
  static Future<Map<String, dynamic>> uploadMultipleImages(
    String vendorId,
    String productId,
    String productName,
    List<File> images,
  ) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/upload/$vendorId/$productId/$productName"),
    );

    for (var img in images) {
      request.files.add(await http.MultipartFile.fromPath("files", img.path));
    }

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);
      print("⬅️ Upload response: $data");
      return data;
    } else {
      throw Exception("Failed to upload images: ${response.statusCode}");
    }
  }

  /// Fetch product images (returns signed URLs)
  static Future<List<String>> fetchProductImages(
    String vendorId,
    String productId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/products/$vendorId/$productId"),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final images = List<String>.from(data['images']);
      print("⬅️ Fetch response: ${images.length} images");
      return images;
    } else {
      throw Exception("Failed to fetch product images");
    }
  }

  /// Delete image
  static Future<List<String>> deleteImage(
    String vendorId,
    String productId,
    String imageKey,
  ) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/products/$vendorId/$productId/$imageKey"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final images = List<String>.from(data['images']);
      print("⬅️ Delete response: ${images.length} images left");
      return images;
    } else {
      throw Exception("Failed to delete image: ${response.statusCode}");
    }
  }
}

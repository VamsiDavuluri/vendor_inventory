import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api_service.dart';

class UploadScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const UploadScreen({
    Key? key,
    required this.productId,
    required this.productName,
  }) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<File> _images = [];
  List<String> _previousImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPreviousImages();
  }

  // --- API & LOGIC METHODS (No Changes) ---

  Future<void> _fetchPreviousImages() async {
    try {
      final urls = await ApiService.fetchProductImages(
        "vendor_123",
        widget.productId,
      );
      if (mounted) setState(() => _previousImages = urls);
      print("📥 Fetched ${_previousImages.length} previous images.");
      for (var i = 0; i < _previousImages.length; i++) {
        print("➡️ Image $i: ${_previousImages[i]}");
      }
    } catch (e) {
      _showSnackBar("Failed to load previous images", Colors.red, Icons.error);
    }
  }

  Future<void> _uploadImages() async {
    if (_images.isEmpty) {
      _showSnackBar(
        "Please select new images to upload",
        Colors.orange,
        Icons.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.uploadMultipleImages(
        "vendor_123",
        widget.productId,
        widget.productName,
        _images,
      );
      if (result.containsKey('images')) {
        setState(() {
          _images.clear();
          _previousImages = List<String>.from(result['images']);
        });
        _showSnackBar(
          "Images uploaded successfully",
          Colors.green,
          Icons.check_circle,
        );
        print("📥 Updated ${_previousImages.length} images after upload.");
        for (var i = 0; i < _previousImages.length; i++) {
          print("➡️ Image $i: ${_previousImages[i]}");
        }
        // Note: No longer popping here, WillPopScope handles it.
      }
    } catch (e) {
      _showSnackBar("Upload failed: $e", Colors.red, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteImage(int index) async {
    final imageUrl = _previousImages[index];
    final imageKey = Uri.decodeFull(imageUrl.split('/').last.split('?').first);
    try {
      final updatedImages = await ApiService.deleteImage(
        "vendor_123",
        widget.productId,
        imageKey,
      );
      setState(() => _previousImages = updatedImages);
      _showSnackBar(
        "Image deleted successfully",
        Colors.green,
        Icons.check_circle,
      );
      print("📥 Updated ${_previousImages.length} images after delete.");
      for (var i = 0; i < _previousImages.length; i++) {
        print("➡️ Image $i: ${_previousImages[i]}");
      }
      // Note: No longer popping here, WillPopScope handles it.
    } catch (e) {
      _showSnackBar("Failed to delete image: $e", Colors.red, Icons.error);
    }
  }

  // --- UI WIDGETS (Restored Previous UI) ---

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) =>
                      LinearGradient(
                        colors: [Color(0xFF02D7C0), Color(0xFF009EAE)],
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                  child: Icon(Icons.photo, color: Colors.white),
                ),
                title: Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFiles = await ImagePicker().pickMultiImage();
                  if (pickedFiles.isNotEmpty) {
                    setState(
                      () =>
                          _images.addAll(pickedFiles.map((f) => File(f.path))),
                    );
                  }
                },
              ),
              ListTile(
                leading: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) =>
                      LinearGradient(
                        colors: [Color(0xFF02D7C0), Color(0xFF009EAE)],
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: Text("Take Photo"),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    setState(() => _images.add(File(pickedFile.path)));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _uploadBox() {
    return GestureDetector(
      onTap: () => _showUploadOptions(context),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [Color(0xFF02D7C0), Color(0xFF009EAE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Icon(Icons.cloud_upload, color: Colors.white, size: 40),
            ),
            SizedBox(height: 8),
            Text(
              "Click to upload product images",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final totalCount = _previousImages.length + _images.length;
    if (totalCount == 0) return Container();
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < _previousImages.length) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _previousImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (_, __, ___) =>
                      Icon(Icons.broken_image, color: Colors.red),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _deleteImage(index),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.delete, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        } else {
          final newImageIndex = index - _previousImages.length;
          final newImage = _images[newImageIndex];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  newImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(newImageIndex)),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _saveImagesButton() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 12, bottom: 20),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _uploadImages,
        style:
            ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.transparent,
            ).copyWith(
              backgroundColor: MaterialStateProperty.all(Colors.transparent),
              shadowColor: MaterialStateProperty.all(Colors.transparent),
            ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _images.isNotEmpty
                  ? [Color(0xFF02D7C0), Color(0xFF009EAE)]
                  : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: 14),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    "Save Images",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color bgColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayedTitle = widget.productName.length > 20
        ? '${widget.productName.substring(0, 20)}...'
        : widget.productName;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _previousImages.isNotEmpty);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleSpacing: 0.0,
          title: Text(
            displayedTitle,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _uploadBox(),
              SizedBox(height: 16),
              Expanded(child: _buildImageGrid()),
              _saveImagesButton(),
            ],
          ),
        ),
      ),
    );
  }
}

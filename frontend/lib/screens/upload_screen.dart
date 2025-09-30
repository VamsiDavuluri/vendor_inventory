import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:another_flushbar/flushbar.dart';
import '../api_service.dart';

class UploadScreen extends StatefulWidget {
  final String vendorId;
  final String productId;
  final String productName;
  const UploadScreen({
    Key? key,
    required this.vendorId,
    required this.productId,
    required this.productName,
  }) : super(key: key);
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<File> _localImages = [];
  List<String> _networkImages = [];
  bool _isLoading = false;
  File? _localThumbnail;
  String? _networkThumbnail;
  String? _originalNetworkThumbnail;

  final List<String> _signedUrlsToDelete = [];

  bool get _hasChanges =>
      _localImages.isNotEmpty ||
      _signedUrlsToDelete.isNotEmpty ||
      (_networkThumbnail != null &&
          _networkThumbnail != _originalNetworkThumbnail);

  @override
  void initState() {
    super.initState();
    _fetchPreviousImages();
  }

  Future<void> _fetchPreviousImages() async {
    try {
      final urls = await ApiService.fetchProductImages(
        widget.vendorId,
        widget.productId,
      );
      if (mounted) {
        setState(() {
          _networkImages = urls;
          if (urls.isNotEmpty) {
            _networkThumbnail = urls.first;
            _originalNetworkThumbnail = urls.first;
          } else {
            _networkThumbnail = null;
            _originalNetworkThumbnail = null;
          }
        });
      }
    } catch (e) {
      _showTopFlashbar(
        "Failed to load previous images",
        Colors.red,
        Icons.error,
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      _showTopFlashbar("No changes to save", Colors.orange, Icons.warning);
      return;
    }
    setState(() => _isLoading = true);

    try {
      int? thumbnailIndex;
      if (_localThumbnail != null) {
        thumbnailIndex = _localImages.indexOf(_localThumbnail!);
      }

      String? networkThumbnailUrl;
      if (_networkThumbnail != null &&
          _networkThumbnail != _originalNetworkThumbnail) {
        networkThumbnailUrl = _networkThumbnail;
      }

      final Map<String, dynamic> result = await ApiService.batchUpdateImages(
        vendorId: widget.vendorId,
        productId: widget.productId,
        imagesToUpload: _localImages,
        urlsToDelete: _signedUrlsToDelete,
        newLocalThumbnailIndex: thumbnailIndex,
        newNetworkThumbnailUrl: networkThumbnailUrl,
      );

      final List<dynamic> imageUrls = result['images'] ?? [];
      print(
        "✅ Batch update successful. Received ${imageUrls.length} image URLs for ${widget.productId}:",
      );
      for (var i = 0; i < imageUrls.length; i++) {
        print("  Image $i: ${imageUrls[i]}");
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      _showTopFlashbar("Save failed: $e", Colors.red, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteNetworkImage(int index) {
    if ((_localImages.length + _networkImages.length) <= 1) {
      _showTopFlashbar(
        "At least one image must remain.",
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    setState(() {
      final imageUrl = _networkImages[index];
      _signedUrlsToDelete.add(imageUrl);
      _networkImages.removeAt(index);

      if (_networkThumbnail == imageUrl) {
        _networkThumbnail = _networkImages.isNotEmpty
            ? _networkImages.first
            : null;
        _originalNetworkThumbnail = _networkThumbnail;
      }
    });
  }

  void _deleteLocalImage(int index) {
    if ((_localImages.length + _networkImages.length) <= 1) {
      _showTopFlashbar(
        "At least one image must remain.",
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    final localImageFile = _localImages[index];
    setState(() {
      if (localImageFile == _localThumbnail) _localThumbnail = null;
      _localImages.removeAt(index);
    });
  }

  void _setAsLocalThumbnail(File imageFile) {
    setState(() {
      _localThumbnail = imageFile;
      _networkThumbnail = null;
    });
  }

  void _setAsNetworkThumbnail(String url) {
    setState(() {
      _networkThumbnail = url;
      _localThumbnail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayedTitle = widget.productName.length > 20
        ? '${widget.productName.substring(0, 20)}...'
        : widget.productName;

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text(
                'You have unsaved changes. Are you sure you want to leave?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          titleSpacing: 0.0,
          title: Text(
            displayedTitle,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UploadBox(onTap: () => _showUploadOptions(context)),
              const SizedBox(height: 16),
              if (_networkImages.isNotEmpty || _localImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Tap any image to set as thumbnail",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              Expanded(child: _buildImageGrid()),
              _SaveImagesButton(
                isLoading: _isLoading,
                hasChanges: _hasChanges,
                onPressed: _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final totalCount = _networkImages.length + _localImages.length;
    if (totalCount == 0) return Container();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < _networkImages.length) {
          final imageUrl = _networkImages[index];
          final isHighlighted = imageUrl == _networkThumbnail;
          return _UploadedImageCard(
            imageUrl: imageUrl,
            isThumbnail: isHighlighted,
            onDelete: () => _deleteNetworkImage(index),
            onTap: () => _setAsNetworkThumbnail(imageUrl),
          );
        } else {
          final localIndex = index - _networkImages.length;
          final localImageFile = _localImages[localIndex];
          final isHighlighted = localImageFile == _localThumbnail;
          return _LocalImageCard(
            imageFile: localImageFile,
            isThumbnail: isHighlighted,
            onTap: () => _setAsLocalThumbnail(localImageFile),
            onDelete: () => _deleteLocalImage(localIndex),
          );
        }
      },
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UploadOptions(
        onGalleryPick: () async {
          Navigator.pop(context);
          final pickedFiles = await ImagePicker().pickMultiImage();
          if (pickedFiles.isNotEmpty) {
            setState(
              () => _localImages.addAll(pickedFiles.map((f) => File(f.path))),
            );
          }
        },
        onCameraPick: () async {
          Navigator.pop(context);
          final pickedFile = await ImagePicker().pickImage(
            source: ImageSource.camera,
          );
          if (pickedFile != null) {
            setState(() => _localImages.add(File(pickedFile.path)));
          }
        },
      ),
    );
  }

  void _showTopFlashbar(String message, Color bgColor, IconData icon) {
    Flushbar(
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      icon: Icon(icon, color: Colors.white),
      backgroundColor: bgColor,
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      boxShadows: const [
        BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
      ],
    ).show(context);
  }
}

class _UploadedImageCard extends StatelessWidget {
  final String imageUrl;
  final bool isThumbnail;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _UploadedImageCard({
    Key? key,
    required this.imageUrl,
    required this.isThumbnail,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isThumbnail
                  ? Border.all(width: 3, color: const Color(0xFF02D7C0))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (c, u) =>
                    Center(child: Icon(Icons.image, color: Colors.grey[300])),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.delete, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalImageCard extends StatelessWidget {
  final File imageFile;
  final bool isThumbnail;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _LocalImageCard({
    Key? key,
    required this.imageFile,
    required this.isThumbnail,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isThumbnail
                  ? Border.all(width: 3, color: const Color(0xFF02D7C0))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(imageFile, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadBox({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF02D7C0), Color(0xFF009EAE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: const Icon(Icons.cloud_upload, size: 40),
            ),
            const SizedBox(height: 8),
            const Text("Click to upload product images"),
          ],
        ),
      ),
    );
  }
}

class _SaveImagesButton extends StatelessWidget {
  final bool isLoading;
  final bool hasChanges;
  final VoidCallback onPressed;
  const _SaveImagesButton({
    Key? key,
    required this.isLoading,
    required this.hasChanges,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      child: ElevatedButton(
        onPressed: isLoading || !hasChanges ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasChanges
                  ? [const Color(0xFF02D7C0), const Color(0xFF009EAE)]
                  : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
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
}

class _UploadOptions extends StatelessWidget {
  final VoidCallback onGalleryPick;
  final VoidCallback onCameraPick;
  const _UploadOptions({
    Key? key,
    required this.onGalleryPick,
    required this.onCameraPick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo, color: Color(0xFF02D7C0)),
            title: const Text("Choose from Gallery"),
            onTap: onGalleryPick,
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(0xFF02D7C0)),
            title: const Text("Take Photo"),
            onTap: onCameraPick,
          ),
        ],
      ),
    );
  }
}

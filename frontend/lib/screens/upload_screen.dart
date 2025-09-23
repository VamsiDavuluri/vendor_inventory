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
  String? _originalNetworkThumbnailUrl;
  String? _newNetworkThumbnailUrl;
  File? _localThumbnail;

  bool get _hasUnsavedChanges =>
      _localImages.isNotEmpty ||
      (_newNetworkThumbnailUrl != null &&
          _newNetworkThumbnailUrl != _originalNetworkThumbnailUrl);

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
          _originalNetworkThumbnailUrl = urls.isNotEmpty ? urls.first : null;
          _newNetworkThumbnailUrl = _originalNetworkThumbnailUrl;
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

  /// REWRITTEN AND ROBUST SAVE LOGIC
  Future<void> _handleSaveChanges() async {
    setState(() => _isLoading = true);
    try {
      // If there are new images to upload, this is the primary action.
      if (_localImages.isNotEmpty) {
        // Find the index of the selected local thumbnail BEFORE uploading.
        int? thumbnailIndex;
        if (_localThumbnail != null) {
          thumbnailIndex = _localImages.indexOf(_localThumbnail!);
        }

        final result = await ApiService.addImages(
          widget.vendorId,
          widget.productId,
          _localImages,
          thumbnailIndex,
        );

        if (result.containsKey('images')) {
          _showTopFlashbar(
            "Images uploaded successfully",
            Colors.green,
            Icons.check_circle,
          );

          // After a successful upload, always refresh the state from the server
          // to get the final, correct order of all images.
          await _fetchPreviousImages();

          setState(() {
            _localImages.clear();
            _localThumbnail = null;
          });
        }
      }
      // If there are NO new images, but the user has selected a different NETWORK image as the thumbnail.
      else if (_newNetworkThumbnailUrl != null &&
          _newNetworkThumbnailUrl != _originalNetworkThumbnailUrl) {
        await _setAsNetworkThumbnail(_newNetworkThumbnailUrl!);
      }
    } catch (e) {
      _showTopFlashbar("Save failed: $e", Colors.red, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNetworkImage(int index) async {
    setState(() => _isLoading = true);
    final imageUrl = _networkImages[index];
    final imageKey = Uri.decodeFull(imageUrl.split('/').last.split('?').first);
    try {
      final updatedImages = await ApiService.deleteImage(
        widget.vendorId,
        widget.productId,
        imageKey,
      );
      if (mounted) {
        setState(() {
          _networkImages = updatedImages;
          _originalNetworkThumbnailUrl = updatedImages.isNotEmpty
              ? updatedImages.first
              : null;
          _newNetworkThumbnailUrl = _originalNetworkThumbnailUrl;
        });
      }
      _showTopFlashbar(
        "Image deleted successfully",
        Colors.green,
        Icons.check_circle,
      );
    } catch (e) {
      _showTopFlashbar("Failed to delete image: $e", Colors.red, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteLocalImage(int index) {
    final localImageFile = _localImages[index];
    setState(() {
      if (localImageFile == _localThumbnail) _localThumbnail = null;
      _localImages.removeAt(index);
    });
  }

  Future<void> _setAsNetworkThumbnail(
    String imageUrl, {
    bool showIndicator = true,
    bool showSuccessMessage = true,
  }) async {
    if (showIndicator) setState(() => _isLoading = true);
    final imageKey = Uri.decodeFull(imageUrl.split('/').last.split('?').first);
    try {
      await ApiService.setThumbnail(
        widget.vendorId,
        widget.productId,
        imageKey,
      );
      if (showSuccessMessage)
        _showTopFlashbar(
          "✅ Thumbnail updated successfully",
          Colors.green,
          Icons.check_circle,
        );
      await _fetchPreviousImages();
    } catch (e) {
      _showTopFlashbar("❌ Failed to set thumbnail", Colors.red, Icons.error);
    } finally {
      if (showIndicator && mounted) setState(() => _isLoading = false);
    }
  }

  void _setAsLocalThumbnail(File imageFile) {
    setState(() {
      _localThumbnail = imageFile;
      _newNetworkThumbnailUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayedTitle = widget.productName.length > 20
        ? '${widget.productName.substring(0, 20)}...'
        : widget.productName;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UploadBox(onTap: () => _showUploadOptions(context)),
              SizedBox(height: 16),
              if (_localImages.isNotEmpty || _networkImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Tap an image to set as thumbnail",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              Expanded(child: _buildImageGrid()),
              _SaveImagesButton(
                isLoading: _isLoading,
                hasChanges: _hasUnsavedChanges,
                onPressed: _handleSaveChanges,
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < _networkImages.length) {
          final imageUrl = _networkImages[index];
          final isHighlighted =
              imageUrl == _newNetworkThumbnailUrl && _localThumbnail == null;
          return _UploadedImageCard(
            imageUrl: imageUrl,
            isThumbnail: isHighlighted,
            onTap: () => setState(() {
              _localThumbnail = null;
              _newNetworkThumbnailUrl = imageUrl;
            }),
            onDelete: () => _deleteNetworkImage(index),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UploadOptions(
        onGalleryPick: () async {
          Navigator.pop(context);
          final pickedFiles = await ImagePicker().pickMultiImage();
          if (pickedFiles.isNotEmpty)
            setState(
              () => _localImages.addAll(pickedFiles.map((f) => File(f.path))),
            );
        },
        onCameraPick: () async {
          Navigator.pop(context);
          final pickedFile = await ImagePicker().pickImage(
            source: ImageSource.camera,
          );
          if (pickedFile != null)
            setState(() => _localImages.add(File(pickedFile.path)));
        },
      ),
    );
  }

  void _showTopFlashbar(String message, Color bgColor, IconData icon) {
    Flushbar(
      messageText: Text(
        message,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      icon: Icon(icon, color: Colors.white),
      backgroundColor: bgColor,
      duration: Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
      margin: EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      boxShadows: [
        BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
      ],
    )..show(context);
  }
}

class _UploadedImageCard extends StatelessWidget {
  final String imageUrl;
  final bool isThumbnail;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _UploadedImageCard({
    Key? key,
    required this.imageUrl,
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
              borderRadius: BorderRadius.circular(10),
              border: isThumbnail
                  ? Border.all(color: const Color(0xFF02D7C0), width: 3)
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
              borderRadius: BorderRadius.circular(10),
              border: isThumbnail
                  ? Border.all(color: const Color(0xFF02D7C0), width: 3)
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
              child: CircleAvatar(
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
              shaderCallback: (bounds) => LinearGradient(
                colors: [const Color(0xFF02D7C0), const Color(0xFF009EAE)],
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
      margin: EdgeInsets.only(top: 12, bottom: 20),
      child: ElevatedButton(
        onPressed: isLoading || !hasChanges ? null : onPressed,
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
            padding: EdgeInsets.symmetric(vertical: 14),
            child: isLoading
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
            leading: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [const Color(0xFF02D7C0), const Color(0xFF009EAE)],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Icon(Icons.photo, color: Colors.white),
            ),
            title: Text("Choose from Gallery"),
            onTap: onGalleryPick,
          ),
          ListTile(
            leading: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [const Color(0xFF02D7C0), const Color(0xFF009EAE)],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Icon(Icons.camera_alt, color: Colors.white),
            ),
            title: Text("Take Photo"),
            onTap: onCameraPick,
          ),
        ],
      ),
    );
  }
}

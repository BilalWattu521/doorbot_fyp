import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:doorbot_fyp/services/firebase_storage_service.dart';

class FirebaseImageViewer extends StatefulWidget {
  final String imagePath; // Full path in Firebase Storage
  final double width;
  final double height;
  final BoxFit fit;
  final bool showLoadingIndicator;

  const FirebaseImageViewer({
    super.key,
    required this.imagePath,
    this.width = double.infinity,
    this.height = 300,
    this.fit = BoxFit.cover,
    this.showLoadingIndicator = true,
  });

  @override
  State<FirebaseImageViewer> createState() => _FirebaseImageViewerState();
}

class _FirebaseImageViewerState extends State<FirebaseImageViewer> {
  late Future<String> _imageUrlFuture;

  @override
  void initState() {
    super.initState();
    _imageUrlFuture = FirebaseStorageService().getDownloadUrl(
      imagePath: widget.imagePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _imageUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.showLoadingIndicator
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }

        if (snapshot.hasError) {
          // Check if it's a 404 error and handle quietly
          final is404 =
              snapshot.error.toString().contains('404') ||
              snapshot.error.toString().contains('object-not-found');
          if (!is404) {
            debugPrint('Error loading image: ${snapshot.error}');
          }

          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, size: 48)),
            ),
          );
        }

        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) => Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: widget.showLoadingIndicator
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          errorWidget: (context, url, error) => Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}

/// Widget to display a grid of images from a Firebase Storage folder
class FirebaseImageGrid extends StatefulWidget {
  final String
  folderPath; // Firebase Storage folder path (e.g., "doorbell/snapshots")
  final int crossAxisCount;
  final double spacing;

  const FirebaseImageGrid({
    super.key,
    required this.folderPath,
    this.crossAxisCount = 2,
    this.spacing = 8,
  });

  @override
  State<FirebaseImageGrid> createState() => _FirebaseImageGridState();
}

class _FirebaseImageGridState extends State<FirebaseImageGrid> {
  late Future<List<String>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = FirebaseStorageService().listImages(
      folderPath: widget.folderPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading images: ${snapshot.error}'),
              ],
            ),
          );
        }

        final images = snapshot.data ?? [];

        if (images.isEmpty) {
          return const Center(child: Text('No images found'));
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            crossAxisSpacing: widget.spacing,
            mainAxisSpacing: widget.spacing,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                // Optional: Open full-screen image viewer
                _showImageDialog(context, images[index]);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FirebaseImageViewer(
                  imagePath: images[index],
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: FirebaseImageViewer(
            imagePath: imagePath,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}

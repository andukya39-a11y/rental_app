import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Displays an image from Firebase Storage.
///
/// Accepts either a `gs://` storage path or an `https://` download URL.
/// `gs://` paths are resolved to a download URL before display.
class FirebaseStorageImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FirebaseStorageImage({
    Key? key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<FirebaseStorageImage> createState() => _FirebaseStorageImageState();
}

class _FirebaseStorageImageState extends State<FirebaseStorageImage> {
  late Future<String> _downloadUrlFuture;

  @override
  void initState() {
    super.initState();
    _downloadUrlFuture = _resolve(widget.url);
  }

  @override
  void didUpdateWidget(FirebaseStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _downloadUrlFuture = _resolve(widget.url);
    }
  }

  static Future<String> _resolve(String url) {
    if (url.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(url).getDownloadURL();
    }
    return Future.value(url);
  }

  Widget get _defaultPlaceholder => Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFF0F0F0),
      );

  Widget get _defaultError => Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: Icon(Icons.home_rounded, color: Color(0xFFBDBDBD), size: 32),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _downloadUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder ?? _defaultPlaceholder;
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return widget.errorWidget ?? _defaultError;
        }
        return Image.network(
          snapshot.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : (widget.placeholder ?? _defaultPlaceholder),
          errorBuilder: (_, __, ___) => widget.errorWidget ?? _defaultError,
        );
      },
    );
  }
}

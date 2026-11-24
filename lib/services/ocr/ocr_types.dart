import 'dart:typed_data';

/// A picture chosen from the camera or gallery, ready for text recognition.
class OcrImage {
  const OcrImage({required this.name, this.path, this.bytes});

  final String name;

  /// Available on Android/desktop.
  final String? path;

  /// Available on web.
  final Uint8List? bytes;
}

/// Raised when the device cannot read text from the chosen picture.
class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

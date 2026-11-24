import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_mobile.dart'
    if (dart.library.html) 'ocr_service_web.dart';
import 'ocr_types.dart';

export 'ocr_types.dart';

/// Reads text from a photo using the best engine for the current platform.
Future<String> recognizeText(OcrImage image) => recognizeTextPlatform(image);

/// Lets the user take a photo or choose one, then reads its text.
///
/// Returns `null` when the user cancels. Throws [OcrException] when the image
/// cannot be read.
Future<OcrScan?> scanText({
  required OcrSource source,
  ImagePicker? picker,
}) async {
  final imagePicker = picker ?? ImagePicker();
  final XFile? file;
  try {
    file = await imagePicker.pickImage(
      source: source == OcrSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
    );
  } on Object catch (error) {
    throw OcrException('Could not open the camera or gallery. $error');
  }
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  final text = await recognizeText(
    OcrImage(
      name: file.name,
      // XFile.path is a blob-style value on web; only native OCR uses it.
      path: kIsWeb ? null : file.path,
      bytes: bytes,
    ),
  );
  return OcrScan(text: text, imageName: file.name);
}

enum OcrSource { camera, gallery }

class OcrScan {
  const OcrScan({required this.text, required this.imageName});

  final String text;
  final String imageName;
}

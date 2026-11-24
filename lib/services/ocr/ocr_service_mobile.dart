import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_types.dart';

/// Uses Google ML Kit on the device. No internet connection is needed.
Future<String> recognizeTextPlatform(OcrImage image) async {
  final path = image.path;
  if (path == null) {
    throw const OcrException('Could not read the selected picture.');
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return result.text;
  } finally {
    await recognizer.close();
  }
}

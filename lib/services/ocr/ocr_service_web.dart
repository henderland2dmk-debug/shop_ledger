import 'package:ocr_flutter_web/ocr_flutter_web.dart';

import 'ocr_types.dart';

/// Uses Tesseract.js in the browser. The OCR library is loaded on first use.
Future<String> recognizeTextPlatform(OcrImage image) async {
  final bytes = image.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const OcrException('Could not read the selected picture.');
  }

  final name = image.name.trim().isEmpty ? 'scan.png' : image.name;
  try {
    final result = await OcrFlutterWeb().extractText(
      bytes,
      filename: name,
      language: 'eng',
    );
    return result;
  } on Object catch (error) {
    throw OcrException('Could not scan this picture. $error');
  }
}

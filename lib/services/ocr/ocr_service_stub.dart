import 'ocr_types.dart';

Future<String> recognizeTextPlatform(OcrImage image) async {
  throw const OcrException('Text scanning is not available on this device.');
}

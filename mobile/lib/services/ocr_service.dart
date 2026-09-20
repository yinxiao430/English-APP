import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 拍照/选图 + 端上离线英文 OCR
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final ImagePicker _picker = ImagePicker();
  // latin 脚本覆盖英文，模型端上内置，离线可用
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// 选图并识别。fromCamera=true 调起相机，false 打开相册。
  /// 返回 (图片路径, 识别出的文本)；用户取消返回 null。
  Future<OcrResult?> pickAndRecognize({required bool fromCamera}) async {
    final XFile? file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return null;

    final input = InputImage.fromFilePath(file.path);
    final RecognizedText recognized = await _recognizer.processImage(input);

    // 按块拼接：块之间空行，尽量保留试卷的段落/题目分隔
    final buf = StringBuffer();
    for (final block in recognized.blocks) {
      final lines = block.lines.map((l) => l.text).join(' ');
      buf.writeln(lines);
      buf.writeln();
    }
    return OcrResult(imagePath: file.path, text: buf.toString().trim());
  }

  void dispose() => _recognizer.close();
}

class OcrResult {
  final String imagePath;
  final String text;
  OcrResult({required this.imagePath, required this.text});
}

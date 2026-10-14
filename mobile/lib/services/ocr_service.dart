import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 拍照/选图 + 端上离线英文 OCR，支持多页采集与按页合并
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final ImagePicker _picker = ImagePicker();
  // latin 脚本覆盖英文，模型端上内置，离线可用
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// 相机拍摄单张（用于连拍逐页采集）。用户取消返回 null。
  Future<XFile?> takePhoto() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
  }

  /// 相册选择，允许多张。用户取消返回 null（部分机型在只选一张时返回长度 1 的列表）。
  Future<List<XFile>?> pickGalleryImages() async {
    return _picker.pickMultiImage(imageQuality: 90);
  }

  /// 对单张图片做 OCR。按块拼接：块之间空行，尽量保留试卷的段落/题目分隔。
  Future<String> recognizePath(String path) async {
    final input = InputImage.fromFilePath(path);
    final RecognizedText recognized = await _recognizer.processImage(input);

    final buf = StringBuffer();
    for (final block in recognized.blocks) {
      final lines = block.lines.map((l) => l.text).join(' ');
      buf.writeln(lines);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  /// 多页 OCR 文本按页序合并，处理跨页连字符与跨页断句。
  /// 启发式规则，合并后仍由用户在校对框中人工确认。
  static String mergePageTexts(List<String> pages) {
    final ps = pages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ps.isEmpty) return '';

    var merged = ps[0];
    for (var i = 1; i < ps.length; i++) {
      final next = ps[i];

      // 1) 上一页以连字符结尾：跨页断词，如 environ- + ment → environment
      if (merged.endsWith('-')) {
        merged = merged.substring(0, merged.length - 1) + next;
        continue;
      }

      final lastChar = merged[merged.length - 1];
      final firstChar = next[0];
      const sentenceEnd = {'.', '!', '?', ':', ';', '"', '”', '’', '）', ')'};

      // 2) 上一页未到句末/段末，且下一页以小写字母开头：同一句被分页切开，空格连接
      final midSentence =
          !sentenceEnd.contains(lastChar) && RegExp(r'^[a-z(（]').hasMatch(firstChar);
      merged = midSentence ? '$merged $next' : '$merged\n$next';
    }
    return merged;
  }

  void dispose() => _recognizer.close();
}

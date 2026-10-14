import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'word_sheet.dart';
import '../services/studied_service.dart';

/// 把英文文本拆成「单词 + 标点/空格」：
/// - 点击单词弹出释义卡（WordSheet）
/// - 已加入墨墨的单词自动标黄加粗
/// - 长按整段可复制原文（copyOnLongPress）
class TokenizedSentence extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool copyOnLongPress;
  final Color wordColor;
  const TokenizedSentence({
    super.key,
    required this.text,
    this.style,
    this.copyOnLongPress = true,
    this.wordColor = const Color(0xFF2F4BA8),
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制到剪贴板'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle(fontSize: 16, height: 1.7);
    // 监听“已加入墨墨”集合变化，加入新单词后立即刷新标黄
    return AnimatedBuilder(
      animation: StudiedService.instance,
      builder: (context, _) {
        final spans = <TextSpan>[];
        // 连续的英文字母/撇号算一个单词，其余原样保留
        final matches = RegExp(r"[A-Za-z']+").allMatches(text).toList();
        int cursor = 0;
        for (final m in matches) {
          if (m.start > cursor) {
            spans.add(TextSpan(text: text.substring(cursor, m.start)));
          }
          final word = text.substring(m.start, m.end);
          final studied = StudiedService.instance.contains(word);
          spans.add(TextSpan(
            text: word,
            style: studied
                ? const TextStyle(
                    color: Color(0xFF6B5200),
                    fontWeight: FontWeight.bold,
                    backgroundColor: Color(0xFFFFE45E),
                  )
                : TextStyle(
                    color: wordColor,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => WordSheet.show(context, word),
          ));
          cursor = m.end;
        }
        if (cursor < text.length) {
          spans.add(TextSpan(text: text.substring(cursor)));
        }

        Widget rich = Text.rich(TextSpan(style: base, children: spans));
        if (copyOnLongPress) {
          rich = GestureDetector(
            onLongPress: () => _copy(context),
            child: rich,
          );
        }
        return rich;
      },
    );
  }
}

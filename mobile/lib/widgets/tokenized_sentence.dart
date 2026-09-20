import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'word_sheet.dart';

/// 把英文句子拆成「单词 + 标点/空格」，单词可点击弹出释义卡。
class TokenizedSentence extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const TokenizedSentence({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle(fontSize: 16, height: 1.7);
    final spans = <TextSpan>[];
    // 连续的英文字母/撇号算一个单词，其余原样保留
    final matches = RegExp(r"[A-Za-z']+").allMatches(text).toList();
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      final word = text.substring(m.start, m.end);
      spans.add(TextSpan(
        text: word,
        style: const TextStyle(
          color: Color(0xFF2F4BA8),
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => WordSheet.show(context, word),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));

    return Text.rich(TextSpan(style: base, children: spans));
  }
}

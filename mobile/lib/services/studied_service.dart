import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录已经通过本 App 加入墨墨背单词的单词（小写拼写集合）。
/// 全局单例 + ChangeNotifier：加入新词后界面自动把对应单词标黄。
class StudiedService extends ChangeNotifier {
  StudiedService._();
  static final StudiedService instance = StudiedService._();

  static const _key = 'maimemo_added_words';

  final Set<String> _words = {};

  /// 启动时读取本地记录
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _words
      ..clear()
      ..addAll((sp.getStringList(_key) ?? const <String>[]).map((e) => e.toLowerCase()));
    notifyListeners();
  }

  /// 该单词是否已加入墨墨
  bool contains(String word) => _words.contains(word.toLowerCase().trim());

  /// 标记一批单词为已加入，并持久化；有变化才通知刷新
  Future<void> markAll(List<String> words) async {
    var changed = false;
    for (final w in words) {
      final x = w.toLowerCase().trim();
      if (x.isNotEmpty && _words.add(x)) changed = true;
    }
    if (changed) {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_key, _words.toList());
      notifyListeners();
    }
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ECDICT 离线英汉词典查询。
/// 需要先把 ecdict.db（表名 dict）放到 assets/dict/ecdict.db，
/// 下载方式见 assets/dict/README.txt。
/// assets/dict/version.txt 为词典数据版本号，
/// 与本机已复制版本不一致时会自动重新复制（用于词库更新/瘦身）。
class DictService {
  DictService._();
  static final DictService instance = DictService._();

  static const _assetPath = 'assets/dict/ecdict.db';
  static const _versionAsset = 'assets/dict/version.txt';
  static const _versionKey = 'dict_db_version';

  Database? _db;

  Future<void> _ensureOpen() async {
    if (_db != null) return;
    final dbPath = p.join(await getDatabasesPath(), 'ecdict.db');
    final file = File(dbPath);

    // 读取 asset 中的词典版本（读不到按 '0' 处理）
    String assetVersion = '0';
    try {
      assetVersion =
          (await rootBundle.loadString(_versionAsset)).trim();
    } catch (_) {
      assetVersion = '0';
    }
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getString(_versionKey) ?? '0';

    // asset 里的数据库要先复制到可写目录才能打开；版本不一致则重新复制
    if (!await file.exists() || localVersion != assetVersion) {
      final byteData = await rootBundle.load(_assetPath);
      await file.writeAsBytes(
        byteData.buffer.asUint8List(),
        flush: true,
      );
      await prefs.setString(_versionKey, assetVersion);
    }
    _db = await openDatabase(dbPath, readOnly: true);
  }

  /// 查词；查不到返回 null。word 为 ECDICT 中 dict 表结构：
  /// word 单词 / phonetic 音标 / translation 中文释义 / pos 词性 / exchange 词形变化
  Future<DictEntry?> lookup(String word) async {
    final w = word.toLowerCase().trim();
    if (w.isEmpty) return null;
    try {
      await _ensureOpen();
    } catch (e) {
      // 词典文件尚未放置时不崩溃，返回 null 由上层提示
      return null;
    }
    final rows = await _db!.rawQuery(
      'SELECT word, phonetic, translation, pos, exchange FROM dict '
      'WHERE word = ? OR word = ? LIMIT 1',
      [w, _lemmatize(w)],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DictEntry(
      word: '${r['word']}',
      phonetic: '${r['phonetic'] ?? ''}',
      translation: '${r['translation'] ?? ''}',
      pos: '${r['pos'] ?? ''}',
    );
  }

  // 简单词形还原兜底：复数/过去式/ing（精确还原仍以 ECDICT exchange 字段为准）
  String _lemmatize(String w) {
    if (w.endsWith('ies') && w.length > 4) return '${w.substring(0, w.length - 3)}y';
    if (w.endsWith('es') && w.length > 3) return w.substring(0, w.length - 2);
    if (w.endsWith('s') && w.length > 2) return w.substring(0, w.length - 1);
    if (w.endsWith('ing') && w.length > 5) return w.substring(0, w.length - 3);
    if (w.endsWith('ed') && w.length > 4) return w.substring(0, w.length - 2);
    return w;
  }
}

class DictEntry {
  final String word;
  final String phonetic;
  final String translation;
  final String pos;
  DictEntry({
    required this.word,
    required this.phonetic,
    required this.translation,
    required this.pos,
  });
}

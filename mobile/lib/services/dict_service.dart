import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// 英汉词典查询：先查端上离线 ECDICT，未命中再回退到云端全量词库（约 340 万词条）。
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

  /// 查词：先本地、后云端；都查不到返回 null。
  Future<DictEntry?> lookup(String word) async {
    return (await _lookupLocal(word)) ?? (await _lookupCloud(word));
  }

  /// 本地离线词库查询；查不到返回 null。
  /// ECDICT dict 表结构：
  /// word 单词 / phonetic 音标 / translation 中文释义 / pos 词性 / exchange 词形变化
  Future<DictEntry?> _lookupLocal(String word) async {
    final w = word.toLowerCase().trim();
    if (w.isEmpty) return null;
    try {
      await _ensureOpen();
    } catch (e) {
      // 词典文件尚未放置时不崩溃，交给云端回退
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
      source: 'local',
    );
  }

  /// 云端全量词库回退查询；网络异常或未收录返回 null。
  Future<DictEntry?> _lookupCloud(String word) async {
    final d = await ApiService.instance.lookupCloud(word);
    if (d == null) return null;
    return DictEntry(
      word: '${d['word'] ?? word}',
      phonetic: '${d['phonetic'] ?? ''}',
      translation: '${d['translation'] ?? ''}',
      pos: '${d['pos'] ?? ''}',
      source: 'cloud',
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
  /// local = 本地离线词库；cloud = 云端全量词库
  final String source;
  DictEntry({
    required this.word,
    required this.phonetic,
    required this.translation,
    required this.pos,
    this.source = 'local',
  });
}

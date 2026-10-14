import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/analysis_result.dart';

/// 一条历史分析记录
class HistoryEntry {
  final int id;
  final String title;
  final String article;
  final String questions;
  final String level;
  final AnalysisResult result;
  final String fingerprint;
  final DateTime createdAt;

  HistoryEntry({
    required this.id,
    required this.title,
    required this.article,
    required this.questions,
    required this.level,
    required this.result,
    required this.fingerprint,
    required this.createdAt,
  });
}

/// 精讲历史的本地存档（独立 SQLite 文件，与只读的 ECDICT 词典库互不影响）。
/// 同一篇文章（指纹相同）只保留一条，重新分析会刷新结果与时间。
class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  Database? _db;

  Future<void> _ensureOpen() async {
    if (_db != null) return;
    final dbPath = p.join(await getDatabasesPath(), 'reading_history.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            article TEXT NOT NULL,
            questions TEXT NOT NULL DEFAULT '',
            level TEXT NOT NULL DEFAULT 'auto',
            result_json TEXT NOT NULL,
            fingerprint TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_history_fingerprint ON history(fingerprint)');
        await db.execute(
            'CREATE INDEX idx_history_created ON history(created_at)');
      },
    );
  }

  /// 归一化：小写并只保留字母数字，消除 OCR 空白/标点差异
  static String normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  /// 文章指纹：归一化后取前 200 字符算 SHA-1。
  /// 取前缀可容忍文末题目、OCR 尾部噪声造成的差异。
  static String fingerprintOf(String article) {
    final norm = normalize(article);
    final head = norm.length <= 200 ? norm : norm.substring(0, 200);
    return sha1.convert(utf8.encode(head)).toString();
  }

  String _makeTitle(String article, AnalysisResult result) {
    String clip(String s) {
      final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (t.isEmpty) return '';
      return t.length <= 30 ? t : '${t.substring(0, 30)}…';
    }

    final bySummary = clip(result.summary);
    if (bySummary.isNotEmpty) return bySummary;
    final firstLine = article
        .split(RegExp(r'[\r\n]'))
        .map(clip)
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return firstLine.isEmpty ? '未命名文章' : firstLine;
  }

  /// 保存一次分析。同指纹旧记录会被覆盖（刷新结果与时间，不产生重复）。
  Future<int> save({
    required String article,
    required String questions,
    required String level,
    required AnalysisResult result,
  }) async {
    await _ensureOpen();
    final fp = fingerprintOf(article);
    return _db!.transaction<int>((txn) async {
      await txn.delete('history',
          where: 'fingerprint = ?', whereArgs: [fp]);
      return txn.insert('history', {
        'title': _makeTitle(article, result),
        'article': article,
        'questions': questions,
        'level': level,
        'result_json': jsonEncode(result.toJson()),
        'fingerprint': fp,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// 按指纹查找最近一次分析，没有返回 null
  Future<HistoryEntry?> findByFingerprint(String fingerprint) async {
    await _ensureOpen();
    final rows = await _db!.query(
      'history',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// 全部历史，按时间倒序
  Future<List<HistoryEntry>> listAll() async {
    await _ensureOpen();
    final rows =
        await _db!.query('history', orderBy: 'created_at DESC', limit: 500);
    return rows.map(_fromRow).toList();
  }

  Future<void> delete(int id) async {
    await _ensureOpen();
    await _db!.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    await _ensureOpen();
    await _db!.delete('history');
  }

  HistoryEntry _fromRow(Map<String, Object?> r) {
    final result = AnalysisResult.fromJson(
        Map<String, dynamic>.from(jsonDecode('${r['result_json']}') as Map));
    return HistoryEntry(
      id: r['id'] as int,
      title: '${r['title']}',
      article: '${r['article']}',
      questions: '${r['questions'] ?? ''}',
      level: '${r['level'] ?? 'auto'}',
      result: result,
      fingerprint: '${r['fingerprint']}',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    );
  }
}

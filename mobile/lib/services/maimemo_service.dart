import 'dart:convert';
import 'package:dio/dio.dart';
import 'settings_service.dart';

/// 墨墨背单词开放 API 封装（端点依据官方 OpenAPI 规范核实，base: https://open.maimemo.com/open）
/// 1) POST /api/v1/vocabulary/query       按拼写批量查内部单词 ID
/// 2) POST /api/v1/study/add_words        把单词加入学习规划
/// 3) GET  /api/v1/memo/notepads          查询云词本
/// 4) POST /api/v1/memo/notepads          创建云词本
/// 5) GET  /api/v1/memo/notepads/{id}     获取云词本（含 content）
/// 6) POST /api/v1/memo/notepads/{id}     更新云词本（全量 content 替换）
class MaimemoService {
  MaimemoService._();
  static final MaimemoService instance = MaimemoService._();

  static const _base = 'https://open.maimemo.com/open';

  /// 自动归档生词的云词本标题
  static const notepadTitle = '阅读精讲生词';
  static const notepadBrief = '由英语阅读精讲 App 自动归档的生词，按日期分章';
  // 墨墨云词本 tags 是服务端强校验的枚举，仅允许：
  // 小学/初中/高中/大学教科书/四级/六级/专四/专八/考研/新概念/SAT/托福/雅思/
  // GRE/GMAT/托业/BEC/词典/词频/其他，自定义值会返回 400。
  static const notepadTags = ['其他'];

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  Map<String, String> get _headers =>
      {'Authorization': 'Bearer ${SettingsService.instance.maimemoToken}'};

  /// 兼容响应包络：官方返回 {success, errors, data:{...}} 或直接业务对象
  Map<String, dynamic> _unwrap(Response resp) {
    final d = resp.data is Map ? Map<String, dynamic>.from(resp.data) : <String, dynamic>{};
    if (d['success'] == false) throw Exception('墨墨返回失败：${d['errors'] ?? d}');
    if (d['data'] is Map) return Map<String, dynamic>.from(d['data']);
    return d;
  }

  /// 把 DioException 转成带服务端错误详情的中文异常
  Never _throwFriendly(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? detail;
    if (data != null) {
      try {
        final m = data is Map
            ? Map<String, dynamic>.from(data)
            : jsonDecode('$data') as Map<String, dynamic>;
        final raw = m['errors'] ?? m['error'] ?? m['message'];
        if (raw != null && '$raw'.isNotEmpty) detail = '$raw';
      } catch (_) {}
    }
    detail ??= e.message ?? '网络请求失败，请检查网络';
    throw Exception('墨墨接口错误${code == null ? '' : '（HTTP $code）'}：$detail');
  }

  String _requireToken() {
    final token = SettingsService.instance.maimemoToken;
    if (token.isEmpty) throw Exception('尚未配置墨墨 Token，请到设置页填写');
    return token;
  }

  /// 规范化拼写并去重
  List<String> _normalize(List<String> spellings) =>
      spellings.map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty).toSet().toList();

  /// 拼写 -> 墨墨内部 ID（墨墨词库未收录的拼写不会出现在返回里）
  Future<Map<String, dynamic>> _resolveIds(List<String> spellings) async {
    _requireToken();
    final words = _normalize(spellings);
    try {
      final resp = await _dio.post(
        '/api/v1/vocabulary/query',
        data: {'spellings': words, 'ids': []},
        options: Options(headers: _headers),
      );
      final data = _unwrap(resp);
      final vocList = (data['voc'] ?? []) as List;
      final Map<String, String> idBySpelling = {
        for (final v in vocList) '${v['spelling']}'.toLowerCase(): '${v['id']}'
      };
      final missing = words.where((w) => !idBySpelling.containsKey(w)).toList();
      return {'idBySpelling': idBySpelling, 'missing': missing};
    } on DioException catch (e) {
      _throwFriendly(e);
    }
  }

  /// 把若干单词加入「学习规划」。
  Future<AddWordsResult> addToStudyPlan(List<String> spellings) async {
    final resolved = await _resolveIds(spellings);
    final Map<String, String> idBySpelling = resolved['idBySpelling'];
    final List<String> missing = resolved['missing'];
    final ids = idBySpelling.values.toList();
    if (ids.isEmpty) return AddWordsResult(addedCount: 0, missing: missing);

    try {
      final resp = await _dio.post(
        '/api/v1/study/add_words',
        data: {
          'words': ids.map((id) => {'id': id}).toList(),
          'advance': false,
        },
        options: Options(headers: _headers),
      );
      final data = _unwrap(resp);
      return AddWordsResult(
        addedCount: (data['added_count'] as num?)?.toInt() ?? ids.length,
        missing: missing,
      );
    } on DioException catch (e) {
      _throwFriendly(e);
    }
  }

  /// 把单词归档到「阅读精讲生词」云词本（按日期分章，词本不存在则自动创建）。
  /// 返回实际新增到词本的单词列表（已在词本中的不重复添加）。
  Future<ArchiveResult> archiveToNotepad(List<String> spellings) async {
    final resolved = await _resolveIds(spellings);
    final Map<String, String> idBySpelling = resolved['idBySpelling'];
    final List<String> missing = resolved['missing'];
    // 只归档墨墨词库收录的词，避免云词本里混入无法识别的拼写
    final words = idBySpelling.keys.toList();
    if (words.isEmpty) return ArchiveResult(archived: const [], missing: missing);

    final chapter = _today();
    try {
      // 1. 查找已有词本（墨墨接口 limit 上限为 10，需翻页查找）
      Map<String, dynamic>? existing;
      var offset = 0;
      const pageSize = 10;
      while (existing == null && offset < 100) {
        final listResp = await _dio.get(
          '/api/v1/memo/notepads',
          queryParameters: {'limit': pageSize, 'offset': offset},
          options: Options(headers: _headers),
        );
        final listData = _unwrap(listResp);
        final notepads = (listData['notepads'] ?? []) as List;
        for (final n in notepads) {
          if ('${n['title']}' == notepadTitle) {
            existing = Map<String, dynamic>.from(n);
            break;
          }
        }
        if (notepads.length < pageSize) break; // 已到最后一页
        offset += pageSize;
      }

      if (existing == null) {
        // 2a. 词本不存在：创建（章节模式：# 章节名，下方一行一个单词）
        final content = '# $chapter\n${words.join('\n')}\n';
        final resp = await _dio.post(
          '/api/v1/memo/notepads',
          data: {
            'notepad': {
              'status': 'PUBLISHED',
              'content': content,
              'title': notepadTitle,
              'brief': notepadBrief,
              'tags': notepadTags,
            }
          },
          options: Options(headers: _headers),
        );
        _unwrap(resp);
        return ArchiveResult(archived: words, missing: missing, isNewNotepad: true);
      }

      // 2b. 词本已存在：取完整 content（列表接口不含 content）
      final id = '${existing['id']}';
      final detailResp = await _dio.get(
        '/api/v1/memo/notepads/$id',
        options: Options(headers: _headers),
      );
      final detailData = _unwrap(detailResp);
      final notepad = Map<String, dynamic>.from(detailData['notepad'] as Map);
      final oldContent = '${notepad['content'] ?? ''}';

      final merged = _appendToChapter(oldContent, chapter, words);
      if (merged.added.isEmpty) {
        return ArchiveResult(archived: const [], missing: missing, duplicated: true);
      }

      // 更新接口要求全量字段，保留词本原有的标题/简介/标签/状态
      await _dio.post(
        '/api/v1/memo/notepads/$id',
        data: {
          'id': id,
          'notepad': {
            'status': '${notepad['status'] ?? 'PUBLISHED'}',
            'content': merged.content,
            'title': '${notepad['title'] ?? notepadTitle}',
            'brief': '${notepad['brief'] ?? notepadBrief}',
            'tags': (notepad['tags'] as List?)?.map((e) => '$e').toList() ?? notepadTags,
          }
        },
        options: Options(headers: _headers),
      );
      return ArchiveResult(archived: merged.added, missing: missing);
    } on DioException catch (e) {
      _throwFriendly(e);
    }
  }

  /// 把单词追加到云词本 content 的指定日期章节（章节模式：# 章节名，下方一行一个单词）
  _MergedNotepad _appendToChapter(String content, String chapter, List<String> words) {
    final lines = content.split('\n');
    final lowerWords = words.map((w) => w.toLowerCase()).toList();

    int? chapterStart;
    int chapterEnd = lines.length; // 章节结束位置（下一个 # 行或文件末尾）
    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.startsWith('#')) {
        if (chapterStart != null) {
          chapterEnd = i;
          break;
        }
        if (t == '# $chapter' || t == '#$chapter') chapterStart = i;
      }
    }

    final Set<String> existingWords = {};
    if (chapterStart != null) {
      for (int i = chapterStart + 1; i < chapterEnd; i++) {
        final t = lines[i].trim().toLowerCase();
        if (t.isNotEmpty && !t.startsWith('#')) existingWords.add(t);
      }
    }

    final added = lowerWords.where((w) => !existingWords.contains(w)).toList();
    if (added.isEmpty) return _MergedNotepad(content, const []);

    if (chapterStart == null) {
      // 当天章节不存在：文末新建章节
      var prefix = content;
      if (prefix.isNotEmpty && !prefix.endsWith('\n')) prefix += '\n';
      if (prefix.isNotEmpty) prefix += '\n';
      return _MergedNotepad('$prefix# $chapter\n${added.join('\n')}\n', added);
    }

    // 插入到当天章节末尾（下一个章节之前）
    lines.insertAll(chapterEnd, added);
    return _MergedNotepad(lines.join('\n'), added);
  }

  String _today() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}

class AddWordsResult {
  final int addedCount;
  final List<String> missing;
  AddWordsResult({required this.addedCount, required this.missing});
}

class ArchiveResult {
  /// 本次新增到云词本的单词
  final List<String> archived;
  /// 墨墨词库未收录、无法处理的拼写
  final List<String> missing;
  /// 是否新建了词本
  final bool isNewNotepad;
  /// 是否因词本已含这些词而没有新增
  final bool duplicated;
  ArchiveResult({
    required this.archived,
    required this.missing,
    this.isNewNotepad = false,
    this.duplicated = false,
  });
}

class _MergedNotepad {
  final String content;
  final List<String> added;
  _MergedNotepad(this.content, this.added);
}

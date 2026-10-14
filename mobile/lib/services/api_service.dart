import 'package:dio/dio.dart';
import '../models/analysis_result.dart';
import 'settings_service.dart';

/// 与本机 FastAPI 后端通信
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 180)));

  Future<AnalysisResult> analyze({
    required String article,
    required String questions,
    required String level,
  }) async {
    final base = SettingsService.instance.backendUrl;
    final resp = await _dio.post(
      '$base/api/analyze',
      data: {'article': article, 'questions': questions, 'level': level},
    );
    if (resp.statusCode != 200) {
      throw Exception('后端返回异常：${resp.statusCode} ${resp.data}');
    }
    return AnalysisResult.fromJson(Map<String, dynamic>.from(resp.data));
  }

  Future<bool> health() async {
    try {
      final resp = await _dio
          .get('${SettingsService.instance.backendUrl}/api/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 云端全量词库查词（本地词库未命中时由 DictService 回退调用）。
  /// 返回原始字段 Map；查不到或网络异常返回 null。
  Future<Map<String, dynamic>?> lookupCloud(String word) async {
    try {
      final resp = await _dio.get(
        '${SettingsService.instance.backendUrl}/api/dict/${Uri.encodeComponent(word)}',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      if (resp.statusCode != 200) return null;
      final d = Map<String, dynamic>.from(resp.data);
      if (d['found'] == false) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  /// 悬浮球随身问答：question 为本次问题，history 为最近的对话（role/content）。
  Future<String> askTutor(
    String question,
    List<Map<String, String>> history,
  ) async {
    final base = SettingsService.instance.backendUrl;
    final resp = await _dio.post(
      '$base/api/chat/ask',
      data: {
        'question': question,
        'history': history
            .map((e) => {'role': e['role'], 'content': e['content']})
            .toList(),
      },
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    if (resp.statusCode != 200) {
      throw Exception('问答接口异常：${resp.statusCode} ${resp.data}');
    }
    return '${resp.data['answer'] ?? ''}';
  }
}

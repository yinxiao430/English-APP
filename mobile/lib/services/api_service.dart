import 'package:dio/dio.dart';
import '../models/analysis_result.dart';
import 'settings_service.dart';

/// 与本机 FastAPI 后端通信
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120)));

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
}

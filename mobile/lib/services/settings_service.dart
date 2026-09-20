import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 全局配置：后端地址用普通偏好存储，墨墨 Token 属于敏感凭证，走加密存储。
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kBackend = 'backend_base_url';
  static const _kLevel = 'level';
  static const _kMaimemoToken = 'maimemo_token';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String backendUrl = 'http://192.168.1.100:8000'; // 首次使用请在设置页改成你电脑的局域网 IP
  String level = 'auto';
  String maimemoToken = '';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    backendUrl = sp.getString(_kBackend) ?? backendUrl;
    level = sp.getString(_kLevel) ?? level;
    maimemoToken = (await _secure.read(key: _kMaimemoToken)) ?? '';
  }

  Future<void> saveBackend(String url) async {
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kBackend, backendUrl);
  }

  Future<void> saveLevel(String v) async {
    level = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLevel, v);
  }

  Future<void> saveMaimemoToken(String token) async {
    maimemoToken = token.trim();
    await _secure.write(key: _kMaimemoToken, value: maimemoToken);
  }
}

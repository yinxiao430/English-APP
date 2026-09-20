import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _backendCtrl;
  late final TextEditingController _tokenCtrl;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _backendCtrl = TextEditingController(text: s.backendUrl);
    _tokenCtrl = TextEditingController(text: s.maimemoToken);
  }

  Future<void> _save() async {
    await SettingsService.instance.saveBackend(_backendCtrl.text);
    await SettingsService.instance.saveMaimemoToken(_tokenCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.pop(context);
    }
  }

  Future<void> _testBackend() async {
    await SettingsService.instance.saveBackend(_backendCtrl.text);
    final ok = await ApiService.instance.health();
    setState(() => _testResult = ok ? '✅ 后端连接正常' : '❌ 连不上后端，请确认地址与后端是否启动');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('后端地址（电脑的局域网 IP）',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _backendCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://192.168.x.x:8000',
              helperText: '手机和电脑连同一个 WiFi；后端启动时会打印这个地址',
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _testBackend,
              icon: const Icon(Icons.wifi_find_rounded, size: 19),
              label: const Text('测试连接'),
            ),
            const SizedBox(width: 12),
            Text(_testResult, style: const TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 24),
          const Text('墨墨背单词开放 API Token',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '粘贴墨墨开放 API Token',
              helperText: '获取路径：墨墨 App → 我的 → 更多设置 → 实验功能 → 开放 API',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
  }
}

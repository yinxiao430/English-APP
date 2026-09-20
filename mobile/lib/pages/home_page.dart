import 'package:flutter/material.dart';
import 'ocr_confirm_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('英语阅读精讲'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, size: 72, color: Color(0xFF3B5BDB)),
            const SizedBox(height: 16),
            const Text('拍下英语阅读，逐句精讲 + 生词同步墨墨',
                style: TextStyle(fontSize: 15, color: Colors.black54)),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('拍照分析'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              onPressed: () => _go(context, true),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('从相册选择'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              onPressed: () => _go(context, false),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, bool fromCamera) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OcrConfirmPage(fromCamera: fromCamera)),
    );
  }
}

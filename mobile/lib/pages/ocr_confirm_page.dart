import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import 'result_page.dart';

/// 选图 → OCR → 人工校对（文章区/题目区）→ 提交后端分析
class OcrConfirmPage extends StatefulWidget {
  final bool fromCamera;
  const OcrConfirmPage({super.key, required this.fromCamera});

  @override
  State<OcrConfirmPage> createState() => _OcrConfirmPageState();
}

class _OcrConfirmPageState extends State<OcrConfirmPage> {
  final _articleCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  String? _imagePath;
  bool _recognizing = true;
  bool _analyzing = false;
  late String _level;

  static const _levels = {
    'auto': '自动判断',
    'gaokao': '高考',
    'cet4': '四级',
    'cet6': '六级',
    'postgraduate': '考研',
  };

  @override
  void initState() {
    super.initState();
    _level = SettingsService.instance.level;
    _runOcr();
  }

  Future<void> _runOcr() async {
    setState(() => _recognizing = true);
    final r = await OcrService.instance.pickAndRecognize(fromCamera: widget.fromCamera);
    if (!mounted) return;
    if (r == null) {
      Navigator.pop(context); // 用户取消选图
      return;
    }
    setState(() {
      _imagePath = r.imagePath;
      _articleCtrl.text = r.text;
      _recognizing = false;
    });
  }

  Future<void> _analyze() async {
    if (_articleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文章内容为空，请先识别或粘贴文章')));
      return;
    }
    setState(() => _analyzing = true);
    try {
      final result = await ApiService.instance.analyze(
        article: _articleCtrl.text,
        questions: _questionCtrl.text,
        level: _level,
      );
      await SettingsService.instance.saveLevel(_level);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(result: result)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('分析失败：$e\n请确认后端已启动、设置页地址正确')));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('识别与校对')),
      body: _recognizing
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('正在识别图片文字…'),
              ],
            ))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_imagePath!),
                        height: 160, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 8),
                Text('请校对识别结果（OCR 难免有错，改完再分析效果最好）',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                const SizedBox(height: 12),
                const Text('① 文章正文', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _articleCtrl,
                  maxLines: 10,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '识别出的文章会出现在这里，可手动修改',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('② 题目（没有可留空）', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _questionCtrl,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '题干和选项，可留空',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('难度：'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _level,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(), isDense: true),
                        items: [
                          for (final e in _levels.entries)
                            DropdownMenuItem(value: e.key, child: Text(e.value))
                        ],
                        onChanged: (v) => setState(() => _level = v ?? 'auto'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_analyzing ? 'AI 精讲中，约 10-30 秒…' : '开始 AI 精讲'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _runOcr,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新选图识别'),
                ),
              ],
            ),
    );
  }
}

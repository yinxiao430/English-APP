import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import 'result_page.dart';

/// 单页图片及其 OCR 状态
class _PageItem {
  final String path;
  String text;
  bool recognizing;
  bool failed;
  _PageItem(this.path)
      : text = '',
        recognizing = true,
        failed = false;
}

/// 选图（支持多页）→ 逐页 OCR → 人工校对（文章区/题目区）→ 提交后端分析
class OcrConfirmPage extends StatefulWidget {
  final bool fromCamera;
  const OcrConfirmPage({super.key, required this.fromCamera});

  @override
  State<OcrConfirmPage> createState() => _OcrConfirmPageState();
}

class _OcrConfirmPageState extends State<OcrConfirmPage> {
  final _articleCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final List<_PageItem> _pages = [];

  /// 首次打开选择器/识别整页 loading；之后的追加只显示单页遮罩
  bool _initializing = true;
  bool _analyzing = false;
  bool _userEditedArticle = false;
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
    _initialPick();
  }

  @override
  void dispose() {
    _articleCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  bool get _anyRecognizing => _pages.any((p) => p.recognizing);

  // ---------------------------------------------------------------- 选图/识别

  /// 进入页面后的首次采集：相机拍第一张，相册允许多选
  Future<void> _initialPick() async {
    setState(() => _initializing = true);
    if (widget.fromCamera) {
      await _addCameraPage();
    } else {
      await _addGalleryPages();
    }
    if (!mounted) return;
    setState(() => _initializing = false);
    if (_pages.isEmpty) Navigator.pop(context); // 用户首次即取消
  }

  Future<void> _addCameraPage() async {
    final file = await OcrService.instance.takePhoto();
    if (file == null) return;
    final item = _PageItem(file.path);
    setState(() => _pages.add(item));
    await _recognize(item);
    _notifyEditedPreserved();
  }

  Future<void> _addGalleryPages() async {
    final files = await OcrService.instance.pickGalleryImages();
    if (files == null || files.isEmpty) return;
    final added = files.map((f) => _PageItem(f.path)).toList();
    setState(() => _pages.addAll(added));
    // 串行识别，避免同一 TextRecognizer 并发
    for (final item in added) {
      await _recognize(item);
    }
    _notifyEditedPreserved();
  }

  Future<void> _recognize(_PageItem item) async {
    try {
      final text = await OcrService.instance.recognizePath(item.path);
      item.text = text;
      item.recognizing = false;
      item.failed = false;
    } catch (_) {
      item.recognizing = false;
      item.failed = true;
    }
    if (!mounted) return;
    setState(() {});
    _rebuildArticle(overwriteEdited: false);
  }

  // ---------------------------------------------------------------- 文本合并

  /// 根据各页 OCR 文本重新合并正文。
  /// [overwriteEdited]=false 时，若用户已手动校对，则保留其内容不覆盖，
  /// 由用户点击「重新合并」按钮主动刷新。
  void _rebuildArticle({required bool overwriteEdited}) {
    if (_userEditedArticle && !overwriteEdited) return;
    final merged =
        OcrService.mergePageTexts(_pages.map((p) => p.text).toList());
    _articleCtrl.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: merged.length),
    );
    _userEditedArticle = false;
  }

  /// 追加页识别完成后，若正文已被手动校对，提示一次
  void _notifyEditedPreserved() {
    if (!_userEditedArticle) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('新页面已识别，你校对过的正文被保留；点「重新合并」可加入新页'),
          duration: Duration(seconds: 3),
        ));
      }
    });
  }

  /// 图片结构变化（删除/排序/手动重新合并）前，若用户已校对，先确认覆盖
  Future<bool> _confirmStructureChange(String action) async {
    if (!_userEditedArticle) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提示'),
        content: Text('$action后需要按页序重新合并正文，会覆盖你手动校对的内容，是否继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('重新合并')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _removePage(int index) async {
    if (!await _confirmStructureChange('删除该页')) return;
    setState(() => _pages.removeAt(index));
    _rebuildArticle(overwriteEdited: true);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!await _confirmStructureChange('调整页序')) return;
    setState(() {
      // onReorderItem 已按移除旧位置后的列表修正 newIndex，无需再 -1
      final p = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, p);
    });
    _rebuildArticle(overwriteEdited: true);
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空重来？'),
        content: const Text('将清空全部页面图片、识别结果和校对内容，并重新选择。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清空并重选')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _pages.clear();
      _articleCtrl.clear();
      _questionCtrl.clear();
      _userEditedArticle = false;
    });
    await _initialPick();
  }

  // ---------------------------------------------------------------- 提交分析

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  /// 历史查重。返回 true 表示继续（重新）分析，false 表示已打开历史记录。
  Future<bool> _checkDuplicate() async {
    final existing = await HistoryService.instance
        .findByFingerprint(HistoryService.fingerprintOf(_articleCtrl.text));
    if (existing == null || !mounted) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('这篇文章已经分析过'),
        content: Text(
            '「${existing.title}」\n分析时间：${_fmtTime(existing.createdAt)}\n\n可直接打开历史精讲，或选择重新分析（会刷新该记录）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'reanalyze'),
              child: const Text('仍重新分析')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'open'),
              child: const Text('打开历史')),
        ],
      ),
    );
    if (choice == 'open') {
      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(result: existing.result)),
      );
      return false;
    }
    return true;
  }

  Future<void> _analyze() async {
    if (_anyRecognizing) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还有页面正在识别，请稍候…')));
      return;
    }
    if (_articleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文章内容为空，请先识别或粘贴文章')));
      return;
    }
    if (!await _checkDuplicate()) return;
    setState(() => _analyzing = true);
    try {
      final result = await ApiService.instance.analyze(
        article: _articleCtrl.text,
        questions: _questionCtrl.text,
        level: _level,
      );
      await SettingsService.instance.saveLevel(_level);
      // 存档失败不应影响查看精讲结果
      try {
        await HistoryService.instance.save(
          article: _articleCtrl.text,
          questions: _questionCtrl.text,
          level: _level,
          result: result,
        );
      } catch (_) {}
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

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('识别与校对'),
        actions: [
          IconButton(
            tooltip: '清空重来',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _initializing || _analyzing ? null : _restart,
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('正在选择图片并识别文字…'),
              ],
            ))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPageStrip(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _analyzing || _anyRecognizing
                            ? null
                            : _addCameraPage,
                        icon: const Icon(Icons.photo_camera_outlined, size: 19),
                        label: const Text('拍一页'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _analyzing || _anyRecognizing
                            ? null
                            : _addGalleryPages,
                        icon: const Icon(Icons.photo_library_outlined, size: 19),
                        label: const Text('相册追加'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _analyzing || _anyRecognizing
                            ? null
                            : () async {
                                if (await _confirmStructureChange('重新合并')) {
                                  _rebuildArticle(overwriteEdited: true);
                                }
                              },
                        icon: const Icon(Icons.merge_type_rounded, size: 19),
                        label: const Text('重新合并'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('共 ${_pages.length} 页，长按缩略图可拖动排序；文章跨页时请按页序排列',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 12),
                Text('请校对识别结果（OCR 难免有错，改完再分析效果最好）',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                const SizedBox(height: 12),
                const Text('① 文章正文', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _articleCtrl,
                  maxLines: 10,
                  onChanged: (_) => _userEditedArticle = true,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '各页识别结果会按页序合并在这里，可手动修改',
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
                  onPressed: _analyzing || _anyRecognizing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_anyRecognizing
                      ? '页面识别中…'
                      : _analyzing
                          ? 'AI 精讲中，约 10-30 秒…'
                          : '开始 AI 精讲'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ),
    );
  }

  /// 多页缩略图横条：页码、识别状态、删除，长按拖拽排序
  Widget _buildPageStrip() {
    return SizedBox(
      height: 128,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        onReorderItem: _onReorder,
        buildDefaultDragHandles: false,
        children: [
          for (var i = 0; i < _pages.length; i++)
            ReorderableDelayedDragStartListener(
              key: ValueKey('page-$i-${_pages[i].path}'),
              index: i,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_pages[i].path),
                        width: 100,
                        height: 128,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('P${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _removePage(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    if (_pages[i].recognizing)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.black38,
                            child: const Center(
                                child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5))),
                          ),
                        ),
                      ),
                    if (_pages[i].failed)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pages[i].recognizing = true;
                              _pages[i].failed = false;
                            });
                            _recognize(_pages[i]);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: Colors.black54,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh,
                                      color: Colors.white, size: 26),
                                  SizedBox(height: 4),
                                  Text('识别失败\n点击重试',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

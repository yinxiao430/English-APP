import 'package:flutter/material.dart';
import '../services/dict_service.dart';
import '../services/tts_service.dart';
import '../services/maimemo_service.dart';

/// 点击单词后弹出的底部卡片：音标、释义、发音、加入墨墨
class WordSheet extends StatefulWidget {
  final String word;
  const WordSheet({super.key, required this.word});

  static Future<void> show(BuildContext context, String word) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => WordSheet(word: word),
    );
  }

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  DictEntry? _entry;
  bool _loading = true;
  bool _adding = false;
  String? _tip;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await DictService.instance.lookup(widget.word);
    if (mounted) {
      setState(() {
        _entry = e;
        _loading = false;
      });
    }
  }

  Future<void> _addToMaimemo() async {
    setState(() {
      _adding = true;
      _tip = null;
    });
    final svc = MaimemoService.instance;
    final tips = <String>[];
    // 1. 加入今日学习规划
    try {
      final r = await svc.addToStudyPlan([widget.word]);
      if (r.addedCount > 0) {
        tips.add('已加入墨墨今日学习规划');
      } else if (r.missing.isNotEmpty) {
        tips.add('墨墨词库未收录「${r.missing.join(', ')}」');
      }
    } catch (e) {
      tips.add('加入学习规划失败：$e');
    }
    // 2. 归档到「阅读精讲生词」云词本（失败不影响第 1 步结果）
    try {
      final a = await svc.archiveToNotepad([widget.word]);
      if (a.archived.isNotEmpty) {
        tips.add(a.isNewNotepad
            ? '已创建云词本「${MaimemoService.notepadTitle}」并归档'
            : '已归档到云词本「${MaimemoService.notepadTitle}」');
      } else if (a.duplicated) {
        tips.add('该词已在云词本「${MaimemoService.notepadTitle}」中');
      }
    } catch (e) {
      tips.add('云词本归档失败：$e');
    }
    if (mounted) {
      setState(() {
        _tip = tips.isEmpty ? '操作完成' : tips.join('；');
        _adding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(w,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded),
                tooltip: '发音',
                onPressed: () => TtsService.instance.speak(w),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entry == null)
            const Text('本地词典未收录该词（可能是超纲词或专有名词）',
                style: TextStyle(color: Colors.black54))
          else ...[
            if (_entry!.phonetic.isNotEmpty)
              Text('/${_entry!.phonetic}/',
                  style: const TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              _entry!.translation.replaceAll('\n', '\n'),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _adding ? null : _addToMaimemo,
                icon: _adding
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bookmark_add_rounded, size: 19),
                label: const Text('加入墨墨背单词'),
              ),
              const SizedBox(width: 12),
              if (_tip != null)
                Expanded(
                  child: Text(_tip!,
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

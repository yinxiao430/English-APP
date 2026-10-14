import 'package:flutter/material.dart';
import '../services/dict_service.dart';
import '../services/tts_service.dart';
import '../services/maimemo_service.dart';
import '../services/studied_service.dart';

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
    var studyOk = false;
    try {
      final r = await svc.addToStudyPlan([widget.word]);
      if (r.addedCount > 0) {
        tips.add('已加入墨墨今日学习规划');
        studyOk = true;
      } else if (r.missing.isNotEmpty) {
        tips.add('墨墨词库未收录「${r.missing.join(', ')}」');
      }
    } catch (e) {
      tips.add('加入学习规划失败：$e');
    }
    // 加入成功：记录到本地“已学集合”，原文中该词立即标黄
    if (studyOk) {
      await StudiedService.instance.markAll([widget.word]);
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
    final alreadyStudied = StudiedService.instance.contains(w);
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
              if (alreadyStudied)
                const Tooltip(
                  message: '已加入墨墨背单词',
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFFE6A700)),
                ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded),
                tooltip: '发音',
                onPressed: () => TtsService.instance.speak(w),
              ),
            ],
          ),
          // 词库来源标记
          if (!_loading && _entry != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              _SourceChip(
                label: _entry!.source == 'cloud' ? '云端词库' : '本地词库',
                cloud: _entry!.source == 'cloud',
              ),
              if (alreadyStudied) ...[
                const SizedBox(width: 8),
                const _SourceChip(label: '已在墨墨学习', cloud: false, highlight: true),
              ],
            ]),
          ],
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entry == null)
            const Text('本地与云端词库均未收录该词（可能是超纲词或专有名词）',
                style: TextStyle(color: Colors.black54))
          else ...[
            if (_entry!.phonetic.isNotEmpty)
              Text('/${_entry!.phonetic}/',
                  style: const TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              _entry!.translation,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                onPressed: (_adding || alreadyStudied) ? null : _addToMaimemo,
                icon: _adding
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bookmark_add_rounded, size: 19),
                label: Text(alreadyStudied ? '已加入墨墨' : '加入墨墨背单词'),
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

class _SourceChip extends StatelessWidget {
  final String label;
  final bool cloud;
  final bool highlight;
  const _SourceChip(
      {required this.label, this.cloud = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? const Color(0xFFE6A700)
        : (cloud ? Colors.teal.shade700 : Colors.blueGrey.shade600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, color: color)),
    );
  }
}

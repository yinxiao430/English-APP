import 'package:flutter/material.dart';
import '../services/history_service.dart';
import 'result_page.dart';

/// 精讲历史：回看、左滑删除、清空
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await HistoryService.instance.listAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<bool?> _confirmDelete(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
  }

  Future<void> _deleteOne(HistoryEntry e) async {
    await HistoryService.instance.delete(e.id);
    if (!mounted) return;
    setState(() => _items.removeWhere((x) => x.id == e.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除「${e.title}」')));
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) return;
    final ok = await _confirmDelete('将清空全部 ${_items.length} 条历史记录，且不可恢复。');
    if (ok != true) return;
    await HistoryService.instance.clear();
    if (!mounted) return;
    setState(() => _items = []);
  }

  void _open(HistoryEntry e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultPage(result: e.result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            tooltip: '清空全部',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _loading || _items.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('还没有分析过的文章',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      const Text('拍照精讲后会自动存档到这里',
                          style: TextStyle(fontSize: 12.5, color: Colors.black38)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      return Dismissible(
                        key: ValueKey('history-${e.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) =>
                            _confirmDelete('删除「${e.title}」的历史记录？'),
                        onDismissed: (_) => _deleteOne(e),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            title: Text(e.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.result.sentences.length} 句精讲 · '
                                    '${e.result.questions.length} 道题 · '
                                    '${e.result.keyVocab.length} 个词汇',
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_fmtTime(e.createdAt),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _open(e),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

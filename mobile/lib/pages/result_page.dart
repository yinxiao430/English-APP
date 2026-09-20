import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../widgets/tokenized_sentence.dart';
import '../widgets/word_sheet.dart';
import '../services/maimemo_service.dart';

class ResultPage extends StatelessWidget {
  final AnalysisResult result;
  const ResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('精讲结果'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '题目讲解'),
              Tab(text: '逐句精读'),
              Tab(text: '全文与词汇'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QuestionsTab(result: result),
            _SentencesTab(result: result),
            _SummaryTab(result: result),
          ],
        ),
      ),
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  final AnalysisResult result;
  const _QuestionsTab({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.questions.isEmpty) {
      return const Center(child: Text('本次没有识别到题目', style: TextStyle(color: Colors.black54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        final q = result.questions[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${q.id}. ${q.stem}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, height: 1.4)),
                const SizedBox(height: 8),
                for (final e in q.options.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${e.key}. ${e.value}',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: e.key == q.answer ? Colors.green.shade800 : null,
                          fontWeight: e.key == q.answer ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                const Divider(height: 22),
                Row(children: [
                  const Text('正确答案：', style: TextStyle(fontSize: 14)),
                  Text(q.answer,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
                if (q.evidence.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('定位依据：${q.evidence}',
                      style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.5)),
                ],
                const SizedBox(height: 8),
                Text('解析：${q.analysis}',
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SentencesTab extends StatelessWidget {
  final AnalysisResult result;
  const _SentencesTab({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.sentences.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final s = result.sentences[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TokenizedSentence(text: s.en),
                const SizedBox(height: 8),
                Text(s.zh, style: const TextStyle(fontSize: 14.5, height: 1.6, color: Colors.black87)),
                if (s.grammar.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final g in s.grammar)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                          children: [
                            TextSpan(
                                text: '【${g.point}】',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Color(0xFF2F4BA8))),
                            TextSpan(text: g.explain),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryTab extends StatefulWidget {
  final AnalysisResult result;
  const _SummaryTab({required this.result});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  bool _adding = false;

  Future<void> _addAll() async {
    final words = widget.result.keyVocab.map((e) => e.word).toList();
    if (words.isEmpty) return;
    setState(() => _adding = true);
    try {
      final r = await MaimemoService.instance.addToStudyPlan(words);
      if (!mounted) return;
      var msg = '已加入 ${r.addedCount} 个到墨墨';
      if (r.missing.isNotEmpty) msg += '；未收录：${r.missing.join(", ")}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('全文主旨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(r.summary, style: const TextStyle(fontSize: 15, height: 1.7)),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('重点词汇', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _adding ? null : _addAll,
              icon: const Icon(Icons.bookmark_added_rounded, size: 18),
              label: Text(_adding ? '添加中…' : '全部加入墨墨'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final v in r.keyVocab)
          Card(
            elevation: 0,
            child: ListTile(
              dense: true,
              title: Text(v.word, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${v.pos} ${v.meaning}'.trim()),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () async {
                try {
                  final res = await MaimemoService.instance.addToStudyPlan([v.word]);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res.addedCount > 0 ? '已加入墨墨：${v.word}'
                          : '墨墨未收录：${v.word}')));
                } catch (e) {
                  if (!context.mounted) return;
                  WordSheet.show(context, v.word);
                }
              },
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../widgets/tokenized_sentence.dart';
import '../widgets/word_sheet.dart';
import '../services/maimemo_service.dart';
import '../services/studied_service.dart';

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

// ================= 题目讲解 =================
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
      itemBuilder: (_, i) => _QuestionCard(q: result.questions[i]),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuestionUnit q;
  const _QuestionCard({required this.q});

  @override
  Widget build(BuildContext context) {
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
            // 题干（单词可点击查释义）
            TokenizedSentence(
              text: '${q.id}. ${q.stem}',
              copyOnLongPress: false,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  height: 1.4,
                  color: Colors.black),
            ),
            if (q.stemZh.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('翻译：${q.stemZh}',
                  style: const TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black54)),
            ],
            const SizedBox(height: 8),
            // 选项（可点词 + 中文翻译）
            for (final e in q.options.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.key}. ',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              color: e.key == q.answer
                                  ? Colors.green.shade800
                                  : Colors.black,
                              fontWeight: e.key == q.answer
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                        Expanded(
                          child: TokenizedSentence(
                            text: e.value,
                            copyOnLongPress: false,
                            wordColor: e.key == q.answer
                                ? Colors.green.shade800
                                : const Color(0xFF2F4BA8),
                            style: const TextStyle(fontSize: 14.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    if (q.optionsZh[e.key] != null &&
                        q.optionsZh[e.key]!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 2),
                        child: Text('${q.optionsZh[e.key]}',
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.4, color: Colors.black45)),
                      ),
                  ],
                ),
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
              const Text('定位依据：',
                  style: TextStyle(fontSize: 13.5, color: Colors.black87)),
              const SizedBox(height: 2),
              TokenizedSentence(
                text: q.evidence,
                copyOnLongPress: false,
                style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.5),
              ),
            ],
            const SizedBox(height: 8),
            Text('解析：${q.analysis}',
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

// ================= 逐句精读 =================
class _SentencesTab extends StatelessWidget {
  final AnalysisResult result;
  const _SentencesTab({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.sentences.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _SentenceCard(s: result.sentences[i]),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  final SentenceUnit s;
  const _SentenceCard({required this.s});

  @override
  Widget build(BuildContext context) {
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
            TokenizedSentence(text: s.en), // 点词查义 + 长按复制
            const SizedBox(height: 3),
            const Text('点词查释义，长按可复制',
                style: TextStyle(fontSize: 11, color: Colors.black38)),
            const SizedBox(height: 8),
            Text(s.zh, style: const TextStyle(fontSize: 14.5, height: 1.6, color: Colors.black87)),
            // 详细长难句拆解
            if (s.analysisDetail != null) ...[
              const SizedBox(height: 10),
              _AnalysisDetailCard(d: s.analysisDetail!),
            ],
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
  }
}

// ================= 长难句拆解卡 =================
class _AnalysisDetailCard extends StatelessWidget {
  final SentenceAnalysisDetail d;
  const _AnalysisDetailCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0D9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_tree_rounded, size: 17, color: Color(0xFFC98A00)),
            const SizedBox(width: 5),
            const Text('长难句拆解',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (d.type.isNotEmpty) _MiniTag(label: d.type),
            if (d.difficulty.isNotEmpty) ...[
              const SizedBox(width: 6),
              _MiniTag(label: d.difficulty, byDifficulty: true),
            ],
          ]),
          if (d.skeleton.isNotEmpty) ...[
            const SizedBox(height: 10),
            _blockLabel('句子主干'),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFEBD9AE)),
              ),
              child: Text(d.skeleton,
                  style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C4700))),
            ),
          ],
          if (d.components.isNotEmpty) ...[
            const SizedBox(height: 10),
            _blockLabel('成分拆解'),
            const SizedBox(height: 5),
            for (final c in d.components)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFEFE3C6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                        children: [
                          TextSpan(
                              text: c.segment,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: '   '),
                          TextSpan(
                              text: c.role,
                              style: const TextStyle(
                                  color: Color(0xFFB27400),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    if (c.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(c.note,
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
                      ),
                  ],
                ),
              ),
          ],
          if (d.clauses.isNotEmpty) ...[
            const SizedBox(height: 6),
            _blockLabel('从句分析'),
            const SizedBox(height: 5),
            for (final c in d.clauses)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFD4E0FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black87),
                        children: [
                          TextSpan(
                              text: '【${c.type}】',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: Color(0xFF2F4BA8))),
                          if (c.connector.isNotEmpty)
                            TextSpan(text: '  引导词：${c.connector}'),
                        ],
                      ),
                    ),
                    if (c.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(c.text,
                            style: const TextStyle(fontSize: 12.5, height: 1.4)),
                      ),
                    if (c.modifies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('功能：${c.modifies}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2F4BA8), height: 1.4)),
                      ),
                    if (c.explain.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(c.explain,
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
                      ),
                  ],
                ),
              ),
          ],
          if (d.steps.isNotEmpty) ...[
            const SizedBox(height: 6),
            _blockLabel('拆解步骤'),
            const SizedBox(height: 5),
            for (int i = 0; i < d.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${i + 1}. ${d.steps[i]}',
                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: Colors.black87)),
              ),
          ],
          if (d.translationTechnique.isNotEmpty) ...[
            const SizedBox(height: 6),
            _blockLabel('翻译技巧'),
            const SizedBox(height: 4),
            Text(d.translationTechnique,
                style: const TextStyle(fontSize: 12.5, height: 1.6, color: Colors.black87)),
          ],
        ],
      ),
    );
  }

  Widget _blockLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFB27400)));
}

class _MiniTag extends StatelessWidget {
  final String label;
  final bool byDifficulty;
  const _MiniTag({required this.label, this.byDifficulty = false});

  @override
  Widget build(BuildContext context) {
    Color c;
    if (byDifficulty) {
      c = label == '难'
          ? Colors.red.shade600
          : (label == '较难' ? Colors.orange.shade700 : Colors.green.shade700);
    } else {
      c = const Color(0xFFB27400);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: c)),
    );
  }
}

// ================= 全文与词汇 =================
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
      // 成功加入（未被判定为缺失）的单词记录标黄
      final okWords = words
          .where((w) => !r.missing.contains(w.toLowerCase()))
          .toList();
      if (okWords.isNotEmpty) await StudiedService.instance.markAll(okWords);
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
                    if (res.addedCount > 0) {
                      await StudiedService.instance.markAll([v.word]);
                    }
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

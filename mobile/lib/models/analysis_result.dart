// 后端 /api/analyze 返回结构对应的模型（手写 fromJson，无需代码生成）
class GrammarPoint {
  final String point;
  final String explain;
  GrammarPoint({required this.point, required this.explain});

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
        point: (j['point'] ?? '').toString(),
        explain: (j['explain'] ?? '').toString(),
      );
}

class SentenceUnit {
  final int seq;
  final String en;
  final String zh;
  final List<GrammarPoint> grammar;
  SentenceUnit({
    required this.seq,
    required this.en,
    required this.zh,
    required this.grammar,
  });

  factory SentenceUnit.fromJson(Map<String, dynamic> j) => SentenceUnit(
        seq: (j['seq'] is int) ? j['seq'] : int.tryParse('${j['seq']}') ?? 0,
        en: (j['en'] ?? '').toString(),
        zh: (j['zh'] ?? '').toString(),
        grammar: ((j['grammar'] ?? []) as List)
            .map((e) => GrammarPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class QuestionUnit {
  final int id;
  final String stem;
  final Map<String, String> options;
  final String answer;
  final String evidence;
  final String analysis;
  QuestionUnit({
    required this.id,
    required this.stem,
    required this.options,
    required this.answer,
    required this.evidence,
    required this.analysis,
  });

  factory QuestionUnit.fromJson(Map<String, dynamic> j) {
    final opts = <String, String>{};
    (j['options'] ?? {}).forEach((k, v) => opts['$k'] = '$v');
    return QuestionUnit(
      id: (j['id'] is int) ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      stem: (j['stem'] ?? '').toString(),
      options: opts,
      answer: (j['answer'] ?? '').toString(),
      evidence: (j['evidence'] ?? '').toString(),
      analysis: (j['analysis'] ?? '').toString(),
    );
  }
}

class KeyVocab {
  final String word;
  final String pos;
  final String meaning;
  KeyVocab({required this.word, required this.pos, required this.meaning});

  factory KeyVocab.fromJson(Map<String, dynamic> j) => KeyVocab(
        word: (j['word'] ?? '').toString(),
        pos: (j['pos'] ?? '').toString(),
        meaning: (j['meaning'] ?? '').toString(),
      );
}

class AnalysisResult {
  final String summary;
  final List<SentenceUnit> sentences;
  final List<QuestionUnit> questions;
  final List<KeyVocab> keyVocab;

  AnalysisResult({
    required this.summary,
    required this.sentences,
    required this.questions,
    required this.keyVocab,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) => AnalysisResult(
        summary: (j['summary'] ?? '').toString(),
        sentences: ((j['sentences'] ?? []) as List)
            .map((e) => SentenceUnit.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        questions: ((j['questions'] ?? []) as List)
            .map((e) => QuestionUnit.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        keyVocab: ((j['key_vocab'] ?? []) as List)
            .map((e) => KeyVocab.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

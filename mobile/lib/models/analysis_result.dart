// 后端 /api/analyze 返回结构对应的模型（手写 fromJson/toJson，无需代码生成）
class GrammarPoint {
  final String point;
  final String explain;
  GrammarPoint({required this.point, required this.explain});

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
        point: (j['point'] ?? '').toString(),
        explain: (j['explain'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'point': point, 'explain': explain};
}

class ComponentPart {
  final String segment;
  final String role;
  final String note;
  ComponentPart({required this.segment, required this.role, required this.note});

  factory ComponentPart.fromJson(Map<String, dynamic> j) => ComponentPart(
        segment: (j['segment'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() =>
      {'segment': segment, 'role': role, 'note': note};
}

class ClauseInfo {
  final String type;
  final String text;
  final String connector;
  final String modifies;
  final String explain;
  ClauseInfo({
    required this.type,
    required this.text,
    required this.connector,
    required this.modifies,
    required this.explain,
  });

  factory ClauseInfo.fromJson(Map<String, dynamic> j) => ClauseInfo(
        type: (j['type'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        connector: (j['connector'] ?? '').toString(),
        modifies: (j['modifies'] ?? '').toString(),
        explain: (j['explain'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        'connector': connector,
        'modifies': modifies,
        'explain': explain,
      };
}

class SentenceAnalysisDetail {
  final String type;
  final String difficulty;
  final String skeleton;
  final String translationTechnique;
  final List<ComponentPart> components;
  final List<ClauseInfo> clauses;
  final List<String> steps;
  SentenceAnalysisDetail({
    required this.type,
    required this.difficulty,
    required this.skeleton,
    required this.translationTechnique,
    required this.components,
    required this.clauses,
    required this.steps,
  });

  factory SentenceAnalysisDetail.fromJson(Map<String, dynamic> j) =>
      SentenceAnalysisDetail(
        type: (j['type'] ?? '').toString(),
        difficulty: (j['difficulty'] ?? '').toString(),
        skeleton: (j['skeleton'] ?? '').toString(),
        translationTechnique: (j['translation_technique'] ?? '').toString(),
        components: ((j['components'] ?? []) as List)
            .map((e) => ComponentPart.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        clauses: ((j['clauses'] ?? []) as List)
            .map((e) => ClauseInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        steps: ((j['steps'] ?? []) as List).map((e) => '$e').toList(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'difficulty': difficulty,
        'skeleton': skeleton,
        'translation_technique': translationTechnique,
        'components': components.map((e) => e.toJson()).toList(),
        'clauses': clauses.map((e) => e.toJson()).toList(),
        'steps': steps,
      };
}

class SentenceUnit {
  final int seq;
  final String en;
  final String zh;
  final List<GrammarPoint> grammar;
  final SentenceAnalysisDetail? analysisDetail;
  SentenceUnit({
    required this.seq,
    required this.en,
    required this.zh,
    required this.grammar,
    this.analysisDetail,
  });

  factory SentenceUnit.fromJson(Map<String, dynamic> j) => SentenceUnit(
        seq: (j['seq'] is int) ? j['seq'] : int.tryParse('${j['seq']}') ?? 0,
        en: (j['en'] ?? '').toString(),
        zh: (j['zh'] ?? '').toString(),
        grammar: ((j['grammar'] ?? []) as List)
            .map((e) => GrammarPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        analysisDetail: j['sentence_analysis'] is Map
            ? SentenceAnalysisDetail.fromJson(
                Map<String, dynamic>.from(j['sentence_analysis']))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'en': en,
        'zh': zh,
        'grammar': grammar.map((e) => e.toJson()).toList(),
        'sentence_analysis': analysisDetail?.toJson(),
      };
}

class QuestionUnit {
  final int id;
  final String stem;
  final Map<String, String> options;
  final String answer;
  final String evidence;
  final String analysis;
  final String stemZh;
  final Map<String, String> optionsZh;
  QuestionUnit({
    required this.id,
    required this.stem,
    required this.options,
    required this.answer,
    required this.evidence,
    required this.analysis,
    required this.stemZh,
    required this.optionsZh,
  });

  factory QuestionUnit.fromJson(Map<String, dynamic> j) {
    final opts = <String, String>{};
    (j['options'] ?? {}).forEach((k, v) => opts['$k'] = '$v');
    final optsZh = <String, String>{};
    (j['options_zh'] ?? {}).forEach((k, v) => optsZh['$k'] = '$v');
    return QuestionUnit(
      id: (j['id'] is int) ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      stem: (j['stem'] ?? '').toString(),
      options: opts,
      answer: (j['answer'] ?? '').toString(),
      evidence: (j['evidence'] ?? '').toString(),
      analysis: (j['analysis'] ?? '').toString(),
      stemZh: (j['stem_zh'] ?? '').toString(),
      optionsZh: optsZh,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stem': stem,
        'options': options,
        'answer': answer,
        'evidence': evidence,
        'analysis': analysis,
        'stem_zh': stemZh,
        'options_zh': optionsZh,
      };
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

  Map<String, dynamic> toJson() => {'word': word, 'pos': pos, 'meaning': meaning};
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

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'sentences': sentences.map((e) => e.toJson()).toList(),
        'questions': questions.map((e) => e.toJson()).toList(),
        'key_vocab': keyVocab.map((e) => e.toJson()).toList(),
      };
}

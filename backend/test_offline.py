# -*- coding: utf-8 -*-
"""离线自测：不调用豆包，只验证 JSON 提取与结构校验是否正常。
运行：python test_offline.py
"""
from app.llm import _extract_json
from app.schemas import AnalysisResult

MOCK = """下面是分析结果：
```json
{
  "summary": "本文介绍了远程办公的利弊。",
  "sentences": [
    {"seq": 1, "en": "Remote work has become common.", "zh": "远程办公已变得普遍。",
     "grammar": [{"point": "现在完成时", "explain": "has become 表示到目前为止已经发生的变化。"}]}
  ],
  "questions": [
    {"id": 1, "stem": "What is the passage mainly about?",
     "options": {"A": "Travel", "B": "Remote work"}, "answer": "B",
     "evidence": "Remote work has become common.",
     "analysis": "全文首句点明主题，故选 B；A 未提及。"}
  ],
  "key_vocab": [{"word": "remote", "pos": "adj.", "meaning": "远程的"}]
}
```
"""


def main():
    obj = _extract_json(MOCK)
    result = AnalysisResult.model_validate(obj)
    assert len(result.sentences) == 1
    assert result.questions[0].answer == "B"
    print("[OK] JSON 提取与结构校验通过")
    print("主旨：", result.summary)
    print("第1句翻译：", result.sentences[0].zh)
    print("语法点：", result.sentences[0].grammar[0].point)
    print("题目答案：", result.questions[0].answer)


if __name__ == "__main__":
    main()

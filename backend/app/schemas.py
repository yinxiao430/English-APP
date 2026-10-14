# -*- coding: utf-8 -*-
"""请求/响应的数据结构（Pydantic 负责校验大模型返回的 JSON）。"""
from typing import List, Optional

from pydantic import BaseModel, Field


class AnalyzeRequest(BaseModel):
    # OCR 后的英文文章正文
    article: str = Field(..., min_length=1, description="英文阅读原文")
    # OCR 后的题目（题干+选项），没有题目的纯文章场景可留空
    questions: Optional[str] = Field(default="", description="题目原文，可为空")
    # 难度档位：gaokao / cet4 / cet6 / postgraduate / auto
    level: Optional[str] = Field(default="auto", description="难度档位")


class GrammarPoint(BaseModel):
    point: str = Field(..., description="语法点名称，如 定语从句")
    explain: str = Field(..., description="该语法点在本句中的用法讲解，中文")


class ComponentPart(BaseModel):
    segment: str = Field(..., description="句子中的英文片段（尽量引用原文）")
    role: str = Field(..., description="句法成分：主语/谓语/宾语/表语/定语/状语/同位语等")
    note: str = Field(default="", description="对该成分的补充说明（词性、时态、修饰对象等）")


class ClauseInfo(BaseModel):
    type: str = Field(..., description="从句类型：定语从句/宾语从句/状语从句/同位语从句等")
    text: str = Field(default="", description="从句原文")
    connector: str = Field(default="", description="引导词/关系词，如 who/which/that/because/if")
    modifies: str = Field(default="", description="修饰对象或承担的句法功能，如 修饰先行词 study")
    explain: str = Field(default="", description="从句内部结构与用法的详细说明")


class SentenceAnalysis(BaseModel):
    """长难句的全面拆解信息。"""
    type: str = Field(default="", description="句型：简单句/并列句/主从复合句/并列复合句等")
    difficulty: str = Field(default="", description="难度评级：一般/较难/难")
    skeleton: str = Field(default="", description="句子主干：剔除修饰后的主谓宾核心，英文")
    components: List[ComponentPart] = Field(default_factory=list, description="逐片段成分标注")
    clauses: List[ClauseInfo] = Field(default_factory=list, description="所含从句的逐一分析")
    steps: List[str] = Field(default_factory=list, description="读者视角的拆解步骤")
    translation_technique: str = Field(default="", description="翻译技巧：语序、增删词、被动转主动等")


class SentenceUnit(BaseModel):
    seq: int = Field(..., description="句子序号，从 1 开始")
    en: str = Field(..., description="英文原句")
    zh: str = Field(..., description="整句中文翻译")
    grammar: List[GrammarPoint] = Field(default_factory=list, description="本句语法点")
    sentence_analysis: Optional[SentenceAnalysis] = Field(
        default=None, description="详细的长难句拆解")


class QuestionUnit(BaseModel):
    id: int = Field(..., description="题号，从 1 开始")
    stem: str = Field(default="", description="题干")
    options: dict = Field(default_factory=dict, description="选项，如 {'A':'...','B':'...'}")
    answer: str = Field(default="", description="正确答案，如 B")
    evidence: str = Field(default="", description="原文定位依据句（英文）")
    analysis: str = Field(..., description="中文解析：为什么对、其它选项为什么错")
    stem_zh: str = Field(default="", description="题干的中文翻译")
    options_zh: dict = Field(default_factory=dict,
                             description="各选项中文翻译，如 {'A':'...','B':'...'}")


class KeyVocab(BaseModel):
    word: str
    pos: str = Field(default="", description="词性，如 n. / v.")
    meaning: str = Field(default="", description="在本文语境中的中文含义")


class AnalysisResult(BaseModel):
    summary: str = Field(default="", description="全文主旨，2-3 句中文")
    sentences: List[SentenceUnit] = Field(default_factory=list)
    questions: List[QuestionUnit] = Field(default_factory=list)
    key_vocab: List[KeyVocab] = Field(default_factory=list)


# ===== 悬浮球问答 =====
class ChatMessage(BaseModel):
    role: str = Field(..., description="user 或 assistant")
    content: str = Field(..., description="消息内容")


class ChatAskRequest(BaseModel):
    question: str = Field(..., min_length=1, description="学生的问题")
    history: List[ChatMessage] = Field(default_factory=list, description="最近的对话历史")


class ChatAskResponse(BaseModel):
    answer: str


# ===== 云端词库回退查询 =====
class DictLookupResponse(BaseModel):
    found: bool = True
    source: str = "cloud"
    word: str
    phonetic: str = Field(default="", description="音标")
    translation: str = Field(default="", description="中文释义")
    pos: str = Field(default="", description="词性")

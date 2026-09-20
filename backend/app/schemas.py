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


class SentenceUnit(BaseModel):
    seq: int = Field(..., description="句子序号，从 1 开始")
    en: str = Field(..., description="英文原句")
    zh: str = Field(..., description="整句中文翻译")
    grammar: List[GrammarPoint] = Field(default_factory=list, description="本句语法点")


class QuestionUnit(BaseModel):
    id: int = Field(..., description="题号，从 1 开始")
    stem: str = Field(default="", description="题干")
    options: dict = Field(default_factory=dict, description="选项，如 {'A':'...','B':'...'}")
    answer: str = Field(default="", description="正确答案，如 B")
    evidence: str = Field(default="", description="原文定位依据句（英文）")
    analysis: str = Field(..., description="中文解析：为什么对、其它选项为什么错")


class KeyVocab(BaseModel):
    word: str
    pos: str = Field(default="", description="词性，如 n. / v.")
    meaning: str = Field(default="", description="在本文语境中的中文含义")


class AnalysisResult(BaseModel):
    summary: str = Field(default="", description="全文主旨，2-3 句中文")
    sentences: List[SentenceUnit] = Field(default_factory=list)
    questions: List[QuestionUnit] = Field(default_factory=list)
    key_vocab: List[KeyVocab] = Field(default_factory=list)

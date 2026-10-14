# -*- coding: utf-8 -*-
"""服务端 ECDICT 全量词库查询（约 340 万词条）。

App 端本地词库未命中时，通过 GET /api/dict/{word} 回退到这里查询。
sqlite3 为 Python 内置库，查询放到线程池执行，避免阻塞事件循环。
"""
import asyncio
import sqlite3
from typing import Optional

from . import config

_conn: Optional[sqlite3.Connection] = None


def _get_conn() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        conn = sqlite3.connect(config.DICT_DB_PATH, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        # 只读模式打开更安全；这里用 URI 声明
        _conn = conn
    return _conn


def _lemmatize(w: str) -> str:
    """简单词形还原兜底：复数/过去式/ing（与 App 端逻辑保持一致）。"""
    if w.endswith("ies") and len(w) > 4:
        return f"{w[:-3]}y"
    if w.endswith("es") and len(w) > 3:
        return w[:-2]
    if w.endswith("s") and len(w) > 2:
        return w[:-1]
    if w.endswith("ing") and len(w) > 5:
        return w[:-3]
    if w.endswith("ed") and len(w) > 4:
        return w[:-2]
    return w


def _query(word: str) -> Optional[dict]:
    import os
    if not os.path.exists(config.DICT_DB_PATH):
        return None
    conn = _get_conn()
    w = word.lower().strip()
    if not w:
        return None
    for cand in (w, _lemmatize(w)):
        row = conn.execute(
            "SELECT word, phonetic, translation, pos "
            "FROM dict WHERE word = ? LIMIT 1",
            (cand,),
        ).fetchone()
        if row:
            return {
                "word": row["word"],
                "phonetic": row["phonetic"] or "",
                "translation": row["translation"] or "",
                "pos": row["pos"] or "",
            }
    return None


async def lookup_word(word: str) -> Optional[dict]:
    """异步查词；查不到或词库文件缺失返回 None。"""
    loop = asyncio.get_running_loop()
    try:
        return await loop.run_in_executor(None, _query, word)
    except sqlite3.Error:
        return None

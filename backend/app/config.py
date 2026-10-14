# -*- coding: utf-8 -*-
"""读取 .env 配置。"""
import os
from dotenv import load_dotenv

load_dotenv()

ARK_API_KEY = os.getenv("ARK_API_KEY", "").strip()
ARK_MODEL = os.getenv("ARK_MODEL", "doubao-1-5-pro-32k-250115").strip()
ARK_BASE_URL = os.getenv("ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3").strip().rstrip("/")
APP_PORT = int(os.getenv("APP_PORT", "8000"))

# 服务端全量词库（ECDICT，约 340 万词条），供 App 本地词库未命中时回退
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DICT_DB_PATH = os.getenv(
    "DICT_DB_PATH",
    os.path.join(_BASE_DIR, "data", "ecdict_full.db"),
).strip()

# 单次请求模型输出 token 上限（分块后每块输出可控，8192 足够）
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "8192"))
# 逐句精讲每个分块包含的句子数（块越小越不容易截断）
SENTENCE_CHUNK_SIZE = int(os.getenv("SENTENCE_CHUNK_SIZE", "6"))

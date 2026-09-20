# 墨墨背单词开放 API 对接说明（已核实）

- 官方文档：https://open.maimemo.com
- Base URL：`https://open.maimemo.com/open`
- 认证：请求头 `Authorization: Bearer <Token>`
- Token 获取：墨墨背单词 App → 我的 → 更多设置 → 实验功能 → 开放 API
- 频控：10 秒 20 次 / 60 秒 40 次 / 5 小时 2000 次（背单词）；
  自建内容（释义/例句/助记）每天最多 600 条 —— 本项目只加单词、不自建内容，不受这条影响。

## 本项目用到的两个接口（端点依据官方 CLI 源码核实）

### 1. 按拼写批量查单词，拿到墨墨内部 ID

`POST /api/v1/vocabulary/query`

请求体：

```json
{ "spellings": ["apple", "banana"], "ids": [] }
```

返回（业务数据在 `data` 内，也可能直接平铺）：

```json
{ "data": { "voc": [ { "id": "v_xxx", "spelling": "apple" } ] } }
```

> 注意：**墨墨词库未收录的拼写不会出现在 voc 数组里**，据此判断 missing。
> 单个查询可用 `GET /api/v1/vocabulary?spelling=apple`。

### 2. 加入学习规划

`POST /api/v1/study/add_words`

请求体：

```json
{ "words": [ { "id": "v_xxx" } ], "advance": false }
```

返回：`{ "added_count": 1 }`。

## 代码位置

Flutter 端已在 `mobile/lib/services/maimemo_service.dart` 封装好：
`addToStudyPlan(List<String> 单词列表)`，自动完成「查 ID → 过滤未收录 → 加入规划」，
返回成功数和未收录词列表。Token 只保存在手机加密存储中，不经过你的后端。

## 备选：加到云词本（生词本）而不是当天学习规划

官方还提供 notepad 资源（list/get/create/update/delete），适合“先攒着、以后统一规划”。
需要时在开放 API 文档站搜索 NotepadService，按同样的 Bearer 方式调用即可，
可在 maimemo_service.dart 里再加一个方法，不影响现有流程。

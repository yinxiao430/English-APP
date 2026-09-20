# 英语阅读精讲 App（reading-tutor）

拍照上传英语阅读 → 端上 OCR 识别 → 豆包大模型逐句翻译/讲语法/讲题目 →
点单词查离线词典 → 一键把生词同步进**墨墨背单词**的学习规划。

## 当前进度（已在本机完成的部分）

- [x] 后端 FastAPI 工程：虚拟环境、依赖已装好，离线自测与真实启动均通过
- [x] Flutter SDK 已安装到 `D:\JAVA\flutter`（Gitee 镜像），用户级 PATH 与国内镜像环境变量已配置
- [x] Flutter 工程脚手架（android）已生成，依赖已拉取，`flutter analyze` 零问题、冒烟测试通过
- [x] Android 相机/网络权限、中文应用名已配置
- [ ] **你还需要做的两件事**：① 申请豆包 API Key；② 安装 Android SDK（装 Android Studio 最省心），否则无法编译到手机

## 目录结构

```
English APP/
├── backend/          # FastAPI 后端
│   ├── app/main.py       # POST /api/analyze、GET /api/health
│   ├── app/llm.py        # 豆包（火山方舟，OpenAI 兼容协议）调用 + JSON 修复重试
│   ├── app/prompts.py    # 精讲提示词（输出格式契约）
│   ├── app/schemas.py    # 返回结构与 Pydantic 校验
│   ├── .env.example      # 复制为 .env 后填豆包 API Key
│   ├── run.bat           # 一键装依赖/启动后端
│   └── test_offline.py   # 不耗 API 的离线自测
├── mobile/           # Flutter 手机端
│   ├── lib/pages/        # 首页、OCR校对页、结果页(3 Tab)、设置页
│   ├── lib/widgets/      # 点词弹窗、可点词句子
│   ├── lib/services/     # 后端调用、OCR、离线词典、墨墨API、TTS、配置
│   ├── lib/models/       # 精讲结果模型
│   ├── assets/dict/      # 放 ECDICT 离线词典（见该目录 README.txt）
│   ├── run.bat           # 一键编译运行到手机
│   └── build-apk.bat     # 一键打包 APK
└── docs/墨墨开放API对接说明.md
```

---

## 第一步：启动后端

1. 去[火山方舟控制台](https://console.volcengine.com/ark)申请 API Key，并创建一个豆包推理接入点
   （模型选 doubao-1.5-pro-32k 即可；把接入点 ID 或模型 ID 填进 .env 的 ARK_MODEL）。
2. 双击 `backend/run.bat`：首次会自动生成 `.env`，填好 `ARK_API_KEY`、`ARK_MODEL` 保存，再双击一次启动。
3. 启动后窗口会打印 `http://192.168.x.x:8000`，**把它填进手机 App 设置页**。
   手机和电脑连同一个 WiFi；Windows 防火墙弹窗请点“允许”。

## 第二步：安装 Android SDK（只需一次）

Flutter 本体已装好，但编译安卓还需要 Android SDK，二选一：

- **推荐**：安装 [Android Studio](https://developer.android.com/studio)，安装向导勾选 Android SDK、
  Android SDK Platform、Android Virtual Device；装完在本目录新开 PowerShell 执行
  `D:\JAVA\flutter\bin\flutter.bat doctor --android-licenses`，全部输入 y。
- 不想装 IDE 可只装 Android Command-line Tools + 用 sdkmanager 装 platform-tools / platforms;android-35 /
  build-tools，新手不建议。

> 已有一台安卓真机时无需模拟器：设置 → 关于手机 → 连点版本号开启开发者选项 → 打开 USB 调试，
> 数据线连电脑，弹窗选“允许调试”。

## 第三步：运行到手机

1. 手机连上电脑，双击 `mobile/run.bat`（自动带国内镜像、拉依赖、编译安装）。
   想直接出安装包就双击 `mobile/build-apk.bat`，APK 在
   `mobile/build/app/outputs/flutter-apk/app-release.apk`，发到手机安装即可。
2. App 首页右上角「设置」：
   - 后端地址填第一步打印的 `http://192.168.x.x:8000`，点“测试连接”；
   - 墨墨 Token：墨墨 App → 我的 → 更多设置 → 实验功能 → 开放 API，复制粘贴（加密存本机）。
3. 离线词典（可选）：按 `mobile/assets/dict/README.txt` 放好 `ecdict.db`；不放不影响拍照分析和墨墨同步，
   只是点词没有本地释义。

## 使用流程

首页「拍照分析」→ 校对页改对 OCR 错字、题目贴到第二栏 → 开始 AI 精讲 →
结果页三 Tab：题目讲解 / 逐句精读（点蓝色单词查词并加入墨墨）/ 全文与词汇（可整批加入墨墨）。

## 常见问题

- **pub 下载报 424 / 卡住**：run.bat 已默认走清华 Pub 镜像；自己开终端记得设
  `PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub`。
- **Flutter 版本显示 0.0.0-unknown**：Gitee 浅克隆不带 tag，已通过本地 tag 解决；
  若以后换机器克隆遇到，在 SDK 目录执行 `git tag 3.27.1` 即可。
- **手机连不上后端**：确认同 WiFi、地址用电脑局域网 IP（不是 127.0.0.1）、防火墙已放行。
- **墨墨提示词库未收录**：生僻词/专有名词墨墨没有收录就加不进去，App 会列出这些词，属正常现象。
- **成本**：OCR、点词、TTS、墨墨均免费；豆包按 token 计费，一篇阅读约几分钱。

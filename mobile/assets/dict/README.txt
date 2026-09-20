把 ECDICT 离线词典数据库放到本目录，文件名必须是 ecdict.db。

下载方式（二选一）：
1. 开源仓库：https://github.com/skywind3000/ECDICT/releases
   下载 ecdict-sqlite 压缩包，解压得到的 .db 文件重命名为 ecdict.db 放到这里。
2. 国内镜像：在 Gitee 搜索 “ECDICT”，下载 release 中的 sqlite 数据库。

要求：数据库内有表 dict，至少包含字段
word（单词）、phonetic（音标）、translation（中文释义）、pos（词性）、exchange（词形变化）。
放好后重新 flutter run 即可，App 首次启动会自动把它复制到本机数据库目录。
在词典文件就位前，点词弹窗会提示“本地词典未收录”，但不影响拍照分析与墨墨同步功能。

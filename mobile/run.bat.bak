@echo off
chcp 65001 >nul
REM 一键运行到已连接的安卓手机/模拟器（自动带国内镜像）
set PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=%PATH%;D:\JAVA\flutter\bin
cd /d %~dp0

echo [1/2] 拉取依赖...
flutter pub get
echo [2/2] 编译并安装到设备（手机需开启 USB 调试并连接电脑）...
flutter run
pause

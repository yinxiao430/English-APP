@echo off
chcp 65001 >nul
REM 打包 release APK，产物在 build\app\outputs\flutter-apk\app-release.apk
set PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=%PATH%;D:\JAVA\flutter\bin
cd /d %~dp0

flutter pub get
flutter build apk --release
echo.
echo 打包完成，APK 路径：
echo %~dp0build\app\outputs\flutter-apk\app-release.apk
pause

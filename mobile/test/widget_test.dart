// 冒烟测试：验证首页两个入口按钮正常渲染
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reading_tutor/pages/home_page.dart';

void main() {
  testWidgets('首页渲染拍照与相册入口', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('拍照分析'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
  });
}

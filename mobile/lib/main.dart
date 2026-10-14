import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'services/studied_service.dart';
import 'services/app_keys.dart';
import 'widgets/floating_ball.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  await StudiedService.instance.load();
  runApp(const ReadingTutorApp());
}

class ReadingTutorApp extends StatelessWidget {
  const ReadingTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: '英语阅读精讲',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB)),
        useMaterial3: true,
      ),
      // 在所有页面之上挂载可拖动的豆包悬浮球
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(child: child ?? const SizedBox.shrink()),
          const FloatingBall(),
        ],
      ),
      home: const HomePage(),
    );
  }
}

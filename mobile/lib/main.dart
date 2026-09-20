import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  runApp(const ReadingTutorApp());
}

class ReadingTutorApp extends StatelessWidget {
  const ReadingTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '英语阅读精讲',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

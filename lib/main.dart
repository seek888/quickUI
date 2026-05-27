import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import 'src/actions/platform_action_parser.dart';
import 'src/ui/demo_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Stac.initialize(
    actionParsers: const [PlatformActionParser()],
    errorWidgetBuilder: (context, error) {
      return Material(
        color: const Color(0xFFFFF7ED),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Stac parse error: ${error.error}',
            style: const TextStyle(color: Color(0xFF9A3412)),
          ),
        ),
      );
    },
  );
  runApp(const QuickUiDemoApp());
}

class QuickUiDemoApp extends StatelessWidget {
  const QuickUiDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickUI Platform Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F8),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const DemoShell(),
    );
  }
}

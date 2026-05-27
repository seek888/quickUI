import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:quick_ui/main.dart';
import 'package:quick_ui/src/actions/platform_action_parser.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Stac.initialize(
      actionParsers: const [PlatformActionParser()],
      override: true,
    );
  });

  testWidgets('renders the Stac platform demo shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('QuickUI 能力平台 Demo'), findsOneWidget);
    expect(find.text('内容流'), findsWidgets);
    expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsWidgets);
  });

  testWidgets('downloads config variants in order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.cloud_download_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('已下载配置：活动内容流'), findsOneWidget);
    expect(find.text('创作者直播周'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cloud_download_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('本周作者榜'), findsOneWidget);
  });

  testWidgets('opens current config viewer', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('内容流配置'), findsOneWidget);
  });
}

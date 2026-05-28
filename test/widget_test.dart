import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:quick_ui/main.dart';
import 'package:quick_ui/src/actions/platform_action_parser.dart';
import 'package:quick_ui/src/im/im_models.dart';
import 'package:quick_ui/src/im/mock_im_repository.dart';
import 'package:quick_ui/src/im/weather_api_service.dart';

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
    expect(find.text('IM'), findsWidgets);
    expect(find.text('内容流'), findsWidgets);
    expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsWidgets);
    expect(find.text('IM 工作台'), findsOneWidget);
    expect(find.text('创作者运营频道'), findsWidgets);
  });

  testWidgets('downloads config variants in order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('内容流').last);
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

    await tester.tap(find.text('内容流').last);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('内容流配置'), findsOneWidget);
  });

  testWidgets('runs an IM slash command', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const ValueKey('im-message-composer')),
      '/campaign',
    );
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('im-message-composer')),
    );
    expect(composer.controller?.text, isEmpty);
  });

  testWidgets('shows the weather API command in IM command list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.drag(find.byType(ListView).first, const Offset(0, -280));
    await tester.pumpAndSettle();

    expect(find.text('/weather'), findsOneWidget);
    expect(find.text('调用公开天气 API 并生成数据卡片'), findsOneWidget);
  });

  testWidgets('opens IM app manager', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.extension_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('频道应用管理'), findsOneWidget);
    expect(find.text('QuickUI 创作者助手'), findsOneWidget);
    expect(find.text('权限 Scope'), findsOneWidget);
  });

  testWidgets('opens scope request flow', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickUiDemoApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const ValueKey('im-message-composer')),
      '/request_scope',
    );
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('申请 IM 能力'), findsOneWidget);
    expect(find.text('启动工作流'), findsOneWidget);
  });

  test('mock IM repository creates campaign command card', () {
    final repository = MockImRepository();
    final message = repository.createCommandResult(
      conversationId: 'creator_ops',
      command: '/campaign',
    );

    expect(message.kind, ImMessageKind.card);
    expect(message.card?.title, '新建活动卡片');
    expect(message.card?.template, 'campaign_card');
  });

  test('mock IM manifest exposes app scopes and templates', () {
    final manifest = MockImRepository().getManifest();

    expect(manifest.name, 'QuickUI 创作者助手');
    expect(manifest.scopes.any((scope) => !scope.granted), isTrue);
    expect(
      manifest.scopes.any((scope) => scope.id == 'network.request'),
      isTrue,
    );
    expect(
      manifest.cardTemplates.any((template) => template.id == 'weather_card'),
      isTrue,
    );
  });

  test('weather code labels are mapped for card rendering', () {
    expect(weatherCodeToLabel(0), '晴朗');
    expect(weatherCodeToLabel(61), '降雨');
    expect(weatherCodeToLabel(95), '雷暴');
    expect(weatherCodeToLabel(-1), '未知天气');
  });

  test('mock IM repository creates weather command card', () {
    final repository = MockImRepository();
    final message = repository.createWeatherCard(
      conversationId: 'creator_ops',
      weather: const WeatherSnapshot(
        cityName: 'Shanghai',
        country: '中国',
        latitude: 31.2304,
        longitude: 121.4737,
        temperature: 24.6,
        windSpeed: 10.2,
        weatherCode: 1,
        observedAt: '2026-05-28T10:00',
      ),
    );

    expect(message.kind, ImMessageKind.card);
    expect(message.card?.template, 'weather_card');
    expect(message.card?.payload['source'], 'open_meteo');
  });
}

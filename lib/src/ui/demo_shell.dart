import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stac/stac.dart';

import '../data/demo_pages.dart';
import '../im/im_demo_page.dart';

class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  int _selectedIndex = 0;
  final Map<String, int> _variantIndexes = {
    for (final page in demoPages) page.id: 0,
  };

  DemoPageConfig get _selectedPage => demoPages[_selectedIndex];
  int get _selectedVariantIndex => _variantIndexes[_selectedPage.id] ?? 0;
  DemoConfigVariant get _selectedVariant =>
      _selectedPage.variants[_selectedVariantIndex];

  void _downloadConfig() {
    setState(() {
      _variantIndexes[_selectedPage.id] =
          (_selectedVariantIndex + 1) % _selectedPage.variants.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已下载配置：${_selectedVariant.name}，并重新渲染动态页面')),
    );
  }

  void _openCurrentConfig() {
    if (_selectedPage.id == 'im') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IM POC 使用原生容器 + 动态卡片表单，当前入口没有页面 JSON。')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ConfigViewerPage(page: _selectedPage, variant: _selectedVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickUI 能力平台 Demo'),
        actions: [
          IconButton(
            tooltip: '查看配置',
            onPressed: _openCurrentConfig,
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            tooltip: '下载配置',
            onPressed: _downloadConfig,
            icon: const Icon(Icons.cloud_download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ConfigBanner(
              page: _selectedPage,
              variant: _selectedVariant,
              variantIndex: _selectedVariantIndex,
              variantCount: _selectedPage.variants.length,
              onDownload: _downloadConfig,
              onViewConfig: _openCurrentConfig,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(
                    '${_selectedPage.id}-${_selectedVariant.assetPath}',
                  ),
                  child: _selectedPage.id == 'im'
                      ? const ImDemoPage()
                      : Stac.fromAssets(
                          _selectedVariant.assetPath,
                          loadingWidget: (_) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorWidget: (_, error) {
                            return Center(child: Text('配置加载失败: $error'));
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          for (final page in demoPages)
            NavigationDestination(icon: Icon(page.icon), label: page.title),
        ],
      ),
    );
  }
}

class _ConfigBanner extends StatelessWidget {
  const _ConfigBanner({
    required this.page,
    required this.variant,
    required this.variantIndex,
    required this.variantCount,
    required this.onDownload,
    required this.onViewConfig,
  });

  final DemoPageConfig page;
  final DemoConfigVariant variant;
  final int variantIndex;
  final int variantCount;
  final VoidCallback onDownload;
  final VoidCallback onViewConfig;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(page.icon, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${page.title} · ${variant.name} ${variantIndex + 1}/$variantCount',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${page.description} · ${variant.summary}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 8,
            children: [
              IconButton.filledTonal(
                tooltip: '查看配置',
                onPressed: onViewConfig,
                icon: const Icon(Icons.account_tree_outlined),
              ),
              FilledButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('下载'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConfigViewerPage extends StatefulWidget {
  const ConfigViewerPage({
    super.key,
    required this.page,
    required this.variant,
  });

  final DemoPageConfig page;
  final DemoConfigVariant variant;

  @override
  State<ConfigViewerPage> createState() => _ConfigViewerPageState();
}

class _ConfigViewerPageState extends State<ConfigViewerPage> {
  late final Future<String> _configFuture = _loadPrettyConfig();

  Future<String> _loadPrettyConfig() async {
    final raw = await rootBundle.loadString(widget.variant.assetPath);
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.page.title}配置')),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _configFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('配置读取失败: ${snapshot.error}'));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.variant.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.variant.assetPath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(widget.variant.summary),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          snapshot.data ?? '',
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

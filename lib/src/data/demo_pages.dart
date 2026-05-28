import 'package:flutter/material.dart';

class DemoPageConfig {
  const DemoPageConfig({
    required this.id,
    required this.title,
    required this.variants,
    required this.icon,
    required this.description,
  });

  final String id;
  final String title;
  final List<DemoConfigVariant> variants;
  final IconData icon;
  final String description;
}

class DemoConfigVariant {
  const DemoConfigVariant({
    required this.name,
    required this.assetPath,
    required this.summary,
  });

  final String name;
  final String assetPath;
  final String summary;
}

const demoPages = <DemoPageConfig>[
  DemoPageConfig(
    id: 'im',
    title: 'IM',
    variants: [
      DemoConfigVariant(
        name: 'IM 能力 POC',
        assetPath: 'native://im-demo',
        summary: '会话、Bot、命令、动态卡片和表单',
      ),
    ],
    icon: Icons.chat_bubble_outline,
    description: '模拟 Slack/Discord 风格的 IM 开放能力',
  ),
  DemoPageConfig(
    id: 'feed',
    title: '内容流',
    variants: [
      DemoConfigVariant(
        name: '基础内容流',
        assetPath: 'assets/stac/feed.json',
        summary: '文章卡片、关注、私信和分享',
      ),
      DemoConfigVariant(
        name: '活动内容流',
        assetPath: 'assets/stac/feed_event.json',
        summary: '活动横幅、报名入口和会话咨询',
      ),
      DemoConfigVariant(
        name: '榜单内容流',
        assetPath: 'assets/stac/feed_rank.json',
        summary: '作者榜单、推荐关注和分享榜单',
      ),
    ],
    icon: Icons.dynamic_feed_outlined,
    description: '配置驱动的信息流、文章卡片和社交动作',
  ),
  DemoPageConfig(
    id: 'article',
    title: '专题页',
    variants: [
      DemoConfigVariant(
        name: '平台专题',
        assetPath: 'assets/stac/article.json',
        summary: '能力平台说明和相关推荐',
      ),
      DemoConfigVariant(
        name: '发布指南',
        assetPath: 'assets/stac/article_guide.json',
        summary: '创作者发布指南和咨询入口',
      ),
      DemoConfigVariant(
        name: '案例拆解',
        assetPath: 'assets/stac/article_case.json',
        summary: '动态页面案例和分享入口',
      ),
    ],
    icon: Icons.article_outlined,
    description: '后台下发的文章详情、推荐和分享入口',
  ),
  DemoPageConfig(
    id: 'creator',
    title: '创作者',
    variants: [
      DemoConfigVariant(
        name: '能力申请',
        assetPath: 'assets/stac/creator.json',
        summary: '权限申请、动态表单和提交',
      ),
      DemoConfigVariant(
        name: '活动配置',
        assetPath: 'assets/stac/creator_campaign.json',
        summary: '活动信息、表单和分享能力',
      ),
      DemoConfigVariant(
        name: '数据看板',
        assetPath: 'assets/stac/creator_dashboard.json',
        summary: '指标卡片、运营建议和授权入口',
      ),
    ],
    icon: Icons.dashboard_customize_outlined,
    description: '动态表单、活动入口和平台能力申请',
  ),
];

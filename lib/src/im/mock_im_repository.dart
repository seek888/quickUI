import 'im_models.dart';

class MockImRepository {
  final List<ImConversation> _conversations = const [
    ImConversation(
      id: 'creator_ops',
      title: '创作者运营频道',
      type: ImConversationType.channel,
      description: '频道 · 配置活动、榜单和群工具',
      avatarText: '#',
      unreadCount: 3,
      memberCount: 128,
    ),
    ImConversation(
      id: 'platform_bot',
      title: 'QuickUI 平台助手',
      type: ImConversationType.bot,
      description: 'Bot · 命令、表单、能力申请',
      avatarText: 'B',
      unreadCount: 1,
      memberCount: 1,
    ),
    ImConversation(
      id: 'design_group',
      title: '设计协作群',
      type: ImConversationType.group,
      description: '群聊 · 分享动态卡片和专题',
      avatarText: '设',
      unreadCount: 0,
      memberCount: 18,
    ),
  ];

  final Map<String, List<ImMessage>> _messages = {
    'creator_ops': [
      const ImMessage(
        id: 'm1',
        conversationId: 'creator_ops',
        senderName: '系统',
        sentAt: '09:30',
        kind: ImMessageKind.system,
        text: 'QuickUI 应用已安装到频道，可使用 /campaign 创建活动卡片。',
      ),
      const ImMessage(
        id: 'm2',
        conversationId: 'creator_ops',
        senderName: '运营助手',
        sentAt: '09:32',
        kind: ImMessageKind.card,
        card: ImCard(
          template: 'campaign_card',
          title: '春季创作挑战',
          subtitle: '点击按钮打开 Stac 动态表单，提交后生成活动卡片。',
          primaryAction: '打开表单',
          secondaryAction: '分享',
          configAsset: 'assets/stac/im/campaign_card.json',
          formAsset: 'assets/stac/im/campaign_form.json',
          payload: {
            'campaignId': 'spring_creator_2026',
            'source': 'channel_card',
          },
        ),
      ),
      const ImMessage(
        id: 'm3',
        conversationId: 'creator_ops',
        senderName: '林川',
        sentAt: '09:35',
        kind: ImMessageKind.text,
        text: '这个卡片可以交给创作者自己配置，不需要客户端发版。',
      ),
    ],
    'platform_bot': [
      const ImMessage(
        id: 'b1',
        conversationId: 'platform_bot',
        senderName: 'QuickUI Bot',
        sentAt: '10:00',
        kind: ImMessageKind.text,
        text: '输入 /campaign、/poll 或 /request_scope 试试。',
      ),
    ],
    'design_group': [
      const ImMessage(
        id: 'g1',
        conversationId: 'design_group',
        senderName: '阿澈',
        sentAt: '11:20',
        kind: ImMessageKind.card,
        card: ImCard(
          template: 'article_card',
          title: '动态页面组件规范',
          subtitle: '用于统一 IM 卡片、专题页和活动表单的组件边界。',
          primaryAction: '查看',
          secondaryAction: '转发',
          configAsset: 'assets/stac/im/article_card.json',
          formAsset: 'assets/stac/im/campaign_form.json',
          payload: {
            'articleId': 'dynamic_component_spec',
            'source': 'group_share',
          },
        ),
      ),
    ],
  };

  final List<ImCommand> _commands = const [
    ImCommand(
      name: '/campaign',
      description: '创建活动卡片并打开动态表单',
      scope: 'message.card.write',
    ),
    ImCommand(
      name: '/poll',
      description: '发起投票卡片',
      scope: 'message.card.write',
    ),
    ImCommand(
      name: '/request_scope',
      description: '申请群工具和卡片能力',
      scope: 'app.scope.request',
    ),
  ];

  List<ImConversation> getConversations() => List.unmodifiable(_conversations);

  List<ImMessage> getMessages(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? const []);

  List<ImCommand> getCommands() => List.unmodifiable(_commands);

  ImMessage createTextMessage({
    required String conversationId,
    required String text,
  }) {
    return ImMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderName: '我',
      sentAt: '现在',
      kind: ImMessageKind.text,
      text: text,
      isMine: true,
    );
  }

  ImMessage createCommandResult({
    required String conversationId,
    required String command,
  }) {
    if (command.startsWith('/campaign')) {
      return ImMessage(
        id: 'cmd_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        senderName: 'QuickUI Bot',
        sentAt: '现在',
        kind: ImMessageKind.card,
        card: const ImCard(
          template: 'campaign_card',
          title: '新建活动卡片',
          subtitle: '命令触发 Bot，Bot 返回一张可交互动态卡片。',
          primaryAction: '打开表单',
          secondaryAction: '分享',
          configAsset: 'assets/stac/im/campaign_card.json',
          formAsset: 'assets/stac/im/campaign_form.json',
          payload: {'command': '/campaign'},
        ),
      );
    }

    if (command.startsWith('/poll')) {
      return ImMessage(
        id: 'cmd_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        senderName: 'QuickUI Bot',
        sentAt: '现在',
        kind: ImMessageKind.card,
        card: const ImCard(
          template: 'poll_card',
          title: '投票：下一期活动主题',
          subtitle: '消息卡片可以承载投票、审批、报名和任务。',
          primaryAction: '参与投票',
          secondaryAction: '查看结果',
          configAsset: 'assets/stac/im/poll_card.json',
          formAsset: 'assets/stac/im/campaign_form.json',
          payload: {'command': '/poll'},
        ),
      );
    }

    return ImMessage(
      id: 'cmd_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderName: 'QuickUI Bot',
      sentAt: '现在',
      kind: ImMessageKind.system,
      text: '已收到 $command。该命令需要申请对应 scope 后才能执行。',
    );
  }

  ImMessage createSubmittedCampaignCard({required String conversationId}) {
    return ImMessage(
      id: 'submitted_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderName: 'QuickUI Bot',
      sentAt: '现在',
      kind: ImMessageKind.card,
      card: const ImCard(
        template: 'campaign_card',
        title: '已提交：春季创作挑战',
        subtitle: '表单提交后，工作流生成新的频道消息卡片。',
        primaryAction: '再次编辑',
        secondaryAction: '分享',
        configAsset: 'assets/stac/im/campaign_card.json',
        formAsset: 'assets/stac/im/campaign_form.json',
        payload: {'workflow': 'campaign_card_create'},
      ),
    );
  }

  ImAppManifest getManifest() {
    return ImAppManifest(
      appId: 'quickui_creator_bot',
      name: 'QuickUI 创作者助手',
      description: '安装到频道后提供活动卡片、投票、表单和能力申请。',
      installed: true,
      scopes: const [
        ImScope(
          id: 'message.send_card',
          name: '发送卡片消息',
          description: '允许 Bot 在已安装频道发送结构化卡片。',
          granted: true,
        ),
        ImScope(
          id: 'modal.open',
          name: '打开动态表单',
          description: '允许按钮或命令打开 Stac 表单。',
          granted: true,
        ),
        ImScope(
          id: 'workflow.start',
          name: '启动工作流',
          description: '允许表单提交后触发自动化流程。',
          granted: false,
        ),
        ImScope(
          id: 'member.invite',
          name: '邀请成员',
          description: '允许应用辅助邀请成员加入频道。',
          granted: false,
        ),
      ],
      commands: _commands,
      cardTemplates: const [
        ImCardTemplate(
          id: 'campaign_card',
          name: '活动卡片',
          description: '用于报名、活动传播和频道通知。',
          configAsset: 'assets/stac/im/campaign_card.json',
        ),
        ImCardTemplate(
          id: 'poll_card',
          name: '投票卡片',
          description: '用于频道投票和轻量决策。',
          configAsset: 'assets/stac/im/poll_card.json',
        ),
        ImCardTemplate(
          id: 'article_card',
          name: '文章卡片',
          description: '用于把内容分享到会话。',
          configAsset: 'assets/stac/im/article_card.json',
        ),
      ],
    );
  }
}

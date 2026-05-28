import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stac/stac.dart';

import 'im_models.dart';
import 'mock_im_repository.dart';
import 'weather_api_service.dart';

class ImDemoPage extends StatefulWidget {
  const ImDemoPage({super.key});

  @override
  State<ImDemoPage> createState() => _ImDemoPageState();
}

class _ImDemoPageState extends State<ImDemoPage> {
  final MockImRepository _repository = MockImRepository();
  final WeatherApiService _weatherApiService = WeatherApiService();
  final Random _random = Random();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  late final List<ImConversation> _conversations = _repository
      .getConversations();
  late String _selectedConversationId = _conversations.first.id;
  late final Map<String, List<ImMessage>> _messagesByConversation = {
    for (final conversation in _conversations)
      conversation.id: _repository.getMessages(conversation.id).toList(),
  };
  late final Set<String> _grantedScopes = _repository
      .getManifest()
      .scopes
      .where((scope) => scope.granted)
      .map((scope) => scope.id)
      .toSet();

  ImConversation get _selectedConversation => _conversations.firstWhere(
    (conversation) => conversation.id == _selectedConversationId,
  );

  List<ImMessage> get _messages =>
      _messagesByConversation[_selectedConversationId] ?? const [];

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _selectConversation(String id) {
    setState(() {
      _selectedConversationId = id;
    });
  }

  void _openConversation(String id) {
    _selectConversation(id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, setRouteState) {
            return _ConversationChatPage(
              conversation: _selectedConversation,
              messages: _messages,
              scrollController: _messageScrollController,
              controller: _messageController,
              onSend: () {
                _sendInput();
                setRouteState(() {});
              },
              onOpenCard: (card) async {
                await _openDynamicForm(card);
                setRouteState(() {});
              },
              onViewCardConfig: _openCardConfig,
              onShareCard: _shareCard,
              onOpenAppManager: _openAppManager,
            );
          },
        ),
      ),
    );
  }

  void _sendInput() {
    final input = _messageController.text.trim();
    if (input.isEmpty) return;

    if (input.startsWith('/request_scope')) {
      _messageController.clear();
      _showScopeRequestSheet();
      return;
    }

    if (input.startsWith('/workflow')) {
      _handleScopedCommand(
        input: input,
        requiredScope: 'workflow.start',
        createResult: () => _repository.createWorkflowCard(
          conversationId: _selectedConversationId,
        ),
      );
      return;
    }

    if (input.startsWith('/invite')) {
      _handleScopedCommand(
        input: input,
        requiredScope: 'member.invite',
        createResult: () => _repository.createInviteResult(
          conversationId: _selectedConversationId,
          invitees: _parseInvitees(input),
        ),
      );
      return;
    }

    if (input.startsWith('/weather')) {
      final cityName = _parseWeatherCity(input);
      _messageController.clear();
      _appendMessage(
        _repository.createTextMessage(
          conversationId: _selectedConversationId,
          text: input,
        ),
      );
      _fetchAndAppendWeather(cityName, conversationId: _selectedConversationId);
      return;
    }

    final message = input.startsWith('/')
        ? _repository.createCommandResult(
            conversationId: _selectedConversationId,
            command: input,
          )
        : _repository.createTextMessage(
            conversationId: _selectedConversationId,
            text: input,
          );

    setState(() {
      _messagesByConversation[_selectedConversationId] = [
        ..._messages,
        message,
      ];
      _messageController.clear();
    });
    _scrollToBottom();
  }

  String _parseWeatherCity(String input) {
    final parts = input.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts.length >= 2 ? parts.skip(1).join(' ') : 'Shanghai';
  }

  List<String> _parseInvitees(String input) {
    return input
        .split(RegExp(r'\s+'))
        .skip(1)
        .where((part) => part.trim().isNotEmpty)
        .toList();
  }

  void _handleScopedCommand({
    required String input,
    required String requiredScope,
    required ImMessage Function() createResult,
  }) {
    _messageController.clear();
    _appendMessage(
      _repository.createTextMessage(
        conversationId: _selectedConversationId,
        text: input,
      ),
    );

    if (!_grantedScopes.contains(requiredScope)) {
      _appendMessage(
        ImMessage(
          id: 'scope_denied_${DateTime.now().microsecondsSinceEpoch}',
          conversationId: _selectedConversationId,
          senderName: '系统',
          sentAt: '现在',
          kind: ImMessageKind.system,
          text: '缺少 $requiredScope 权限。请先输入 /request_scope 提交申请，本 Demo 会默认通过。',
        ),
      );
      return;
    }

    _appendMessage(createResult());
  }

  void _insertCommand(String command) {
    _messageController.text = command;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Future<void> _openDynamicForm(ImCard card) async {
    if (card.template == 'weather_card') {
      final cityName = _randomChineseCity(exceptCity: card.payload['city']);
      await _fetchAndAppendWeather(
        cityName,
        conversationId: _selectedConversationId,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Stac.fromAssets(
              card.formAsset,
              loadingWidget: (_) {
                return const Center(child: CircularProgressIndicator());
              },
              errorWidget: (_, error) {
                return Center(child: Text('IM 表单配置加载失败: $error'));
              },
            ),
          ),
        );
      },
    );
    _appendMessage(
      _repository.createSubmittedCampaignCard(
        conversationId: _selectedConversationId,
      ),
    );
  }

  String _randomChineseCity({String? exceptCity}) {
    const cities = [
      'Beijing',
      'Shanghai',
      'Guangzhou',
      'Shenzhen',
      'Hangzhou',
      'Chengdu',
      'Wuhan',
      'Nanjing',
      'Xian',
      'Chongqing',
      'Suzhou',
      'Qingdao',
      'Xiamen',
      'Changsha',
      'Kunming',
    ];
    final candidates = cities.where((city) => city != exceptCity).toList();
    return candidates[_random.nextInt(candidates.length)];
  }

  Future<void> _fetchAndAppendWeather(
    String cityName, {
    required String conversationId,
  }) async {
    _appendMessage(
      ImMessage(
        id: 'weather_loading_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        senderName: '系统',
        sentAt: '现在',
        kind: ImMessageKind.system,
        text: '正在通过 Open-Meteo 获取 $cityName 天气...',
      ),
    );
    try {
      final weather = await _weatherApiService.fetchWeatherForCity(cityName);
      if (!mounted) return;
      _appendMessage(
        _repository.createWeatherCard(
          conversationId: conversationId,
          weather: weather,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _appendMessage(
        ImMessage(
          id: 'weather_error_${DateTime.now().microsecondsSinceEpoch}',
          conversationId: conversationId,
          senderName: '系统',
          sentAt: '现在',
          kind: ImMessageKind.system,
          text: '天气接口调用失败: $error',
        ),
      );
    }
  }

  void _appendMessage(ImMessage message) {
    setState(() {
      _messagesByConversation[_selectedConversationId] = [
        ..._messages,
        message,
      ];
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _openCardConfig(ImCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImJsonViewerPage(
          title: '${card.template} 配置',
          assetPath: card.configAsset,
          summary: '消息卡片模板由结构化 JSON 描述，客户端只渲染和分发受控 action。',
        ),
      ),
    );
  }

  void _openAppManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImAppManagerPage(manifest: _currentManifest()),
      ),
    );
  }

  void _showScopeRequestSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return _ScopeRequestSheet(
          manifest: _currentManifest(),
          onApprove: _approvePendingScopes,
        );
      },
    );
  }

  ImAppManifest _currentManifest() {
    final manifest = _repository.getManifest();
    return ImAppManifest(
      appId: manifest.appId,
      name: manifest.name,
      description: manifest.description,
      installed: manifest.installed,
      scopes: [
        for (final scope in manifest.scopes)
          ImScope(
            id: scope.id,
            name: scope.name,
            description: scope.description,
            granted: _grantedScopes.contains(scope.id),
          ),
      ],
      commands: manifest.commands,
      cardTemplates: manifest.cardTemplates,
    );
  }

  void _approvePendingScopes(List<ImScope> pendingScopes) {
    setState(() {
      _grantedScopes.addAll(pendingScopes.map((scope) => scope.id));
    });
    _appendMessage(
      ImMessage(
        id: 'scope_approved_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: _selectedConversationId,
        senderName: '系统',
        sentAt: '现在',
        kind: ImMessageKind.system,
        text:
            '权限申请已自动通过：${pendingScopes.map((scope) => scope.name).join('、')}。现在可以测试 /workflow 和 /invite。',
      ),
    );
  }

  void _shareCard(ImCard card) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已模拟分享卡片：${card.title}')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;
        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: 310,
                child: _ConversationList(
                  conversations: _conversations,
                  selectedConversationId: _selectedConversationId,
                  commands: _repository.getCommands(),
                  onSelected: _selectConversation,
                  onCommandSelected: _insertCommand,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _ChatRoom(
                  conversation: _selectedConversation,
                  messages: _messages,
                  scrollController: _messageScrollController,
                  controller: _messageController,
                  onSend: _sendInput,
                  onOpenCard: _openDynamicForm,
                  onViewCardConfig: _openCardConfig,
                  onShareCard: _shareCard,
                  onOpenAppManager: _openAppManager,
                ),
              ),
            ],
          );
        }

        return _ConversationInbox(
          conversations: _conversations,
          commands: _repository.getCommands(),
          onConversationSelected: _openConversation,
          onCommandSelected: (command) {
            _insertCommand(command);
            _openConversation(_selectedConversationId);
          },
        );
      },
    );
  }
}

class _ConversationChatPage extends StatelessWidget {
  const _ConversationChatPage({
    required this.conversation,
    required this.messages,
    required this.scrollController,
    required this.controller,
    required this.onSend,
    required this.onOpenCard,
    required this.onViewCardConfig,
    required this.onShareCard,
    required this.onOpenAppManager,
  });

  final ImConversation conversation;
  final List<ImMessage> messages;
  final ScrollController scrollController;
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<ImCard> onOpenCard;
  final ValueChanged<ImCard> onViewCardConfig;
  final ValueChanged<ImCard> onShareCard;
  final VoidCallback onOpenAppManager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _ChatRoom(
          conversation: conversation,
          messages: messages,
          scrollController: scrollController,
          controller: controller,
          onSend: onSend,
          onOpenCard: onOpenCard,
          onViewCardConfig: onViewCardConfig,
          onShareCard: onShareCard,
          onOpenAppManager: onOpenAppManager,
          showBackButton: true,
        ),
      ),
    );
  }
}

class _ConversationInbox extends StatelessWidget {
  const _ConversationInbox({
    required this.conversations,
    required this.commands,
    required this.onConversationSelected,
    required this.onCommandSelected,
  });

  final List<ImConversation> conversations;
  final List<ImCommand> commands;
  final ValueChanged<String> onConversationSelected;
  final ValueChanged<String> onCommandSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('消息', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: '搜索会话、频道或 Bot',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 72, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _InboxConversationTile(
                conversation: conversation,
                onTap: () => onConversationSelected(conversation.id),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                '快捷命令',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList.builder(
              itemCount: commands.length,
              itemBuilder: (context, index) {
                final command = commands[index];
                return _CommandTile(command: command, onTap: onCommandSelected);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxConversationTile extends StatelessWidget {
  const _InboxConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ImConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(
            conversation.avatarText,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _conversationTime(conversation),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_typeLabel(conversation.type)} · ${conversation.description}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: conversation.unreadCount > 0
            ? Badge(label: Text('${conversation.unreadCount}'))
            : const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }

  String _conversationTime(ImConversation conversation) {
    return switch (conversation.id) {
      'creator_ops' => '09:35',
      'platform_bot' => '10:00',
      'design_group' => '11:20',
      _ => '现在',
    };
  }

  String _typeLabel(ImConversationType type) {
    return switch (type) {
      ImConversationType.direct => '单聊',
      ImConversationType.group => '群聊',
      ImConversationType.channel => '频道',
      ImConversationType.bot => 'Bot',
    };
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.selectedConversationId,
    required this.commands,
    required this.onSelected,
    required this.onCommandSelected,
  });

  final List<ImConversation> conversations;
  final String selectedConversationId;
  final List<ImCommand> commands;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onCommandSelected;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('IM 工作台', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '模拟 Slack/Discord 风格：频道、Bot、命令和动态卡片。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        for (final conversation in conversations)
          _ConversationTile(
            conversation: conversation,
            selected: conversation.id == selectedConversationId,
            onTap: () => onSelected(conversation.id),
          ),
        const SizedBox(height: 16),
        Text('可配置命令', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final command in commands)
          _CommandTile(command: command, onTap: onCommandSelected),
      ],
    );

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
      child: content,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final ImConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primaryContainer : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? colorScheme.primary : const Color(0xFFE5E7EB),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: selected
              ? colorScheme.primary
              : const Color(0xFFE2E8F0),
          child: Text(
            conversation.avatarText,
            style: TextStyle(
              color: selected ? colorScheme.onPrimary : const Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          conversation.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: conversation.unreadCount > 0
            ? Badge(label: Text('${conversation.unreadCount}'))
            : null,
        onTap: onTap,
      ),
    );

    return tile;
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.command, required this.onTap});

  final ImCommand command;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        dense: true,
        title: Text(command.name),
        subtitle: Text(command.description),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => onTap(command.name),
      ),
    );
  }
}

class _ChatRoom extends StatelessWidget {
  const _ChatRoom({
    required this.conversation,
    required this.messages,
    required this.scrollController,
    required this.controller,
    required this.onSend,
    required this.onOpenCard,
    required this.onViewCardConfig,
    required this.onShareCard,
    required this.onOpenAppManager,
    this.showBackButton = false,
  });

  final ImConversation conversation;
  final List<ImMessage> messages;
  final ScrollController scrollController;
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<ImCard> onOpenCard;
  final ValueChanged<ImCard> onViewCardConfig;
  final ValueChanged<ImCard> onShareCard;
  final VoidCallback onOpenAppManager;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(
          conversation: conversation,
          onOpenAppManager: onOpenAppManager,
          showBackButton: showBackButton,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return _MessageBubble(
                message: messages[index],
                onOpenCard: onOpenCard,
                onViewCardConfig: onViewCardConfig,
                onShareCard: onShareCard,
              );
            },
          ),
        ),
        _MessageComposer(controller: controller, onSend: onSend),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.conversation,
    required this.onOpenAppManager,
    required this.showBackButton,
  });

  final ImConversation conversation;
  final VoidCallback onOpenAppManager;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              tooltip: '返回',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_typeLabel(conversation.type)} · ${conversation.memberCount} 成员 · App 能力：命令、卡片、表单、工作流',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '频道工具',
            onPressed: onOpenAppManager,
            icon: const Icon(Icons.extension_outlined),
          ),
        ],
      ),
    );
  }

  String _typeLabel(ImConversationType type) {
    return switch (type) {
      ImConversationType.direct => '单聊',
      ImConversationType.group => '群聊',
      ImConversationType.channel => '频道',
      ImConversationType.bot => 'Bot',
    };
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onOpenCard,
    required this.onViewCardConfig,
    required this.onShareCard,
  });

  final ImMessage message;
  final ValueChanged<ImCard> onOpenCard;
  final ValueChanged<ImCard> onViewCardConfig;
  final ValueChanged<ImCard> onShareCard;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ImMessageKind.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.text ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: message.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              '${message.senderName} · ${message.sentAt}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            if (message.kind == ImMessageKind.text)
              _TextMessageBubble(message: message)
            else if (message.card != null)
              _CardMessage(
                card: message.card!,
                onOpenCard: onOpenCard,
                onViewCardConfig: onViewCardConfig,
                onShareCard: onShareCard,
              ),
          ],
        ),
      ),
    );
  }
}

class _TextMessageBubble extends StatelessWidget {
  const _TextMessageBubble({required this.message});

  final ImMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isMine ? colorScheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: message.isMine
            ? null
            : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        message.text ?? '',
        style: TextStyle(
          color: message.isMine
              ? colorScheme.onPrimary
              : const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _CardMessage extends StatelessWidget {
  const _CardMessage({
    required this.card,
    required this.onOpenCard,
    required this.onViewCardConfig,
    required this.onShareCard,
  });

  final ImCard card;
  final ValueChanged<ImCard> onOpenCard;
  final ValueChanged<ImCard> onViewCardConfig;
  final ValueChanged<ImCard> onShareCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.widgets_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.template,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const Text('Dynamic Card'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  card.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => onOpenCard(card),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(card.primaryAction),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onShareCard(card),
                      icon: const Icon(Icons.ios_share_outlined, size: 18),
                      label: Text(card.secondaryAction),
                    ),
                    TextButton.icon(
                      onPressed: () => onViewCardConfig(card),
                      icon: const Icon(Icons.account_tree_outlined, size: 18),
                      label: const Text('配置'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('im-message-composer'),
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '输入消息，或输入 /weather Shanghai 调用天气 API',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '发送',
            onPressed: onSend,
            icon: const Icon(Icons.send_outlined),
          ),
        ],
      ),
    );
  }
}

class ImJsonViewerPage extends StatefulWidget {
  const ImJsonViewerPage({
    super.key,
    required this.title,
    required this.assetPath,
    required this.summary,
  });

  final String title;
  final String assetPath;
  final String summary;

  @override
  State<ImJsonViewerPage> createState() => _ImJsonViewerPageState();
}

class _ImJsonViewerPageState extends State<ImJsonViewerPage> {
  late final Future<String> _jsonFuture = _loadJson();

  Future<String> _loadJson() async {
    final raw = await rootBundle.loadString(widget.assetPath);
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _jsonFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('读取失败: ${snapshot.error}'));
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
                        widget.summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.assetPath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
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

class ImAppManagerPage extends StatelessWidget {
  const ImAppManagerPage({super.key, required this.manifest});

  final ImAppManifest manifest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('频道应用管理')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: const Icon(Icons.smart_toy_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manifest.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                manifest.appId,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(value: manifest.installed, onChanged: (_) {}),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(manifest.description),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('权限 Scope', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final scope in manifest.scopes)
              Card(
                child: ListTile(
                  leading: Icon(
                    scope.granted
                        ? Icons.check_circle_outline
                        : Icons.lock_outline,
                    color: scope.granted
                        ? const Color(0xFF047857)
                        : const Color(0xFFB45309),
                  ),
                  title: Text(scope.name),
                  subtitle: Text('${scope.id} · ${scope.description}'),
                  trailing: scope.granted
                      ? const Text('已授权')
                      : FilledButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已模拟申请：${scope.name}')),
                            );
                          },
                          child: const Text('申请'),
                        ),
                ),
              ),
            const SizedBox(height: 12),
            Text('命令', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final command in manifest.commands)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.terminal_outlined),
                  title: Text(command.name),
                  subtitle: Text('${command.description} · ${command.scope}'),
                ),
              ),
            const SizedBox(height: 12),
            Text('卡片模板', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final template in manifest.cardTemplates)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.widgets_outlined),
                  title: Text(template.name),
                  subtitle: Text(template.description),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImJsonViewerPage(
                            title: '${template.name}配置',
                            assetPath: template.configAsset,
                            summary: template.description,
                          ),
                        ),
                      );
                    },
                    child: const Text('查看'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScopeRequestSheet extends StatelessWidget {
  const _ScopeRequestSheet({required this.manifest, required this.onApprove});

  final ImAppManifest manifest;
  final ValueChanged<List<ImScope>> onApprove;

  @override
  Widget build(BuildContext context) {
    final pendingScopes = manifest.scopes
        .where((scope) => !scope.granted)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('申请 IM 能力', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '模拟第三方 App 申请更多频道能力。真实产品中会进入管理员审批和审计流程。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          for (final scope in pendingScopes)
            CheckboxListTile(
              value: true,
              onChanged: (_) {},
              contentPadding: EdgeInsets.zero,
              title: Text(scope.name),
              subtitle: Text('${scope.id} · ${scope.description}'),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onApprove(pendingScopes);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('权限申请已自动通过')));
              },
              child: const Text('提交申请并通过'),
            ),
          ),
        ],
      ),
    );
  }
}

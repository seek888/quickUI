import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import 'im_models.dart';
import 'mock_im_repository.dart';

class ImDemoPage extends StatefulWidget {
  const ImDemoPage({super.key});

  @override
  State<ImDemoPage> createState() => _ImDemoPageState();
}

class _ImDemoPageState extends State<ImDemoPage> {
  final MockImRepository _repository = MockImRepository();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  late final List<ImConversation> _conversations = _repository
      .getConversations();
  late String _selectedConversationId = _conversations.first.id;
  late final Map<String, List<ImMessage>> _messagesByConversation = {
    for (final conversation in _conversations)
      conversation.id: _repository.getMessages(conversation.id).toList(),
  };

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

  void _sendInput() {
    final input = _messageController.text.trim();
    if (input.isEmpty) return;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _insertCommand(String command) {
    _messageController.text = command;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Future<void> _openDynamicForm(ImCard card) {
    return showModalBottomSheet<void>(
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
              'assets/stac/im/campaign_form.json',
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
                  onShareCard: _shareCard,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 164,
              child: _ConversationList(
                conversations: _conversations,
                selectedConversationId: _selectedConversationId,
                commands: _repository.getCommands(),
                onSelected: _selectConversation,
                onCommandSelected: _insertCommand,
                compact: true,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _ChatRoom(
                conversation: _selectedConversation,
                messages: _messages,
                scrollController: _messageScrollController,
                controller: _messageController,
                onSend: _sendInput,
                onOpenCard: _openDynamicForm,
                onShareCard: _shareCard,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.selectedConversationId,
    required this.commands,
    required this.onSelected,
    required this.onCommandSelected,
    this.compact = false,
  });

  final List<ImConversation> conversations;
  final String selectedConversationId;
  final List<ImCommand> commands;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onCommandSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      scrollDirection: compact ? Axis.horizontal : Axis.vertical,
      padding: const EdgeInsets.all(12),
      children: [
        if (!compact) ...[
          Text('IM 工作台', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '模拟 Slack/Discord 风格：频道、Bot、命令和动态卡片。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
        ],
        for (final conversation in conversations)
          _ConversationTile(
            conversation: conversation,
            selected: conversation.id == selectedConversationId,
            compact: compact,
            onTap: () => onSelected(conversation.id),
          ),
        if (!compact) ...[
          const SizedBox(height: 16),
          Text('可配置命令', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final command in commands)
            _CommandTile(command: command, onTap: onCommandSelected),
        ],
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
    required this.compact,
    required this.onTap,
  });

  final ImConversation conversation;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tile = Container(
      width: compact ? 260 : null,
      margin: EdgeInsets.only(right: compact ? 10 : 0, bottom: compact ? 0 : 8),
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
    required this.onShareCard,
  });

  final ImConversation conversation;
  final List<ImMessage> messages;
  final ScrollController scrollController;
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<ImCard> onOpenCard;
  final ValueChanged<ImCard> onShareCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(conversation: conversation),
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
  const _ChatHeader({required this.conversation});

  final ImConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
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
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('这里会打开频道工具和应用安装管理')));
            },
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
    required this.onShareCard,
  });

  final ImMessage message;
  final ValueChanged<ImCard> onOpenCard;
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
    required this.onShareCard,
  });

  final ImCard card;
  final ValueChanged<ImCard> onOpenCard;
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
                hintText: '输入消息，或输入 /campaign 触发动态能力',
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

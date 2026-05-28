enum ImConversationType { direct, group, channel, bot }

enum ImMessageKind { text, system, card }

class ImConversation {
  const ImConversation({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.avatarText,
    required this.unreadCount,
    required this.memberCount,
  });

  final String id;
  final String title;
  final ImConversationType type;
  final String description;
  final String avatarText;
  final int unreadCount;
  final int memberCount;
}

class ImMessage {
  const ImMessage({
    required this.id,
    required this.conversationId,
    required this.senderName,
    required this.sentAt,
    required this.kind,
    this.text,
    this.card,
    this.isMine = false,
  });

  final String id;
  final String conversationId;
  final String senderName;
  final String sentAt;
  final ImMessageKind kind;
  final String? text;
  final ImCard? card;
  final bool isMine;
}

class ImCard {
  const ImCard({
    required this.template,
    required this.title,
    required this.subtitle,
    required this.primaryAction,
    required this.secondaryAction,
    required this.payload,
  });

  final String template;
  final String title;
  final String subtitle;
  final String primaryAction;
  final String secondaryAction;
  final Map<String, String> payload;
}

class ImCommand {
  const ImCommand({
    required this.name,
    required this.description,
    required this.scope,
  });

  final String name;
  final String description;
  final String scope;
}

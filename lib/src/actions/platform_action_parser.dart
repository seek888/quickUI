import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

class PlatformAction {
  const PlatformAction({
    required this.capability,
    this.title,
    this.message,
    this.payload = const {},
  });

  factory PlatformAction.fromJson(Map<String, dynamic> json) {
    return PlatformAction(
      capability: json['capability'] as String? ?? 'unknown',
      title: json['title'] as String?,
      message: json['message'] as String?,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    );
  }

  final String capability;
  final String? title;
  final String? message;
  final Map<String, dynamic> payload;
}

class PlatformActionParser extends StacActionParser<PlatformAction> {
  const PlatformActionParser();

  @override
  String get actionType => 'platform';

  @override
  PlatformAction getModel(Map<String, dynamic> json) =>
      PlatformAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(BuildContext context, PlatformAction model) {
    switch (model.capability) {
      case 'openChat':
        return _showCapabilityDialog(
          context,
          icon: Icons.chat_bubble_outline,
          title: model.title ?? '打开即时通讯',
          message: model.message ?? '这里会进入单聊、群聊或客服会话。',
          payload: model.payload,
        );
      case 'shareArticle':
        return _showCapabilityDialog(
          context,
          icon: Icons.ios_share_outlined,
          title: model.title ?? '分享内容',
          message: model.message ?? '这里会弹出客户端原生分享面板。',
          payload: model.payload,
        );
      case 'followAuthor':
        _showSnackBar(context, model.message ?? '已通过平台 action 模拟关注作者');
        return null;
      case 'submitForm':
        return _showCapabilityDialog(
          context,
          icon: Icons.check_circle_outline,
          title: model.title ?? '提交动态表单',
          message: model.message ?? '这里会由客户端网关提交表单数据。',
          payload: model.payload,
        );
      case 'requestPermission':
        return _showCapabilityDialog(
          context,
          icon: Icons.verified_user_outlined,
          title: model.title ?? '能力授权',
          message: model.message ?? '这里会展示平台能力申请和用户授权流程。',
          payload: model.payload,
        );
      default:
        _showSnackBar(context, '未注册的平台能力: ${model.capability}');
        return null;
    }
  }

  Future<void> _showCapabilityDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required Map<String, dynamic> payload,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(icon),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (payload.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payload.entries
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

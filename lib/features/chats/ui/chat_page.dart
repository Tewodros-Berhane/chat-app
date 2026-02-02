import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/color_utils.dart';
import '../../users/data/user_service.dart';
import '../data/chat_service.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.roomId,
    this.room,
  });

  final String roomId;
  final types.Room? room;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<types.Room>(
      stream: room == null
          ? ChatService.instance.roomStream(roomId).take(1)
          : null,
      initialData: room,
      builder: (context, snapshot) {
        final activeRoom = snapshot.data ?? room;
        if (activeRoom == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final title = _roomTitle(activeRoom);
        final avatarColor = colorFromId(activeRoom.id);

        final otherUserId = _otherUserId(activeRoom);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/chats');
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: avatarColor.withAlpha(38),
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: avatarColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (otherUserId != null && otherUserId.isNotEmpty)
                        StreamBuilder<Map<String, dynamic>?>(
                          stream: UserService.instance
                              .userDocStream(otherUserId),
                          builder: (context, snapshot) {
                            final data = snapshot.data;
                            final isOnline = data?['isOnline'] == true;
                            final lastSeen = data?['lastSeen'];
                            String subtitle;
                            if (isOnline) {
                              subtitle = 'Online';
                            } else if (lastSeen is Timestamp) {
                              final date = lastSeen.toDate();
                              final hour = date.hour.toString().padLeft(2, '0');
                              final minute =
                                  date.minute.toString().padLeft(2, '0');
                              subtitle = 'Last seen $hour:$minute';
                            } else {
                              subtitle = 'Offline';
                            }
                            return Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(140),
                                  ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: _MessagesView(room: activeRoom),
        );
      },
    );
  }

  String _roomTitle(types.Room room) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (room.name != null && room.name!.trim().isNotEmpty) {
      return room.name!.trim();
    }
    if (room.type == types.RoomType.direct && currentUserId != null) {
      final otherUser = room.users.firstWhere(
        (user) => user.id != currentUserId,
        orElse: () => const types.User(id: ''),
      );
      final name = '${otherUser.firstName ?? ''} ${otherUser.lastName ?? ''}'
          .trim();
      return name.isNotEmpty ? name : 'Chat';
    }
    return 'Chat';
  }

  String? _otherUserId(types.Room room) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return null;
    if (room.type != types.RoomType.direct) return null;
    return room.users
        .firstWhere(
          (user) => user.id != currentUserId,
          orElse: () => const types.User(id: ''),
        )
        .id;
  }
}

class _MessagesView extends StatefulWidget {
  const _MessagesView({required this.room});

  final types.Room room;

  @override
  State<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<_MessagesView> {
  Timer? _typingTimer;

  @override
  void dispose() {
    _typingTimer?.cancel();
    ChatService.instance.setTyping(roomId: widget.room.id, isTyping: false);
    super.dispose();
  }

  String _formatMessageTime(int? milliseconds) {
    if (milliseconds == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _statusIcon(types.Status? status) {
    switch (status) {
      case types.Status.sent:
        return const Icon(
          Icons.done_rounded,
          size: 14,
          color: Colors.white,
        );
      case types.Status.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.white,
        );
      case types.Status.seen:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Color(0xFF7DD3FC),
        );
      case types.Status.sending:
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case types.Status.error:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Colors.white,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  double _dynamicMaxWidth(
    BuildContext context,
    types.Message message,
    double baseMaxWidth,
  ) {
    if (message is! types.TextMessage) return baseMaxWidth;
    final length = message.text.length;
    final clamped = length.clamp(4, 120);
    final estimated = 120 + (clamped * 6.2);
    return estimated > baseMaxWidth ? baseMaxWidth : estimated;
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final user = types.User(
      id: authUser?.uid ?? '',
      firstName: authUser?.displayName,
      imageUrl: authUser?.photoURL,
    );

    return StreamBuilder<List<types.Message>>(
      stream: ChatService.instance.messagesStream(widget.room),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];
        if (messages.isNotEmpty) {
          ChatService.instance.markMessagesSeen(
            roomId: widget.room.id,
            messages: messages,
          );
        }
        final screenWidth = MediaQuery.of(context).size.width;
        final widthRatio = screenWidth < 480
            ? 0.74
            : screenWidth < 900
                ? 0.62
                : 0.52;

        return StreamBuilder<List<types.User>>(
          stream: ChatService.instance.typingUsersStream(widget.room),
          builder: (context, typingSnapshot) {
            final typingUsers = typingSnapshot.data ?? [];

            return Chat(
              messages: messages,
              messageWidthRatio: widthRatio,
              inputOptions: InputOptions(
                onTextChanged: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) {
                    ChatService.instance.setTyping(
                      roomId: widget.room.id,
                      isTyping: true,
                    );
                    _typingTimer?.cancel();
                    _typingTimer = Timer(const Duration(seconds: 2), () {
                      ChatService.instance.setTyping(
                        roomId: widget.room.id,
                        isTyping: false,
                      );
                    });
                  } else {
                    ChatService.instance.setTyping(
                      roomId: widget.room.id,
                      isTyping: false,
                    );
                  }
                },
              ),
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: typingUsers,
                typingWidgetBuilder: ({
                  required BuildContext context,
                  required TypingIndicator widget,
                  required TypingIndicatorMode mode,
                }) =>
                    const SizedBox.shrink(),
              ),
              customStatusBuilder: (_, {required BuildContext context}) =>
                  const SizedBox.shrink(),
              textMessageBuilder: (message,
                  {required int messageWidth, required bool showName}) {
                final isMe = message.author.id == user.id;
                final time = _formatMessageTime(message.createdAt);
                final textColor = isMe ? Colors.white : AppColors.ink;
                final metaColor = isMe
                    ? Colors.white.withAlpha(200)
                    : Theme.of(context).colorScheme.onSurface.withAlpha(140);
                final baseMax = MediaQuery.of(context).size.width * widthRatio;
                final maxWidth = _dynamicMaxWidth(context, message, baseMax);

                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: metaColor,
                                      fontSize: 11,
                                    ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                _statusIcon(message.status),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onSendPressed: (partial) {
                ChatService.instance.sendTextMessage(
                  roomId: widget.room.id,
                  text: partial.text,
                );
                ChatService.instance.setTyping(
                  roomId: widget.room.id,
                  isTyping: false,
                );
              },
              user: user,
              theme: DefaultChatTheme(
                primaryColor: AppColors.primary,
                secondaryColor: Colors.white,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                inputBackgroundColor: Colors.white,
                inputBorderRadius: BorderRadius.circular(24),
                inputTextColor: Theme.of(context).colorScheme.onSurface,
                sendButtonIcon: const Icon(Icons.send_rounded),
                messageBorderRadius: 22,
                attachmentButtonIcon: const Icon(Icons.add_rounded),
                statusIconPadding: EdgeInsets.zero,
              ),
              showUserAvatars: false,
              showUserNames: false,
            );
          },
        );
      },
    );
  }
}

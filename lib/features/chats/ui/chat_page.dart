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
  types.Message? _replyTo;

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

  void _setReply(types.Message message) {
    setState(() {
      _replyTo = message;
    });
  }

  void _clearAction() {
    setState(() {
      _replyTo = null;
    });
  }

  Future<void> _handleDelete(types.TextMessage message, bool isLast) async {
    await ChatService.instance.deleteMessage(
      roomId: widget.room.id,
      message: message,
      updateRoomLast: isLast,
    );
  }

  Future<void> _handleEdit(
    types.TextMessage message,
    String text,
    bool isLast,
  ) async {
    await ChatService.instance.editTextMessage(
      roomId: widget.room.id,
      message: message,
      newText: text,
      updateRoomLast: isLast,
    );
  }

  Future<void> _showEditDialog(
    types.TextMessage message,
    bool isLast,
  ) async {
    final controller = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Update your message',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                controller.text.trim(),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    await _handleEdit(message, result, isLast);
  }

  void _showMessageActions(types.Message message, List<types.Message> messages) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMine = currentUserId != null && message.author.id == currentUserId;
    final isText = message is types.TextMessage;
    final isLast = messages.isNotEmpty && messages.first.id == message.id;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _setReply(message);
                },
              ),
              if (isMine && isText)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(message, isLast);
                  },
                ),
              if (isMine && isText)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleDelete(message, isLast);
                  },
                ),
            ],
          ),
        );
      },
    );
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
              onMessageLongPress: (context, message) =>
                  _showMessageActions(message, messages),
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
              listBottomWidget: _replyTo != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Replying to ${_replyTo?.author.firstName ?? 'Message'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _replyTo is types.TextMessage
                                        ? (_replyTo as types.TextMessage).text
                                        : 'Message',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withAlpha(160),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _clearAction,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
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
                final reply = message.metadata?['replyTo'];
                final replyText = reply is Map<String, dynamic>
                    ? reply['text'] as String?
                    : null;
                final replyAuthor = reply is Map<String, dynamic>
                    ? reply['authorName'] as String?
                    : null;
                final isDeleted = message.metadata?['deleted'] == true;
                final isEdited = message.metadata?['edited'] == true;

                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyText != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withAlpha(40)
                                  : Colors.black.withAlpha(12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  replyAuthor ?? 'Reply',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.ink,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  replyText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isMe
                                            ? Colors.white.withAlpha(200)
                                            : AppColors.ink,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          isDeleted ? 'Message deleted' : message.text,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    fontStyle: isDeleted
                                        ? FontStyle.italic
                                        : FontStyle.normal,
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
                              if (isEdited) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'edited',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: metaColor,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              ],
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
                final trimmed = partial.text.trim();
                if (trimmed.isEmpty) return;
                final replyTo = _replyTo;
                ChatService.instance.sendTextMessage(
                  room: widget.room,
                  text: trimmed,
                  replyTo: replyTo is types.TextMessage
                      ? {
                          'id': replyTo.id,
                          'text': replyTo.text,
                          'authorId': replyTo.author.id,
                          'authorName': replyTo.author.firstName ?? 'User',
                        }
                      : null,
                );
                _clearAction();
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
                bubbleMargin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

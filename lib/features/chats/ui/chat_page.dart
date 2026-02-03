import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
          backgroundColor: const Color(0xFFECE5DD),
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
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Video',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Call',
              ),
            ],
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
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  bool _canSend = false;
  static const double _inputBarHeight = 64;
  static const double _emojiPanelHeight = 280;
  late final Stream<List<types.Message>> _messagesStream;
  late final Stream<List<types.User>> _typingUsersStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = ChatService.instance.messagesStream(widget.room);
    _typingUsersStream = ChatService.instance.typingUsersStream(widget.room);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    ChatService.instance.setTyping(roomId: widget.room.id, isTyping: false);
    _textController.dispose();
    _textFocusNode.dispose();
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
          color: Color(0xFF9AA0A6),
        );
      case types.Status.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Color(0xFF9AA0A6),
        );
      case types.Status.seen:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Color(0xFF53BDEB),
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

  void _handleTextChanged(String value) {
    final trimmed = value.trim();
    if (_canSend != (trimmed.isNotEmpty)) {
      setState(() => _canSend = trimmed.isNotEmpty);
    }

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
  }

  void _sendCurrentText() {
    final trimmed = _textController.text.trim();
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
    _textController.clear();
    setState(() => _canSend = false);
    _clearAction();
    ChatService.instance.setTyping(
      roomId: widget.room.id,
      isTyping: false,
    );
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _textFocusNode.requestFocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  Future<void> _handleAttachment() async {
    // TODO: Implement attachment picking + upload once Firebase Storage
    // is enabled for this project.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachments coming soon.')),
    );
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
    final theme = Theme.of(context);

    return StreamBuilder<List<types.Message>>(
      stream: _messagesStream,
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
          stream: _typingUsersStream,
          builder: (context, typingSnapshot) {
            final typingUsers = typingSnapshot.data ?? [];

            return Stack(
              children: [
                Chat(
                  messages: messages,
                  messageWidthRatio: widthRatio,
                  customBottomWidget: _ChatInputBar(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    canSend: _canSend,
                    showEmojiPicker: _showEmojiPicker,
                    onAttachmentPressed: _handleAttachment,
                    onEmojiPressed: _toggleEmojiPicker,
                    onSendPressed: _sendCurrentText,
                    onTextChanged: _handleTextChanged,
                    onTextFieldTap: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
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
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying to ${_replyTo?.author.firstName ?? 'Message'}',
                                        style:
                                            theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _replyTo is types.TextMessage
                                            ? (_replyTo as types.TextMessage)
                                                .text
                                            : 'Message',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
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
                  bubbleBuilder: (child,
                  {required types.Message message,
                  required bool nextMessageInGroup}) {
                final isMe = message.author.id == user.id;
                final color =
                    isMe ? const Color(0xFFDCF8C6) : Colors.white;
                return Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
                  onMessageLongPress: (context, message) =>
                      _showMessageActions(message, messages),
                  onBackgroundTap: () {
                    if (_showEmojiPicker) {
                      setState(() => _showEmojiPicker = false);
                    }
                  },
                  inputOptions: InputOptions(
                    onTextChanged: (value) {
                      _handleTextChanged(value);
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
                final textColor = AppColors.ink;
                final metaColor =
                    Theme.of(context).colorScheme.onSurface.withAlpha(140);
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
                              color: const Color(0xFFE7F3E0),
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
                                        color: AppColors.ink,
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
                                        color: AppColors.ink,
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
                  onSendPressed: (_) => _sendCurrentText(),
                  user: user,
                  theme: DefaultChatTheme(
                primaryColor: const Color(0xFFDCF8C6),
                secondaryColor: Colors.white,
                backgroundColor: const Color(0xFFECE5DD),
                bubbleMargin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                inputBackgroundColor: Colors.white,
                inputBorderRadius: BorderRadius.circular(24),
                inputTextColor: Theme.of(context).colorScheme.onSurface,
                inputContainerDecoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                inputMargin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                inputPadding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                inputTextDecoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                sendButtonIcon: const Icon(Icons.mic_rounded),
                sendButtonMargin: const EdgeInsets.only(left: 8),
                messageBorderRadius: 16,
                attachmentButtonIcon: const Icon(Icons.add),
                attachmentButtonMargin: const EdgeInsets.only(right: 6),
                statusIconPadding: EdgeInsets.zero,
              ),
                  showUserAvatars: false,
                  showUserNames: false,
                ),
                if (_showEmojiPicker)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _inputBarHeight,
                    child: SizedBox(
                      height: _emojiPanelHeight,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _textController.text += emoji.emoji;
                          _textController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                          _handleTextChanged(_textController.text);
                        },
                        onBackspacePressed: () {
                          final text = _textController.text;
                          if (text.isEmpty) return;
                          _textController.text =
                              text.characters.skipLast(1).toString();
                          _textController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                          _handleTextChanged(_textController.text);
                        },
                        config: const Config(
                          emojiViewConfig: EmojiViewConfig(
                            columns: 8,
                            emojiSizeMax: 28,
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            backgroundColor: Color(0xFFF6F6F8),
                            recentsLimit: 28,
                            noRecents: Text(
                              'No recent emojis',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                          ),
                          categoryViewConfig: CategoryViewConfig(
                            initCategory: Category.SMILEYS,
                            recentTabBehavior: RecentTabBehavior.RECENT,
                            backgroundColor: Color(0xFFF6F6F8),
                            indicatorColor: Color(0xFF25D366),
                            iconColor: Color(0xFF9AA0A6),
                            iconColorSelected: Color(0xFF25D366),
                            backspaceColor: Color(0xFF25D366),
                          ),
                          skinToneConfig: SkinToneConfig(),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.showEmojiPicker,
    required this.onAttachmentPressed,
    required this.onEmojiPressed,
    required this.onSendPressed,
    required this.onTextChanged,
    required this.onTextFieldTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool showEmojiPicker;
  final VoidCallback onAttachmentPressed;
  final VoidCallback onEmojiPressed;
  final VoidCallback onSendPressed;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onTextFieldTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, insets > 0 ? 8 : 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onAttachmentPressed,
                icon: const Icon(Icons.add),
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
              IconButton(
                onPressed: onEmojiPressed,
                icon: Icon(
                  showEmojiPicker
                      ? Icons.keyboard_rounded
                      : Icons.emoji_emotions_outlined,
                ),
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onTextChanged,
                  onTap: onTextFieldTap,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                onPressed: canSend ? onSendPressed : null,
                icon: Icon(
                  canSend ? Icons.send_rounded : Icons.mic_rounded,
                ),
                color: canSend
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(150),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/color_utils.dart';
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
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
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
}

class _MessagesView extends StatelessWidget {
  const _MessagesView({required this.room});

  final types.Room room;

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final user = types.User(
      id: authUser?.uid ?? '',
      firstName: authUser?.displayName,
      imageUrl: authUser?.photoURL,
    );

    return StreamBuilder<List<types.Message>>(
      stream: ChatService.instance.messagesStream(room),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];
        if (messages.isNotEmpty) {
          ChatService.instance.markMessagesSeen(
            roomId: room.id,
            messages: messages,
          );
        }
        return Chat(
          messages: messages,
          customStatusBuilder: (message, {required BuildContext context}) {
            switch (message.status) {
              case types.Status.sent:
                return const Icon(
                  Icons.done_rounded,
                  size: 16,
                  color: Colors.white,
                );
              case types.Status.delivered:
                return const Icon(
                  Icons.done_all_rounded,
                  size: 16,
                  color: Colors.white,
                );
              case types.Status.seen:
                return const Icon(
                  Icons.done_all_rounded,
                  size: 16,
                  color: Color(0xFF7DD3FC),
                );
              case types.Status.sending:
                return const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              case types.Status.error:
                return const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: Colors.white,
                );
              default:
                return const SizedBox.shrink();
            }
          },
          onSendPressed: (partial) {
            ChatService.instance.sendTextMessage(
              roomId: room.id,
              text: partial.text,
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
          ),
          showUserAvatars: false,
          showUserNames: false,
        );
      },
    );
  }
}

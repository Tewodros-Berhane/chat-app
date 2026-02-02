import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:go_router/go_router.dart';

import '../../../core/utils/color_utils.dart';
import '../../../core/utils/time_format.dart';
import '../../auth/data/auth_service.dart';
import '../data/chat_service.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  @override
  void initState() {
    super.initState();
    ChatService.instance.repairRoomsForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<types.Room>>(
        stream: ChatService.instance.roomsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load chats.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurface.withAlpha(153),
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data ?? [];
          if (rooms.isNotEmpty) {
            ChatService.instance.markLastMessagesDelivered(rooms);
          }
          if (rooms.isEmpty) {
            return _EmptyState(
              onStart: () => context.push('/new-chat'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return _RoomTile(room: room);
            },
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: rooms.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new-chat'),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New chat'),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});

  final types.Room room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final title = _roomTitle(room, currentUserId);
    final subtitle = _lastMessagePreview(room);
    final timeStamp = _roomTime(room);
    final avatarColor = colorFromId(room.id);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        context.push('/chat/${room.id}', extra: room);
      },
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor.withAlpha(38),
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: avatarColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(166),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              timeStamp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roomTitle(types.Room room, String? currentUserId) {
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
      return name.isNotEmpty ? name : 'Unknown user';
    }
    return 'Chat room';
  }

  String _lastMessagePreview(types.Room room) {
    final last = room.lastMessages?.isNotEmpty == true
        ? room.lastMessages!.first
        : null;

    if (last == null) return 'Start the conversation';

    if (last is types.TextMessage) return last.text;
    if (last is types.ImageMessage) return 'Photo message';
    if (last is types.FileMessage) return 'File attachment';
    return 'New message';
  }

  String _roomTime(types.Room room) {
    final last = room.lastMessages?.isNotEmpty == true
        ? room.lastMessages!.first
        : null;
    return formatCompactTime(room.updatedAt ?? last?.createdAt);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: theme.colorScheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No chats yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation and your rooms will show here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(166),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start new chat'),
            ),
          ],
        ),
      ),
    );
  }
}

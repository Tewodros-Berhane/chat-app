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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: AuthService.instance.signOut,
                    child: const Text('Edit'),
                  ),
                  const Spacer(),
                  Text(
                    'Chats',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/new-chat'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'New chat',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Broadcast Lists',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'New Group',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<types.Room>>(
                stream: ChatService.instance.roomsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load chats.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
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
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _RoomTile(room: room);
                    },
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemCount: rooms.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        onChatsTap: () {},
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
    final unreadCount = _unreadCount(room, currentUserId);
    final lastMessage = _lastMessage(room);
    final avatarColor = colorFromId(room.id);
    final avatarUrl = _otherUserAvatar(room, currentUserId);

    return InkWell(
      onTap: () => context.push('/chat/${room.id}', extra: room),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor.withAlpha(38),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: avatarColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
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
                  Row(
                    children: [
                      if (lastMessage != null &&
                          lastMessage.author.id == currentUserId)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _statusIcon(theme, lastMessage.status),
                        ),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStamp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
                const SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withAlpha(120),
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
    final last = _lastMessage(room);

    if (last == null) return 'Start the conversation';

    if (last is types.TextMessage) return last.text;
    if (last is types.ImageMessage) return 'Photo message';
    if (last is types.FileMessage) return 'File attachment';
    return 'New message';
  }

  String _roomTime(types.Room room) {
    final last = _lastMessage(room);
    return formatCompactTime(room.updatedAt ?? last?.createdAt);
  }

  int _unreadCount(types.Room room, String? currentUserId) {
    if (currentUserId == null) return 0;
    final data = room.metadata;
    if (data is Map<String, dynamic>) {
      final counts = data['unreadCounts'];
      if (counts is Map<String, dynamic>) {
        final raw = counts[currentUserId];
        if (raw is int) return raw;
      }
    }
    final last = _lastMessage(room);
    if (last == null) return 0;
    if (last.author.id == currentUserId) return 0;
    return last.status != types.Status.seen ? 1 : 0;
  }

  types.Message? _lastMessage(types.Room room) {
    return room.lastMessages?.isNotEmpty == true
        ? room.lastMessages!.first
        : null;
  }

  String? _otherUserAvatar(types.Room room, String? currentUserId) {
    if (room.type != types.RoomType.direct || currentUserId == null) return null;
    final otherUser = room.users.firstWhere(
      (user) => user.id != currentUserId,
      orElse: () => const types.User(id: ''),
    );
    return otherUser.imageUrl;
  }

  Widget _statusIcon(ThemeData theme, types.Status? status) {
    final muted = theme.colorScheme.onSurface.withAlpha(140);
    switch (status) {
      case types.Status.sent:
        return Icon(Icons.done_rounded, size: 16, color: muted);
      case types.Status.delivered:
        return Icon(Icons.done_all_rounded, size: 16, color: muted);
      case types.Status.seen:
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Color(0xFF7DD3FC),
        );
      case types.Status.sending:
        return Icon(Icons.schedule_rounded, size: 14, color: muted);
      case types.Status.error:
        return Icon(Icons.error_outline_rounded, size: 16, color: muted);
      default:
        return const SizedBox(width: 16);
    }
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onChatsTap});

  final VoidCallback onChatsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BottomNavigationBar(
      currentIndex: 2,
      onTap: (index) {
        if (index == 2) onChatsTap();
      },
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurface.withAlpha(140),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.radio_button_checked_rounded),
          label: 'Status',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.call_outlined),
          label: 'Calls',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt_outlined),
          label: 'Camera',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    );
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

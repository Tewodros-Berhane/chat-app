import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:go_router/go_router.dart';

import '../features/auth/ui/auth_page.dart';
import '../features/chats/ui/chat_page.dart';
import '../features/chats/ui/chats_page.dart';
import '../features/chats/ui/new_chat_page.dart';
import '../features/users/data/user_service.dart';
import '../features/users/ui/profile_page.dart';

class AppRouter {
  static final AuthStateNotifier authNotifier = AuthStateNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: '/auth',
    refreshListenable: authNotifier,
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/chats',
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatsPage(),
      ),
      GoRoute(
        path: '/new-chat',
        builder: (context, state) => const NewChatPage(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? '';
          final extra = state.extra;
          final room = extra is types.Room ? extra : null;
          return ChatPage(roomId: roomId, room: room);
        },
      ),
    ],
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.uri.path;
      final isLoggingIn = location == '/auth';
      final isProfile = location == '/profile';

      if (user == null) {
        return isLoggingIn ? null : '/auth';
      }

      final profileComplete =
          await UserService.instance.isProfileComplete(user.uid);

      if (!profileComplete) {
        return isProfile ? null : '/profile';
      }

      if (isLoggingIn || isProfile) {
        return '/chats';
      }

      return null;
    },
  );
}

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

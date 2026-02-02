import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();
  final Set<String> _statusUpdatedMessages = {};

  Stream<List<types.Room>> roomsStream() {
    return FirebaseChatCore.instance.rooms(orderByUpdatedAt: false);
  }

  Stream<types.Room> roomStream(String roomId) {
    return FirebaseChatCore.instance.room(roomId);
  }

  Stream<List<types.Message>> messagesStream(types.Room room) {
    return FirebaseChatCore.instance.messages(room);
  }

  Future<types.Room> createOrGetDirectRoom(types.User otherUser) {
    return FirebaseChatCore.instance.createRoom(otherUser);
  }

  Future<void> sendTextMessage({
    required String roomId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final messageRef =
        firestore.collection('rooms/$roomId/messages').doc();

    final now = FieldValue.serverTimestamp();
    final nowTimestamp = Timestamp.now();
    final messageMap = <String, dynamic>{
      'authorId': user.uid,
      'createdAt': now,
      'updatedAt': now,
      'text': trimmed,
      'type': 'text',
      'status': types.Status.sent.name,
      'showStatus': true,
    };

    final lastMessageMap = <String, dynamic>{
      'authorId': user.uid,
      'createdAt': nowTimestamp,
      'updatedAt': nowTimestamp,
      'text': trimmed,
      'type': 'text',
      'id': messageRef.id,
      'status': types.Status.sent.name,
      'showStatus': true,
    };

    final batch = firestore.batch();
    batch.set(messageRef, messageMap);
    batch.update(
      firestore.collection('rooms').doc(roomId),
      {
        'updatedAt': now,
        'lastMessages': [lastMessageMap],
      },
    );
    await batch.commit();
  }

  Future<void> markMessagesSeen({
    required String roomId,
    required List<types.Message> messages,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final updates = <DocumentReference, Map<String, dynamic>>{};

    for (final message in messages) {
      if (message.author.id == user.uid) continue;
      if (message.status == types.Status.seen) continue;
      if (_statusUpdatedMessages.contains(message.id)) continue;

      _statusUpdatedMessages.add(message.id);
      updates[firestore.collection('rooms/$roomId/messages').doc(message.id)] =
          {
        'status': types.Status.seen.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    if (updates.isEmpty) return;

    final batch = firestore.batch();
    updates.forEach(batch.update);
    await batch.commit();
  }

  Future<void> markLastMessagesDelivered(List<types.Room> rooms) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final updates = <DocumentReference, Map<String, dynamic>>{};

    for (final room in rooms) {
      if (room.lastMessages == null || room.lastMessages!.isEmpty) continue;
      final last = room.lastMessages!.first;
      if (last.author.id == user.uid) continue;
      if (last.status == types.Status.delivered ||
          last.status == types.Status.seen) {
        continue;
      }
      if (_statusUpdatedMessages.contains(last.id)) continue;

      _statusUpdatedMessages.add(last.id);
      updates[firestore.collection('rooms/${room.id}/messages').doc(last.id)] =
          {
        'status': types.Status.delivered.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    if (updates.isEmpty) return;

    final batch = firestore.batch();
    updates.forEach(batch.update);
    await batch.commit();
  }

  Future<void> repairRoomsForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('rooms')
        .where('userIds', arrayContains: user.uid)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      var changed = false;
      final updates = <String, dynamic>{};

      final createdAt = data['createdAt'];
      if (createdAt is int) {
        updates['createdAt'] =
            Timestamp.fromMillisecondsSinceEpoch(createdAt);
        changed = true;
      }

      final updatedAt = data['updatedAt'];
      if (updatedAt is int) {
        updates['updatedAt'] =
            Timestamp.fromMillisecondsSinceEpoch(updatedAt);
        changed = true;
      }

      final lastMessages = data['lastMessages'];
      if (lastMessages is List) {
        final converted = <Map<String, dynamic>>[];
        var lastChanged = false;
        for (final item in lastMessages) {
          if (item is Map<String, dynamic>) {
            final msg = Map<String, dynamic>.from(item);
            final lmCreated = msg['createdAt'];
            if (lmCreated is int) {
              msg['createdAt'] =
                  Timestamp.fromMillisecondsSinceEpoch(lmCreated);
              lastChanged = true;
            }
            final lmUpdated = msg['updatedAt'];
            if (lmUpdated is int) {
              msg['updatedAt'] =
                  Timestamp.fromMillisecondsSinceEpoch(lmUpdated);
              lastChanged = true;
            }
            converted.add(msg);
          }
        }
        if (lastChanged) {
          updates['lastMessages'] = converted;
          changed = true;
        }
      }

      if (changed) {
        await doc.reference.update(updates);
      }
    }
  }
}

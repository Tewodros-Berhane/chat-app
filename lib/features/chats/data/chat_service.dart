import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();
  final Map<String, types.Status> _statusUpdatedMessages = {};

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
    required types.Room room,
    required String text,
    Map<String, dynamic>? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final roomId = room.id;
    final messageRef = firestore.collection('rooms/$roomId/messages').doc();

    final now = FieldValue.serverTimestamp();
    final nowTimestamp = Timestamp.now();
    final replyMap =
        replyTo != null ? {'metadata': {'replyTo': replyTo}} : null;
    final messageMap = <String, dynamic>{
      'authorId': user.uid,
      'createdAt': now,
      'updatedAt': now,
      'text': trimmed,
      'type': 'text',
      'status': types.Status.sent.name,
      'showStatus': true,
      ...?replyMap,
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
    final roomRef = firestore.collection('rooms').doc(roomId);
    final unreadUpdates = <String, dynamic>{};
    for (final u in room.users) {
      if (u.id == user.uid) continue;
      unreadUpdates['metadata.unreadCounts.${u.id}'] =
          FieldValue.increment(1);
    }
    batch.update(
      roomRef,
      {
        'updatedAt': now,
        'lastMessages': [lastMessageMap],
        ...unreadUpdates,
      },
    );
    await batch.commit();
  }

  Future<void> sendFileMessage({
    required types.Room room,
    required PlatformFile file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (file.bytes == null) {
      throw StateError('Selected file data is unavailable.');
    }

    final firestore = FirebaseFirestore.instance;
    final roomId = room.id;
    final messageRef = firestore.collection('rooms/$roomId/messages').doc();
    final fileId = messageRef.id;
    final storagePath =
        'chat_uploads/$roomId/${user.uid}/$fileId-${file.name}';

    final mimeType = lookupMimeType(
      file.name,
      headerBytes: file.bytes,
    );
    final isImage = mimeType?.startsWith('image/') ?? false;

    final storageRef = FirebaseStorage.instance.ref(storagePath);
    final metadata = SettableMetadata(contentType: mimeType);
    await storageRef.putData(file.bytes!, metadata);
    final downloadUrl = await storageRef.getDownloadURL();

    final now = FieldValue.serverTimestamp();
    final nowTimestamp = Timestamp.now();
    final mimeTypeMap = mimeType != null ? {'mimeType': mimeType} : null;
    final messageMap = <String, dynamic>{
      'authorId': user.uid,
      'createdAt': now,
      'updatedAt': now,
      'type': isImage ? 'image' : 'file',
      'status': types.Status.sent.name,
      'showStatus': true,
      'uri': downloadUrl,
      'name': file.name,
      'size': file.size,
      ...?mimeTypeMap,
    };

    final previewText = isImage ? 'Photo' : 'File attachment';
    final lastMessageMap = <String, dynamic>{
      'authorId': user.uid,
      'createdAt': nowTimestamp,
      'updatedAt': nowTimestamp,
      'type': isImage ? 'image' : 'file',
      'id': messageRef.id,
      'status': types.Status.sent.name,
      'showStatus': true,
      'text': previewText,
      'uri': downloadUrl,
      'name': file.name,
      'size': file.size,
      ...?mimeTypeMap,
    };

    final batch = firestore.batch();
    batch.set(messageRef, messageMap);
    final roomRef = firestore.collection('rooms').doc(roomId);
    final unreadUpdates = <String, dynamic>{};
    for (final u in room.users) {
      if (u.id == user.uid) continue;
      unreadUpdates['metadata.unreadCounts.${u.id}'] =
          FieldValue.increment(1);
    }
    batch.update(
      roomRef,
      {
        'updatedAt': now,
        'lastMessages': [lastMessageMap],
        ...unreadUpdates,
      },
    );
    await batch.commit();
  }

  Future<void> editTextMessage({
    required String roomId,
    required types.TextMessage message,
    required String newText,
    required bool updateRoomLast,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final messageRef =
        firestore.collection('rooms/$roomId/messages').doc(message.id);
    await messageRef.update({
      'text': newText,
      'updatedAt': FieldValue.serverTimestamp(),
      'metadata.edited': true,
    });

    if (updateRoomLast) {
      await firestore.collection('rooms').doc(roomId).update({
        'lastMessages': [
          _lastMessageFrom(
            message.copyWith(text: newText),
            message.status ?? types.Status.sent,
          ),
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteMessage({
    required String roomId,
    required types.TextMessage message,
    required bool updateRoomLast,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final messageRef =
        firestore.collection('rooms/$roomId/messages').doc(message.id);
    await messageRef.update({
      'text': 'Message deleted',
      'updatedAt': FieldValue.serverTimestamp(),
      'metadata.deleted': true,
    });

    if (updateRoomLast) {
      await firestore.collection('rooms').doc(roomId).update({
        'lastMessages': [
          _lastMessageFrom(
            message.copyWith(text: 'Message deleted'),
            message.status ?? types.Status.sent,
          ),
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
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
      final tracked = _statusUpdatedMessages[message.id];
      if (tracked == types.Status.seen) continue;
      _statusUpdatedMessages[message.id] = types.Status.seen;
      updates[firestore.collection('rooms/$roomId/messages').doc(message.id)] =
          {
        'status': types.Status.seen.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    if (updates.isEmpty) return;

    final batch = firestore.batch();
    updates.forEach(batch.update);

    final latest = messages.isNotEmpty ? messages.first : null;
    if (latest != null &&
        latest.author.id != user.uid &&
        updates.containsKey(
          firestore.collection('rooms/$roomId/messages').doc(latest.id),
        )) {
      batch.update(
        firestore.collection('rooms').doc(roomId),
        {
          'lastMessages': [_lastMessageFrom(latest, types.Status.seen)],
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata.unreadCounts.${user.uid}': 0,
        },
      );
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('markMessagesSeen failed: $e');
    }
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
      final tracked = _statusUpdatedMessages[last.id];
      if (tracked == types.Status.delivered ||
          tracked == types.Status.seen) {
        continue;
      }
      _statusUpdatedMessages[last.id] = types.Status.delivered;
      final messageRef =
          firestore.collection('rooms/${room.id}/messages').doc(last.id);
      updates[messageRef] =
          {
        'status': types.Status.delivered.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    if (updates.isEmpty) return;

    final batch = firestore.batch();
    updates.forEach(batch.update);
    for (final room in rooms) {
      if (room.lastMessages == null || room.lastMessages!.isEmpty) continue;
      final last = room.lastMessages!.first;
      if (last.author.id == user.uid) continue;
      if (last.status == types.Status.delivered ||
          last.status == types.Status.seen) {
        continue;
      }
      batch.update(
        firestore.collection('rooms').doc(room.id),
        {
          'lastMessages': [_lastMessageFrom(last, types.Status.delivered)],
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('markLastMessagesDelivered failed: $e');
    }
  }

  Map<String, dynamic> _lastMessageFrom(
    types.Message message,
    types.Status status,
  ) {
    final createdAt = message.createdAt != null
        ? Timestamp.fromMillisecondsSinceEpoch(message.createdAt!)
        : Timestamp.now();
    final updatedAt = message.updatedAt != null
        ? Timestamp.fromMillisecondsSinceEpoch(message.updatedAt!)
        : Timestamp.now();

    if (message is types.TextMessage) {
      return {
        'authorId': message.author.id,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'text': message.text,
        'type': 'text',
        'id': message.id,
        'status': status.name,
        'showStatus': true,
      };
    }

    if (message is types.ImageMessage) {
      final mimeType = message.metadata?['mimeType'];
      final mimeTypeMap = mimeType != null ? {'mimeType': mimeType} : null;
      return {
        'authorId': message.author.id,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'type': 'image',
        'id': message.id,
        'status': status.name,
        'showStatus': true,
        'text': 'Photo',
        'uri': message.uri,
        'name': message.name,
        'size': message.size,
        ...?mimeTypeMap,
      };
    }

    if (message is types.FileMessage) {
      final mimeType = message.metadata?['mimeType'];
      final mimeTypeMap = mimeType != null ? {'mimeType': mimeType} : null;
      return {
        'authorId': message.author.id,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'type': 'file',
        'id': message.id,
        'status': status.name,
        'showStatus': true,
        'text': 'File attachment',
        'uri': message.uri,
        'name': message.name,
        'size': message.size,
        ...?mimeTypeMap,
      };
    }

    return {
      'authorId': message.author.id,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'type': message.type.name,
      'id': message.id,
      'status': status.name,
      'showStatus': true,
    };
  }

  Stream<List<types.User>> typingUsersStream(types.Room room) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(room.id);

    return roomRef.snapshots().map((doc) {
      final data = doc.data();
      final typing = (data?['typing'] as Map<String, dynamic>?) ?? {};
      final typingAt = (data?['typingAt'] as Map<String, dynamic>?) ?? {};
      final now = DateTime.now();

      return room.users.where((user) {
        if (user.id == currentUserId) return false;
        final isTyping = typing[user.id] == true;
        if (!isTyping) return false;
        final raw = typingAt[user.id];
        DateTime? at;
        if (raw is Timestamp) {
          at = raw.toDate();
        } else if (raw is int) {
          at = DateTime.fromMillisecondsSinceEpoch(raw);
        }
        if (at == null) return true;
        return now.difference(at).inSeconds <= 6;
      }).toList();
    });
  }

  Future<void> setTyping({
    required String roomId,
    required bool isTyping,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    await roomRef.update({
      'typing.${user.uid}': isTyping,
      if (isTyping) 'typingAt.${user.uid}': FieldValue.serverTimestamp(),
    });
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

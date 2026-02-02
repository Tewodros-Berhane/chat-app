import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');

  final Map<String, bool> _profileCompleteCache = {};

  void invalidateProfileCache(String uid) {
    _profileCompleteCache.remove(uid);
  }

  Future<void> ensureUserDocument(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    final email = (user.email ?? '').trim();
    final displayName = (user.displayName ?? '').trim();
    final nameLower = displayName.toLowerCase();
    final emailLower = email.toLowerCase();

    if (!doc.exists) {
      await docRef.set({
        'id': user.uid,
        'firstName': displayName,
        'imageUrl': user.photoURL,
        'email': email,
        'searchName': nameLower,
        'searchEmail': emailLower,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      _profileCompleteCache[user.uid] = displayName.isNotEmpty;
      return;
    }

    await docRef.set({
      'email': email,
      'searchEmail': emailLower,
      'imageUrl': user.photoURL,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfileName(String uid, String name) async {
    final trimmed = name.trim();
    await _users.doc(uid).set({
      'firstName': trimmed,
      'searchName': trimmed.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _profileCompleteCache[uid] = trimmed.isNotEmpty;
  }

  Future<void> updateLastSeen(String uid) async {
    await _users.doc(uid).set({
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isProfileComplete(String uid) async {
    final cached = _profileCompleteCache[uid];
    if (cached != null) return cached;

    final doc = await _users.doc(uid).get();
    if (!doc.exists) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await ensureUserDocument(user);
      }
      _profileCompleteCache[uid] = false;
      return false;
    }

    final data = doc.data();
    final name = (data?['firstName'] as String? ?? '').trim();
    final isComplete = name.isNotEmpty;
    _profileCompleteCache[uid] = isComplete;
    return isComplete;
  }

  Future<String?> fetchDisplayName(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    final name = (data?['firstName'] as String? ?? '').trim();
    return name.isEmpty ? null : name;
  }

  Future<List<types.User>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final nameQuery = _users
        .where('searchName', isGreaterThanOrEqualTo: q)
        .where('searchName', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    final emailQuery = _users
        .where('searchEmail', isGreaterThanOrEqualTo: q)
        .where('searchEmail', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    final results = await Future.wait([nameQuery, emailQuery]);
    final Map<String, types.User> users = {};

    for (final snap in results) {
      for (final doc in snap.docs) {
        if (doc.id == currentUserId) continue;
        final user = _userFromDoc(doc);
        users[user.id] = user;
      }
    }

    final list = users.values.toList();
    list.sort((a, b) => (a.firstName ?? '').compareTo(b.firstName ?? ''));
    return list;
  }

  types.User _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return types.User(
      id: doc.id,
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      imageUrl: data['imageUrl'] as String?,
      metadata: {
        'email': data['email'],
      },
    );
  }
}

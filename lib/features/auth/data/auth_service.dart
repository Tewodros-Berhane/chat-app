import 'package:firebase_auth/firebase_auth.dart';

import '../../users/data/user_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await UserService.instance.updateLastSeen(user.uid);
      UserService.instance.invalidateProfileCache(user.uid);
    }
    await _auth.signOut();
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/local_store.dart';

class SessionService {
  SessionService._();
  static final instance = SessionService._();
  static const _secure = FlutterSecureStorage();
  static const _uidKey = 'offline_first_owner_uid';

  Future<User> ensureUser() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    final previousUid = await _secure.read(key: _uidKey);
    // No mostrar datos SQLite de una cuenta anterior en la nueva sesion.
    if (previousUid != null && previousUid != user.uid) {
      await LocalStore.instance.purge();
    }
    await _secure.write(key: _uidKey, value: user.uid);
    return user;
  }

  Future<void> logoutAndPurge() async {
    await FirebaseAuth.instance.signOut();
    await LocalStore.instance.purge();
    await _secure.delete(key: _uidKey);
  }
}

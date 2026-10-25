import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

/// Where the sign-in token is kept between app launches.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Stores the token in the device keychain/keystore.
class SecureTokenStore implements TokenStore {
  static const _key = 'member_api_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

enum SessionStatus { loading, signedOut, signedIn }

/// Signed-in state for the whole app.
class Session extends ChangeNotifier {
  Session({required this.api, required this.store}) {
    api.onUnauthorized = _expire;
  }

  final ApiClient api;
  final TokenStore store;

  SessionStatus status = SessionStatus.loading;
  Map<String, dynamic> member = const {};

  /// Shown on the sign-in screen after the server ends the session.
  String? notice;

  /// Restores a saved sign-in, checking with the server that it is still valid.
  Future<void> restore() async {
    String? saved;
    try {
      saved = await store.read();
    } catch (e) {
      // The keystore can be unreadable on a real device (for example after a backup restore).
      debugPrint('Could not read the saved sign-in: $e');
      await _clearStore();
    }
    if (saved == null || saved.isEmpty) {
      _set(SessionStatus.signedOut);
      return;
    }
    api.token = saved;
    try {
      final data = await api.get('me');
      member = Map<String, dynamic>.from(data['member'] as Map);
      _set(SessionStatus.signedIn);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _forget();
      } else {
        // Offline or server trouble: keep the member signed in and let screens retry.
        _set(SessionStatus.signedIn);
      }
    } catch (e) {
      // Never leave the app on the loading screen.
      debugPrint('Could not restore the sign-in: $e');
      _set(SessionStatus.signedIn);
    }
  }

  Future<void> signIn(String identifier, String password) async {
    final data = await api.post('login', {
      'identifier': identifier.trim(),
      'password': password,
      'device_name': 'Mobile app (${defaultTargetPlatform.name})',
    });
    final token = data['token'] as String;
    api.token = token;
    try {
      await store.write(token);
    } catch (e) {
      // Stay signed in for this launch even if the device cannot save the token.
      debugPrint('Could not save the sign-in: $e');
    }
    member = Map<String, dynamic>.from(data['member'] as Map);
    notice = null;
    _set(SessionStatus.signedIn);
  }

  /// Replaces the signed-in member's details after the member edits their profile.
  void updateMember(Map<String, dynamic> value) {
    member = value;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.post('logout', const {});
    } on ApiException {
      // Sign out on this device even if the server cannot be reached.
    }
    await _forget();
  }

  void _expire() {
    notice = 'Your session has ended. Please sign in again.';
    _forget();
  }

  Future<void> _forget() async {
    api.token = null;
    member = const {};
    await _clearStore();
    _set(SessionStatus.signedOut);
  }

  Future<void> _clearStore() async {
    try {
      await store.clear();
    } catch (e) {
      debugPrint('Could not clear the saved sign-in: $e');
    }
  }

  void _set(SessionStatus value) {
    status = value;
    notifyListeners();
  }
}

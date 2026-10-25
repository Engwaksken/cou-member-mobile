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
    final saved = await store.read();
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
    await store.write(token);
    member = Map<String, dynamic>.from(data['member'] as Map);
    notice = null;
    _set(SessionStatus.signedIn);
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
    await store.clear();
    _set(SessionStatus.signedOut);
  }

  void _set(SessionStatus value) {
    status = value;
    notifyListeners();
  }
}

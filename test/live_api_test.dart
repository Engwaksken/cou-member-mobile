// Runs the app's API client and session against a real member API.
// Skipped unless a URL is given, for example:
//   flutter test test/live_api_test.dart --dart-define=LIVE_API_URL=http://127.0.0.1:8767/api/member/ \
//     --dart-define=LIVE_MEMBER_NO=RCOU-2026-0001 --dart-define=LIVE_PLEDGE_NO=P-001 --dart-define=LIVE_PASSWORD=...
import 'package:cou_member_app/core/api_client.dart';
import 'package:cou_member_app/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show MemoryTokenStore;

const liveUrl = String.fromEnvironment('LIVE_API_URL');
const memberNo = String.fromEnvironment('LIVE_MEMBER_NO');
const pledgeNo = String.fromEnvironment('LIVE_PLEDGE_NO');
const password = String.fromEnvironment('LIVE_PASSWORD');

void main() {
  final skip = liveUrl.isEmpty ? 'Set LIVE_API_URL to run against a real API' : null;

  Session newSession() => Session(api: ApiClient(baseUrl: liveUrl), store: MemoryTokenStore());

  test('signs in with the membership number and loads every screen', () async {
    final session = newSession();
    await session.signIn(memberNo, password);
    expect(session.member['member_no'], memberNo);
    final api = session.api;
    for (final call in [
      () => api.get('me'),
      () => api.get('dashboard'),
      () => api.get('pledges'),
      for (final t in ['offertory', 'tithe', 'thanksgiving', 'contributions']) () => api.get('giving', {'type': t}),
      () => api.get('announcements'),
      () => api.get('programs'),
      () => api.get('order_of_service'),
      () => api.get('hymns'),
      () => api.get('tips', {'dept': 'health'}),
      () => api.get('tips', {'dept': 'education'}),
    ]) {
      expect((await call())['success'], isTrue);
    }
    await session.signOut();
    expect(session.status, SessionStatus.signedOut);
  }, skip: skip);

  test('signs in with the pledge number', () async {
    final session = newSession();
    await session.signIn(pledgeNo, password);
    expect(session.member['pledge_no'], pledgeNo);
    await session.signOut();
  }, skip: skip);

  test('rejects a wrong password with the server message', () async {
    final session = newSession();
    await expectLater(
      session.signIn(memberNo, 'definitely-wrong'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  }, skip: skip);
}

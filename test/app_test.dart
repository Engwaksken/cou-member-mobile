import 'dart:convert';

import 'package:cou_member_app/core/api_client.dart';
import 'package:cou_member_app/core/session.dart';
import 'package:cou_member_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

const validToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const member = {'id': 1, 'member_no': 'RCOU-2026-0001', 'pledge_no': 'P-001', 'full_name': 'Mary Member'};

/// Fake API: accepts RCOU-2026-0001 or P-001 with password Member@123.
http.Response fakeApi(http.Request request, {bool expireToken = false}) {
  final action = request.url.queryParameters['action'];
  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  if (action == 'login') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final okId = ['RCOU-2026-0001', 'P-001'].contains(body['identifier']);
    if (okId && body['password'] == 'Member@123') return json(200, {'success': true, 'token': validToken, 'member': member});
    return json(401, {'success': false, 'message': 'The membership/pledge number or password is incorrect.'});
  }
  final auth = request.headers['Authorization'];
  if (expireToken || auth != 'Bearer $validToken') {
    return json(401, {'success': false, 'message': 'Your session has expired. Please sign in again.'});
  }
  return switch (action) {
    'me' => json(200, {'success': true, 'member': member, 'church': {'name': 'Rongoro COU'}}),
    'dashboard' => json(200, {
        'success': true,
        'member': member,
        'verses': [
          {'reference': 'Psalm 118:24', 'verse_text': 'This is the day which the LORD hath made.', 'translation': 'KJV', 'display_date': null},
        ],
        'pledges': {'total_pledged': 300000.0, 'total_paid': 100000.0, 'balance': 200000.0, 'open': 1},
        'announcements': [
          {'id': 1, 'title': 'Harvest Sunday', 'message': 'Bring your harvest gifts', 'priority': 'Important'},
        ],
        'programs': <Object>[],
      }),
    'logout' => json(200, {'success': true}),
    _ => json(404, {'success': false, 'message': 'Unknown action.'}),
  };
}

Session makeSession({String? savedToken, bool expireToken = false}) {
  final api = ApiClient(
    baseUrl: 'https://example.test/api/member/',
    httpClient: MockClient((r) async => fakeApi(r, expireToken: expireToken)),
  );
  return Session(api: api, store: MemoryTokenStore(savedToken));
}

Future<void> signIn(WidgetTester tester, String identifier, String password) async {
  await tester.enterText(find.byKey(const Key('identifier')), identifier);
  await tester.enterText(find.byKey(const Key('password')), password);
  await tester.tap(find.byKey(const Key('signIn')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows sign-in when no token is saved', (tester) async {
    final session = makeSession();
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    expect(find.text('Membership or pledge number'), findsOneWidget);
  });

  testWidgets('asks for both fields before contacting the server', (tester) async {
    final session = makeSession();
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.tap(find.byKey(const Key('signIn')));
    await tester.pump();
    expect(find.text('Enter your membership or pledge number.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('signs in with a membership number and shows the home page', (tester) async {
    final session = makeSession();
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await signIn(tester, 'RCOU-2026-0001', 'Member@123');

    expect(session.status, SessionStatus.signedIn);
    expect((session.store as MemoryTokenStore).token, validToken);
    expect(find.text('Welcome back, Mary'), findsOneWidget);
    expect(find.text('This is the day which the LORD hath made.'), findsOneWidget);
    expect(find.text('UGX 200,000'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Harvest Sunday'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Harvest Sunday'), findsOneWidget);
  });

  testWidgets('signs in with a pledge number', (tester) async {
    final session = makeSession();
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await signIn(tester, '  P-001 ', 'Member@123');
    expect(find.text('Welcome back, Mary'), findsOneWidget);
  });

  testWidgets('shows the server message for a wrong password', (tester) async {
    final session = makeSession();
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await signIn(tester, 'P-001', 'wrong');
    expect(session.status, SessionStatus.signedOut);
    expect(find.text('The membership/pledge number or password is incorrect.'), findsOneWidget);
  });

  testWidgets('restores a saved sign-in', (tester) async {
    final session = makeSession(savedToken: validToken);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Mary'), findsOneWidget);
  });

  testWidgets('an expired saved token returns to sign-in and is forgotten', (tester) async {
    final session = makeSession(savedToken: 'b' * 64);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    expect(find.text('Membership or pledge number'), findsOneWidget);
    expect((session.store as MemoryTokenStore).token, isNull);
  });

  testWidgets('a session ended by the server mid-use returns to sign-in with a notice', (tester) async {
    var expired = false;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/member/',
      httpClient: MockClient((r) async => fakeApi(r, expireToken: expired)),
    );
    final session = Session(api: api, store: MemoryTokenStore(validToken));
    await session.restore();
    expired = true;
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
    expect(find.text('Membership or pledge number'), findsOneWidget);
  });

  testWidgets('sign out from the profile tab returns to sign-in', (tester) async {
    final session = makeSession(savedToken: validToken);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Membership or pledge number'), findsOneWidget);
    expect((session.store as MemoryTokenStore).token, isNull);
  });
}

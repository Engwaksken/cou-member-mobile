import 'dart:convert';

import 'package:cou_member_app/core/api_client.dart';
import 'package:cou_member_app/core/push.dart';
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

/// Bodies sent to update_profile, for assertions.
final updatedProfiles = <Map<String, dynamic>>[];

/// Bodies sent to update_notification_settings, for assertions.
final savedNotificationSettings = <Map<String, dynamic>>[];

/// Whether the fake member has read their notifications.
var notificationsRead = false;

/// Mary's password on the fake server; reset_password changes it.
var memberPassword = 'Member@123';

/// Fake API: accepts RCOU-2026-0001 or P-001 with [memberPassword]; reset code 123456.
http.Response fakeApi(http.Request request, {bool expireToken = false}) {
  final action = request.url.queryParameters['action'];
  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  if (action == 'login') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final okId = ['RCOU-2026-0001', 'P-001'].contains(body['identifier']);
    if (okId && body['password'] == memberPassword) return json(200, {'success': true, 'token': validToken, 'member': member});
    return json(401, {'success': false, 'message': 'The membership/pledge number or password is incorrect.'});
  }
  if (action == 'forgot_password') {
    return json(200, {'success': true, 'message': 'A 6-digit code has been sent.'});
  }
  if (action == 'reset_password') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (body['code'] != '123456') return json(422, {'success': false, 'message': 'The code is incorrect or has expired. Check the code or request a new one.'});
    memberPassword = body['new_password'] as String;
    return json(200, {'success': true, 'message': 'Your password was reset.'});
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
    'notification_settings' => json(200, {
        'success': true,
        'categories': [
          {'key': 'announcements', 'label': 'Announcements', 'description': 'New church announcements', 'push': true, 'email': true, 'sms': false},
          {'key': 'payments', 'label': 'Payments received', 'description': 'Tithe and pledge payments', 'push': true, 'email': true, 'sms': false},
        ],
        'channels': {
          'push': {'available': true, 'note': null},
          'email': {'available': false, 'note': 'Add an email address to your profile to get emails.'},
          'sms': {'available': true, 'note': '0772 123456'},
        },
      }),
    'update_notification_settings' => () {
        savedNotificationSettings.add(jsonDecode(request.body) as Map<String, dynamic>);
        return json(200, {'success': true, 'message': 'Your notification settings were saved.'});
      }(),
    'notifications' => json(200, {
        'success': true,
        'unread': notificationsRead ? 0 : 1,
        'items': [
          {'id': 1, 'category': 'payments', 'title': 'Tithe received', 'body': 'We received your tithe of UGX 50,000.', 'created_at': '2026-10-31 09:00:00', 'read_at': notificationsRead ? '2026-10-31 10:00:00' : null},
        ],
      }),
    'mark_notifications_read' => () {
        notificationsRead = true;
        return json(200, {'success': true});
      }(),
    'pledges' => json(200, {'success': true, 'items': <Object>[]}),
    'giving' => request.url.queryParameters['type'] == 'good_samaritan'
        ? json(200, {
            'success': true,
            'type': 'good_samaritan',
            'total': 15000.0,
            'items': [
              {'id': 1, 'date': '2026-10-18', 'amount': 15000.0, 'reference': 'GS-2026-0001', 'description': 'Help for the Okello family', 'payment_method': 'Cash'},
            ],
          })
        : json(200, {'success': true, 'type': request.url.queryParameters['type'], 'total': 0.0, 'items': <Object>[]}),
    'zones' => json(200, {
        'success': true,
        'items': [
          {'id': 3, 'name': 'Central Zone'},
        ],
      }),
    'update_profile' => () {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        updatedProfiles.add(body);
        return json(200, {
          'success': true,
          'message': 'Your profile was updated.',
          'member': {...member, 'phone': body['phone'], 'church_zone_id': body['church_zone_id'], 'church_zone': 'Central Zone'},
        });
      }(),
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
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Membership or pledge number'), findsOneWidget);
    expect((session.store as MemoryTokenStore).token, isNull);
  });

  testWidgets('basket collections are not listed as Giving tabs', (tester) async {
    final session = makeSession(savedToken: validToken);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Rongoro COU · RCOU-2026-0001'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Contributions'), 100, scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)));
    await tester.tap(find.text('Contributions'));
    await tester.pumpAndSettle();
    expect(find.text('Offertory'), findsNothing);
    expect(find.text('Good Samaritan'), findsNothing);
    expect(find.text('My Giving'), findsOneWidget);
    expect(find.text('Contributions'), findsOneWidget);
  });

  testWidgets('edits phone and church zone from the profile', (tester) async {
    updatedProfiles.clear();
    final session = makeSession(savedToken: validToken);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('editProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editProfile')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('phone')), 'abc');
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pump();
    expect(find.text('Enter a valid phone number.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('phone')), '0772 123456');
    await tester.tap(find.text('Not set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central Zone').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();

    expect(updatedProfiles.single['phone'], '0772 123456');
    expect(updatedProfiles.single['church_zone_id'], 3);
    expect(find.text('My Profile'), findsOneWidget);
  });

  testWidgets('resets a forgotten password with a code and signs in', (tester) async {
    memberPassword = 'Member@123';
    addTearDown(() => memberPassword = 'Member@123');
    final session = makeSession();
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.enterText(find.byKey(const Key('identifier')), 'P-001');
    await tester.tap(find.byKey(const Key('forgotPassword')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'P-001'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sendCode')));
    await tester.pumpAndSettle();
    expect(find.text('A 6-digit code has been sent.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('resetCode')), '000000');
    await tester.enterText(find.byKey(const Key('resetNewPassword')), 'weak');
    await tester.enterText(find.byKey(const Key('resetConfirmPassword')), 'weak');
    await tester.ensureVisible(find.byKey(const Key('resetPassword')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetPassword')));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('resetNewPassword')), 'NewPass@2026');
    await tester.enterText(find.byKey(const Key('resetConfirmPassword')), 'NewPass@2026');
    await tester.ensureVisible(find.byKey(const Key('resetPassword')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetPassword')));
    await tester.pumpAndSettle();
    expect(find.text('The code is incorrect or has expired. Check the code or request a new one.'), findsOneWidget);
    expect(session.status, SessionStatus.signedOut);

    await tester.enterText(find.byKey(const Key('resetCode')), '123456');
    await tester.ensureVisible(find.byKey(const Key('resetPassword')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetPassword')));
    await tester.pumpAndSettle();
    expect(memberPassword, 'NewPass@2026');
    expect(session.status, SessionStatus.signedIn);
    expect(find.text('Welcome back, Mary'), findsOneWidget);
    expect(find.text('Reset password'), findsNothing);
  });

  testWidgets('chooses notification channels from the profile', (tester) async {
    savedNotificationSettings.clear();
    final session = makeSession(savedToken: validToken);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('openNotificationSettings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openNotificationSettings')));
    await tester.pumpAndSettle();

    expect(find.text('Notification settings'), findsOneWidget);
    expect(find.text('Add an email address to your profile to get emails.'), findsOneWidget);
    // Email is on but cannot reach the member, so it can still be turned off; SMS is available.
    await tester.tap(find.byKey(const Key('announcements-sms')));
    await tester.pumpAndSettle();
    expect(savedNotificationSettings.single['settings'], {
      'announcements': {'push': true, 'email': true, 'sms': true},
    });
    expect(tester.widget<FilterChip>(find.byKey(const Key('announcements-sms'))).selected, isTrue);
  });

  testWidgets('the bell shows unread notifications and opening them marks them read', (tester) async {
    notificationsRead = false;
    final session = makeSession(savedToken: validToken);
    session.onSignedIn = () => refreshUnread(session.api);
    await session.restore();
    await tester.pumpWidget(MemberApp(session: session));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('notificationBell')), matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notificationBell')));
    await tester.pumpAndSettle();
    expect(find.text('Tithe received'), findsOneWidget);
    expect(notificationsRead, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('notificationBell')), matching: find.text('1')), findsNothing);
  });
}

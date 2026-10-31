# Rongoro COU Member App

Flutter app for church members. Members sign in with their **membership number or pledge number**
and the same password they use on the church member website.

## What members can do
- **Home:** welcome, daily Bible verse, pledge summary, latest announcements, upcoming programs
- **Giving:** their own pledges (with payment history), tithe, thanksgiving and contributions. Offertory and Good Samaritan are collected in the basket.
- **Worship:** Order of Service (with links to hymns) and Church of Uganda hymns
- **Church:** announcements, upcoming programs, Health and Education department tips
- **Profile:** their details, change password (also changes the website password), sign out

- **Forgot password:** from the sign-in screen, the member enters their number, receives a 6-digit code by SMS and
  email (the phone and email on their member record), and sets a new password. They are then signed in.

The app is read-only apart from signing in/out, editing the profile and changing or resetting the password.

## Server
The app talks to the member API in the church website repository (`api/member/`). Before the app is used:
1. Deploy the website code that contains `api/member/`.
2. Run `database/member_mobile_api.sql` on the database (and `database/member_content.sql` for verses, hymns,
   Order of Service and tips).

Sign-in is locked for 15 minutes after 5 failed attempts for the same number (or 20 from one IP address).
Reset codes expire after 15 minutes and allow 5 tries; a number can request 3 codes an hour (10 per IP address).
Sending codes uses the website's SMTP settings and the active `sms_settings` row. A reset signs the member out of the app
on every device. Members with no phone or email on file still need the church office to reset their password.

Sign-in tokens last 90 days; deactivating a member or their login ends app access immediately.

## Development
```
flutter pub get
flutter run                                   # uses https://cou.kemmytech.com/api/member/
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/member/   # local server from the Android emulator
flutter analyze
flutter test                                  # widget tests (the live API test is skipped)
```

To test against a running API:
```
flutter test test/live_api_test.dart --dart-define=LIVE_API_URL=http://127.0.0.1:8000/api/member/ \
  --dart-define=LIVE_MEMBER_NO=<member no> --dart-define=LIVE_PLEDGE_NO=<pledge no> --dart-define=LIVE_PASSWORD=<password>
```

## Releasing
- Android package / iOS bundle id: `org.rongorocou.cou_member_app` (change in `android/app/build.gradle.kts`
  and the Xcode project before the first store upload if you prefer another id).
- Release builds are still signed with the debug key; set up a release keystore before uploading to Google Play.
- Replace the default Flutter launcher icon.

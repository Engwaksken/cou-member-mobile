/// App configuration.
///
/// Point the app at another server at build time, for example:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8767/api/member/`
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cou.kemmytech.com/api/member/',
  );

  static const String churchName = 'Rongoro COU';
}

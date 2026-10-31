import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

void main() {
  // Secure storage uses a platform channel, which needs the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final session = Session(api: api, store: SecureTokenStore())..restore();
  runApp(MemberApp(session: session));
}

class MemberApp extends StatelessWidget {
  const MemberApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        title: AppConfig.churchName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _Root(),
      ),
    );
  }
}

/// Shows sign-in or the app depending on the session.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<Session>().status;
    return switch (status) {
      SessionStatus.loading => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/logo.png', height: 96, cacheHeight: 288, semanticLabel: 'Church of Uganda logo'),
                const SizedBox(height: 28),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.signedIn => const HomeShell(),
    };
  }
}

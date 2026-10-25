import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

void main() {
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final session = Session(api: api, store: SecureTokenStore())..restore();
  runApp(MemberApp(session: session));
}

const brandPurple = Color(0xFF4A1E8F);

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: brandPurple, primary: brandPurple),
          useMaterial3: true,
          cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        ),
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
      SessionStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.signedIn => const HomeShell(),
    };
  }
}

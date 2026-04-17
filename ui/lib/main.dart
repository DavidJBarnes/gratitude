import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  await api.loadToken();
  final defaultRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final initialRoute = Uri.parse(defaultRoute).path == '/reset-password'
      ? defaultRoute
      : (api.isLoggedIn ? '/home' : '/login');
  runApp(GratitudeApp(initialRoute: initialRoute));
}

class GratitudeApp extends StatelessWidget {
  final String initialRoute;
  const GratitudeApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gratitude',
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.path == '/reset-password') {
          final token = uri.queryParameters['token'] ?? '';
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
            settings: settings,
          );
        }
        return null;
      },
      onGenerateInitialRoutes: (name) {
        final uri = Uri.parse(name);
        if (uri.path == '/reset-password') {
          final token = uri.queryParameters['token'] ?? '';
          return [
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
              settings: RouteSettings(name: name),
            ),
          ];
        }
        return [
          MaterialPageRoute(
            builder: (_) => name == '/home' ? const HomeScreen() : const LoginScreen(),
            settings: RouteSettings(name: name),
          ),
        ];
      },
    );
  }
}

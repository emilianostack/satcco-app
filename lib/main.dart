import 'package:flutter/material.dart';
import 'login/auth_router.dart';
import 'login/login_page.dart';
import 'services/auth_service.dart';
import 'services/route_observer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv error: $e');
  }

  await AuthService.bootstrap();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SATCCO App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      navigatorObservers: [appRouteObserver],
      home: StreamBuilder(
        stream: AuthService.authStateChanges,
        initialData: AuthService.currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AuthRouter(user: snapshot.data!);
          }
          return const LoginPage();
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_details_screen.dart';
import 'screens/employee/employee_home_screen.dart';
import 'screens/hr/hr_home_screen.dart';
import 'screens/legal/legal_home_screen.dart';
import 'services/auth_service.dart';
import 'models/user_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sanad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D3B66),
          brightness: Brightness.light,
          primary: const Color(0xFF0D3B66),
          secondary: const Color(0xFF1A7FA0),
          tertiary: const Color(0xFF2E8B9E),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF0D3B66),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0D3B66),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();

  // Cache futures per user ID so they aren't re-run on every rebuild.
  String? _cachedUid;
  Future<UserRole?>? _roleFuture;
  Future<bool>? _profileFuture;

  void _updateFuturesIfNeeded(String uid) {
    if (uid != _cachedUid) {
      _cachedUid = uid;
      _roleFuture = _authService.getUserRole(uid);
      _profileFuture = _authService.isProfileCompleted(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          _updateFuturesIfNeeded(snapshot.data!.uid);

          return FutureBuilder<UserRole?>(
            future: _roleFuture,
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final role = roleSnapshot.data ?? UserRole.employee;

              switch (role) {
                case UserRole.hr:
                  return const HRHomeScreen();
                case UserRole.legal:
                  return const LegalHomeScreen();
                case UserRole.employee:
                default:
                  return FutureBuilder<bool>(
                    future: _profileFuture,
                    builder: (context, profileSnapshot) {
                      if (profileSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final profileCompleted = profileSnapshot.data ?? false;
                      if (!profileCompleted) {
                        return const EmployeeDetailsScreen();
                      }
                      return const EmployeeHomeScreen();
                    },
                  );
              }
            },
          );
        }

        // User signed out — reset cache
        _cachedUid = null;
        _roleFuture = null;
        _profileFuture = null;
        return const LoginScreen();
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_colors.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  // Flutter needs this line before any Firebase call can run.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Android emulators can't pass Google's Play Integrity/reCAPTCHA check
  // that Firebase Auth normally runs on sign-up (it's meant to confirm the
  // request is coming from a real device), which shows up as a
  // "CONFIGURATION_NOT_FOUND" error. This turns that check off for
  // development/testing. Remove this line — or guard it behind a debug
  // check — before shipping a real release build.
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
  );

  // Restore the user's saved light/dark choice before the first frame.
  await themeController.loadSaved();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    return ThemeData(
      // Seeded with your brand teal so every default Material color
      // (buttons, focus states, etc.) already leans the right direction.
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.tealDeep,
        brightness: brightness,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      // Registers AppColors on the theme so any screen can read
      // context.colors.xxx and get the right value for light or dark.
      extensions: [colors],

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? colors.lilacTint
              : colors.background,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.purpleDeep, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Compound',
          theme: _buildTheme(AppColors.light, Brightness.light),
          darkTheme: _buildTheme(AppColors.dark, Brightness.dark),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          // AuthGate decides what the user sees first — sign-in/sign-up, or
          // the home screen if they're already logged in.
          home: const AuthGate(),
        );
      },
    );
  }
}

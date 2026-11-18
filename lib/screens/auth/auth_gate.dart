import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../home/root_shell.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../onboarding/onboarding_screen.dart';

/// The root decision point for the whole app: shows the sign-in/sign-up
/// flow when nobody's logged in, and the home screen once someone is.
///
/// This listens to Firebase's authStateChanges stream, so it reacts the
/// instant someone signs in, signs up, or signs out — no manual navigation
/// needed anywhere else in the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSignIn = true;
  bool _onboardingJustCompleted = false;

  // These live on the State object, so they survive rebuilds — unlike a
  // local variable inside build(), which gets recreated every time.
  String? _cachedUid;
  Future<DocumentSnapshot>? _userDocFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          if (_onboardingJustCompleted) {
            return const RootShell();
          }
          // Only fetch again if this is a different user than last time
          // we checked (e.g. a fresh login) — not on every rebuild.
          if (_cachedUid != user.uid) {
            _cachedUid = user.uid;
            _userDocFuture = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: _userDocFuture,
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = docSnapshot.data!.data() as Map<String, dynamic>?;
              final hasOnboarded =
                  data != null &&
                  data['experienceLevel'] != null &&
                  data['experienceLevel'] != 'unset';

              return hasOnboarded
                  ? const RootShell()
                  : OnboardingScreen(
                      onComplete: () =>
                          setState(() => _onboardingJustCompleted = true),
                    );
            },
          );
        }

        return _showSignIn
            ? SignInScreen(
                onCreateAccount: () => setState(() => _showSignIn = false),
              )
            : SignUpScreen(
                onHaveAccount: () => setState(() => _showSignIn = true),
              );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// A stand-in for the real Home dashboard, which comes in Phase 2.
///
/// For right now, this exists purely to prove the sign-in flow works
/// end to end, and to let you sign out again to re-test it.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Compound')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Signed in as ${user?.email ?? "unknown"}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => AuthService().signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

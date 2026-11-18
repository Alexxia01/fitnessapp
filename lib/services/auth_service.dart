import 'package:firebase_auth/firebase_auth.dart';

/// Wraps every Firebase Authentication call the app needs.
///
/// Keeping these calls in one place, instead of calling FirebaseAuth
/// directly from every screen, means that if sign-in ever needs to change
/// (adding Google sign-in later, say) there's exactly one file to update.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fires every time sign-in state changes: signed in, signed out, or the
  /// app just starting up. AuthGate listens to this to decide which screen
  /// to show, so nothing else in the app has to manually navigate on
  /// sign-in or sign-out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  /// Turns Firebase's error codes into messages a first-time user can
  /// actually read, instead of raw exception text.
  String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "That email address doesn't look right.";
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      default:
        return 'Something went wrong (${e.code}). Try again.';
    }
  }
}

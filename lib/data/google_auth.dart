import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The *Web application* OAuth client ID from Google Cloud Console. Google puts it in the ID token's
/// audience, and the server only accepts tokens for it (GOOGLE_CLIENT_IDS in backend/.env).
/// Pass it at build time: `flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=123-abc.apps.googleusercontent.com`
const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around Google Sign-In that hands back the ID token for the server to verify.
class GoogleAuth {
  static Future<void>? _initializing;

  /// Whether this build can show Google's sign-in sheet (Android/iOS with a client ID set).
  static bool get isAvailable =>
      googleServerClientId.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _ensureInitialized() =>
      _initializing ??= GoogleSignIn.instance.initialize(serverClientId: googleServerClientId);

  /// Shows Google's account picker. Returns null if the person closed it.
  static Future<String?> getIdToken() async {
    if (!isAvailable) {
      throw const GoogleAuthException(
        "Google sign-in isn't set up in this version of the app yet. Use email and password for now.",
      );
    }
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const GoogleAuthException('Google did not return a sign-in token. Please try again.');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleAuthException(
          'Google sign-in is not configured correctly for this app (check the client IDs and SHA-1).',
        );
      }
      throw GoogleAuthException('Google sign-in failed: ${e.description ?? e.code.name}');
    }
  }

  static Future<void> signOut() async {
    if (!isAvailable || _initializing == null) return;
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of Google is best effort; the Sonder session is already cleared.
    }
  }
}

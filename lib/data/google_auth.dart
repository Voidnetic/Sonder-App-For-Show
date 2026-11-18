import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The *Web application* OAuth client ID ("Sonder server") from Google Cloud project sonder-bb41b. Google puts it
/// in the ID token's audience, and the server only accepts tokens for it (GOOGLE_CLIENT_IDS on Railway).
/// Not a secret. A build can override it with --dart-define=GOOGLE_SERVER_CLIENT_ID=...
const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '1075648757478-k4uk872vklp21cjf8oe9m27015pqhnoj.apps.googleusercontent.com',
);

/// The *iOS* OAuth client ID from Google Cloud, needed on iPhone only (set as a GitHub variable, see IOS.md).
/// Empty in builds without it, and then the Google button explains that it isn't set up on iPhone yet.
const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around Google Sign-In that hands back the ID token for the server to verify.
class GoogleAuth {
  static Future<void>? _initializing;

  /// Tests replace Google's account picker with this.
  @visibleForTesting
  static Future<String?> Function()? idTokenOverride;

  /// Whether this build can show Google's sign-in sheet (Android/iOS with a client ID set).
  static bool get isAvailable =>
      googleServerClientId.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS && googleIosClientId.isNotEmpty));

  static Future<void> _ensureInitialized() => _initializing ??= GoogleSignIn.instance.initialize(
    clientId: defaultTargetPlatform == TargetPlatform.iOS ? googleIosClientId : null,
    serverClientId: googleServerClientId,
  );

  /// Shows Google's account picker. Returns null if the person closed it.
  static Future<String?> getIdToken() async {
    final override = idTokenOverride;
    if (override != null) return override();
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
    } on GoogleAuthException {
      rethrow;
    } catch (e) {
      throw GoogleAuthException('Google sign-in failed. Please try again. ($e)');
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

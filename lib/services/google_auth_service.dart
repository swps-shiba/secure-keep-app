import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:secure_keep_app/config/google_oauth_config.dart';

/// Google Sign-In scoped to app-created Drive files only (`drive.file`).
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const [
                drive.DriveApi.driveFileScope,
              ],
              // Required on Flutter Web. Harmless on mobile when set to the
              // Web OAuth client ID (also usable as serverClientId source).
              clientId: GoogleOAuthConfig.isWebClientConfigured
                  ? GoogleOAuthConfig.webClientId
                  : null,
            );

  final GoogleSignIn _googleSignIn;
  auth.AuthClient? _authClient;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  bool get isSignedIn => currentUser != null;

  void _ensureWebClientId() {
    if (kIsWeb && !GoogleOAuthConfig.isWebClientConfigured) {
      throw StateError(GoogleOAuthConfig.missingClientIdMessage);
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    _ensureWebClientId();
    final account = await _googleSignIn.signInSilently();
    if (account != null) {
      await _refreshAuthClient();
    }
    return account;
  }

  Future<GoogleSignInAccount?> signIn() async {
    _ensureWebClientId();
    final account = await _googleSignIn.signIn();
    if (account != null) {
      await _refreshAuthClient();
    }
    return account;
  }

  Future<void> signOut() async {
    _authClient = null;
    await _googleSignIn.signOut();
  }

  Future<void> _refreshAuthClient() async {
    var client = await _googleSignIn.authenticatedClient();
    if (client == null && kIsWeb && _googleSignIn.currentUser != null) {
      final granted = await _googleSignIn.requestScopes(_googleSignIn.scopes);
      if (!granted) {
        throw StateError('Google Drive access was not granted');
      }
      client = await _googleSignIn.authenticatedClient();
    }
    if (client == null) {
      throw StateError(
        'Google sign-in succeeded, but no Drive access token was returned',
      );
    }
    _authClient = client;
  }

  Future<http.Client> authenticatedClient() async {
    if (_authClient != null) {
      return _authClient!;
    }

    var account = currentUser ?? await signInSilently();
    account ??= await signIn();
    if (account == null) {
      throw StateError('Google Sign-In cancelled');
    }
    await _refreshAuthClient();
    return _authClient!;
  }

  Future<drive.DriveApi> driveApi() async {
    final client = await authenticatedClient();
    return drive.DriveApi(client);
  }
}

/// Google Cloud Console setup checklist for Drive sync.
///
/// 1. Create a project at https://console.cloud.google.com/
/// 2. Enable **Google Drive API**
/// 3. Configure OAuth consent screen (add yourself as a test user)
/// 4. Create OAuth client IDs:
///    - **Web** (required for `flutter run -d chrome`):
///      paste into [GoogleOAuthConfig.webClientId] and `web/index.html`
///      Authorized JS origins: `http://localhost`, `http://127.0.0.1`
///    - Android: package `com.swps.secure_keep_app` + SHA-1
///    - iOS: bundle id from Xcode (Runner)
/// 5. Restart the app after changing the Client ID
///
/// Scope: `drive.file`. Encrypted files → Drive folder **Secure Keep**.
library;

export 'google_oauth_config.dart';

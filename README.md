# secure_keep_app

A security-first memo app with Google Drive synchronization.

## Photos and videos in memos

Use the attachment and paste controls in the memo editor to add image or video
files on Android, iOS, and Web. Attachment bytes are encrypted with the vault
key before they are written to the local cache or resumably uploaded to Google Drive.
Attachment names and media types are stored in the encrypted memo record.

On Web, encrypted attachment bytes are cached in IndexedDB; memo records
continue to use the existing encrypted browser cache. Google Drive receives
only ciphertext for both memo records and media.

## Installing on personal phones

- Android: the current debug APK is
  `build/app/outputs/flutter-apk/app-debug.apk` (about 160 MB). Transfer it to
  the phone using Google Drive or another trusted method, open the APK, and
  approve installation for that file source if Android prompts. USB debugging
  is not required. This debug build is signed with the local debug key and is
  only for testing.
- To enable Google Sign-In on Android, create an Android OAuth client in Google
  Cloud Console with package name `com.swps.secure_keep_app` and SHA-1
  fingerprint
  `F5:B0:DE:4C:F2:D1:96:B8:70:6A:31:00:80:F1:94:08:10:12:70:C2`.
  The fingerprint is for this computer's debug signing key; a different key
  requires a different OAuth client configuration. Keep the existing Web OAuth
  client ID configured as the server client ID. Also enable the Google Drive
  API and add the Google account to the OAuth consent screen's test users.
- iPhone without a Mac: deploy the Web build to an HTTPS host, open it in
  Safari, then use Share → Add to Home Screen. This is an installed web app,
  not a native iOS app. A native iOS build requires macOS and Xcode.
- On Web, a passkey protects the cached vault key using the WebAuthn PRF
  extension. The browser/authenticator verifies the user with biometrics or
  the device screen-lock PIN; the app cannot require biometrics only. This
  requires HTTPS and a browser/authenticator that supports PRF. If unsupported,
  Web setup cannot complete. The recovery phrase is still needed to restore on
  another browser or device.
- On Web, switching apps or opening a system/browser dialog does not auto-lock
  the vault, because mobile browsers report those transitions inconsistently;
  use the in-app lock button when stepping away. Reloading the page returns to
  the locked screen.

### Publish a test web app with GitHub Pages

The included GitHub Actions workflow builds Flutter Web and publishes it to
GitHub Pages whenever a commit is pushed to `main`.

1. Create a **public** GitHub repository for this project. GitHub Pages is
   publicly accessible, and the repository source will also be public.
2. Push this project to the repository's `main` branch.
3. In the repository, open **Settings → Pages** and select **GitHub Actions**
   as the build and deployment source.
4. Wait for the **Deploy Flutter web to GitHub Pages** workflow to finish. The
   Pages URL is shown in **Settings → Pages** and in the workflow deployment.
5. In Google Cloud Console, add the site's origin
   (`https://<GitHub-username>.github.io`, without a path or trailing slash)
   to the Web OAuth client's **Authorized JavaScript origins**. For a project
   Pages URL such as `https://<GitHub-username>.github.io/<repository>/`, the
   origin is still just `https://<GitHub-username>.github.io`.

GitHub Pages serves the site publicly even when the source repository is
private, unless the organization has GitHub Enterprise Cloud private Pages.
Only the app code is published; memo data is encrypted in the browser before
being stored locally or synced to Drive. However, a web app must trust the code
delivered by its hosting provider. Use test data until the encryption design
has been upgraded and reviewed.

## Getting Started

Install dependencies with `flutter pub get`, then run with `flutter run`.

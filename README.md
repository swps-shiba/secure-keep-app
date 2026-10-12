# secure_keep_app

A security-first memo app with Google Drive synchronization.

## Photos and videos in memos

Use the attachment and paste controls in the memo editor to add image or video
files on Android, iOS, and Web. Attachment bytes are encrypted with the vault
key before they are written to the local cache or resumably uploaded to Google Drive.
Attachment names and media types are stored in the encrypted memo record.
Saved attachments are decrypted in memory for an in-app image preview or video
playback. Use the preview's Download button to explicitly export the decrypted
file. Native video playback uses a temporary app-private file that is removed
when the preview closes; Web video playback uses an in-memory object URL.

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

### Publish the web app with GitHub Pages

The included GitHub Actions workflow builds Flutter Web and publishes it to
GitHub Pages whenever a commit is pushed to `main`.

1. Add a DNS CNAME record for `secure-keep.swps.jp` pointing to
   `swps-shiba.github.io`, then open the repository's **Settings → Pages**,
   select **GitHub Actions**, and set `secure-keep.swps.jp` as the custom
   domain. Enable **Enforce HTTPS** after DNS verification completes.
2. Push this project to the `main` branch of `swps-shiba/secure-keep-app`.
   GitHub Pages serves the app publicly, and the repository source is public.
3. Wait for the **Deploy Flutter web to GitHub Pages** workflow to finish.
   The workflow publishes the custom-domain CNAME file. The app selects the
   repository path on `swps-shiba.github.io` and the domain root on
   `secure-keep.swps.jp`.
4. Verify ownership of `swps.jp` in Google Search Console and add `swps.jp`
   to the OAuth consent screen's **Authorized domains**. Set the app homepage
   to `https://swps.jp/` and its privacy policy to
   `https://swps.jp/secure-keep-privacy.html`.
5. In the Web OAuth client's **Authorized JavaScript origins**, add
   `https://secure-keep.swps.jp` (origin only; no path or trailing slash).
   Configure the OAuth consent screen for external users and submit any
   verification requested by Google before publishing it to production.

GitHub Pages serves the site publicly even when the source repository is
private, unless the organization has GitHub Enterprise Cloud private Pages.
Only the app code is published; memo data is encrypted in the browser before
being stored locally or synced to Drive. However, a web app must trust the code
delivered by its hosting provider. Use test data until the encryption design
has been upgraded and reviewed. Review the app's security design before
inviting the public to store sensitive information.

## Getting Started

Install dependencies with `flutter pub get`, then run with `flutter run`.

## Using the same vault on another device

Choose **Restore** on a new PC or browser, enter the 12-word recovery phrase
from the original setup, and sign in to the same Google account as the phone.
Starting a new vault creates a different encryption key and cannot decrypt the
phone's memos; setup is blocked when existing memos are found in that Drive
account.

The app does not send a two-step verification approval or notification to the
phone. Google controls its account sign-in verification prompts according to
the account's security settings. The app's fingerprint, face, or device-PIN
prompt is a local vault unlock, not a remote second factor.
On Web, connecting Drive clears the app's remembered Google sign-in and asks
you to sign in again each time. Google may still skip its phone prompt for a
trusted browser or device.

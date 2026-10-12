/// Google OAuth Client ID used by Flutter Web (`google_sign_in_web`).
///
/// ## セットアップ手順（Web）
/// 1. https://console.cloud.google.com/ でプロジェクトを作成
/// 2. 「API とサービス」→「ライブラリ」で **Google Drive API** を有効化
/// 3. 「OAuth 同意画面」を設定（テストユーザーに自分の Gmail を追加）
/// 4. 「認証情報」→「OAuth クライアント ID を作成」
///    - アプリケーションの種類: **ウェブアプリケーション**
///    - 承認済みの JavaScript 生成元に追加:
///      - `http://localhost`
///      - `http://127.0.0.1`
///      （ポート付きでも可: `http://localhost:57140` など）
/// 5. 発行された Client ID を下の [webClientId] に貼り付ける
/// 6. `web/index.html` の meta タグにも同じ ID を入れる
/// 7. ホットリスタートではなく **アプリを再起動**（`flutter run -d chrome`）
/// 8. 本番 Web 公開では `https://secure-keep.swps.jp` を Web OAuth クライアントの
///    承認済み JavaScript 生成元に追加する
///
/// Android / iOS 実機ではパッケージ名 + SHA-1（または URL scheme）で足りるため、
/// この Web Client ID は主にブラウザ実行時に必要です。
class GoogleOAuthConfig {
  /// 例: `1234567890-abcdefg.apps.googleusercontent.com`
  ///
  /// `--dart-define=GOOGLE_CLIENT_ID=...` でも上書きできます。
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '589208431639-8d5cr2k83c3dodu7p2vre8icf9a5822v.apps.googleusercontent.com',
  );

  static bool get isWebClientConfigured => webClientId.trim().isNotEmpty;

  static const String missingClientIdMessage =
      'Google Client ID が未設定です。\n'
      'lib/config/google_oauth_config.dart の webClientId に、'
      'Google Cloud Console で作成した「ウェブアプリケーション」の '
      'Client ID を貼り付けてください。\n'
      'あわせて web/index.html の google-signin-client_id も更新し、'
      'アプリを再起動してください。';
}

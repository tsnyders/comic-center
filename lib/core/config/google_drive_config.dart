/// Google Drive (Sign-In) configuration.
///
/// Drive backup uses `google_sign_in`, which on iOS/macOS needs an
/// **iOS OAuth 2.0 client ID** plus the matching reversed-client-ID URL scheme
/// in `ios/Runner/Info.plist`.
///
/// To enable Drive on iOS (see `docs/DRIVE_SETUP_IOS.md` for the full walk-through):
///   1. Create an iOS OAuth client (bundle id `com.comiccenter.comicCenter`).
///   2. Paste its client ID below (or pass `--dart-define=GOOGLE_IOS_CLIENT_ID=...`).
///   3. Paste the REVERSED_CLIENT_ID into the `CFBundleURLTypes` slot in Info.plist.
///
/// Until a client ID is provided the Drive UI degrades gracefully — it tells the
/// user Drive isn't set up instead of throwing a native sign-in error.
abstract final class GoogleDriveConfig {
  /// iOS / macOS OAuth client ID, e.g.
  /// `123456789-abcdef.apps.googleusercontent.com`.
  ///
  /// Prefer `--dart-define=GOOGLE_IOS_CLIENT_ID=...`; the literal below is the
  /// fallback for local builds. Leave empty to keep Drive disabled.
  static const iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// True once a client ID has been supplied for the current platform.
  static bool get hasIosClientId => iosClientId.isNotEmpty;
}

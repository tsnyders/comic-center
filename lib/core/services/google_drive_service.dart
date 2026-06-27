import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/google_drive_config.dart';

/// Thrown when a Drive action is attempted before an OAuth client ID has been
/// configured for the current platform (see [GoogleDriveConfig]).
class DriveNotConfiguredException implements Exception {
  const DriveNotConfiguredException();
  @override
  String toString() =>
      'Google Drive is not set up for this build. '
      'Add an iOS OAuth client ID — see docs/DRIVE_SETUP_IOS.md.';
}

class GoogleDriveService {
  static final _signIn = GoogleSignIn(
    // Apple platforms read the client ID from the constructor; Android uses the
    // bundled google-services.json instead, so leave it null there.
    clientId: _platformClientId,
    scopes: [drive.DriveApi.driveFileScope],
  );

  static String? get _platformClientId =>
      (Platform.isIOS || Platform.isMacOS) && GoogleDriveConfig.hasIosClientId
          ? GoogleDriveConfig.iosClientId
          : null;

  /// Whether Drive sign-in can be attempted on the current platform.
  static bool get isConfigured => (Platform.isIOS || Platform.isMacOS)
      ? GoogleDriveConfig.hasIosClientId
      : true; // Android relies on google-services.json at build time

  static GoogleSignInAccount? _account;
  static GoogleSignInAccount? get currentAccount => _account;

  static Future<GoogleSignInAccount?> signInSilently() async {
    if (!isConfigured) return null;
    _account = await _signIn.signInSilently();
    return _account;
  }

  static Future<GoogleSignInAccount?> signIn() async {
    if (!isConfigured) throw const DriveNotConfiguredException();
    _account = await _signIn.signIn();
    return _account;
  }

  static Future<void> signOut() async {
    await _signIn.signOut();
    _account = null;
  }

  static Future<drive.DriveApi?> _api() async {
    final acc = _account ?? await _signIn.signInSilently();
    if (acc == null) return null;
    final headers = await acc.authHeaders;
    return drive.DriveApi(_AuthClient(headers));
  }

  static Future<String> _folderId(drive.DriveApi api) async {
    const name = 'Yomi Backups';
    const mime = 'application/vnd.google-apps.folder';
    final list = await api.files.list(
      q: "name='$name' and mimeType='$mime' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = drive.File()
      ..name = name
      ..mimeType = mime;
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  static Future<void> uploadBackup(File file) async {
    final api = await _api();
    if (api == null) throw Exception('Not signed in to Google Drive');
    final folderId = await _folderId(api);
    final fileName = file.path.split('/').last;
    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];
    final length = await file.length();
    final media = drive.Media(
      file.openRead(),
      length,
      contentType: 'application/json',
    );
    await api.files.create(driveFile, uploadMedia: media, $fields: 'id');
  }

  static Future<List<DriveBackupFile>> listBackups() async {
    final api = await _api();
    if (api == null) return [];
    final folderId = await _folderId(api);
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed=false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,size,createdTime)',
    );
    return (result.files ?? []).map((f) {
      return DriveBackupFile(
        id: f.id!,
        name: f.name ?? 'backup.json',
        createdAt: f.createdTime,
        sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
      );
    }).toList();
  }

  static Future<File> downloadBackup(
      String fileId, String fileName) async {
    final api = await _api();
    if (api == null) throw Exception('Not signed in to Google Drive');
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    final bytes =
        await media.stream.fold<List<int>>([], (a, b) => [...a, ...b]);
    await file.writeAsBytes(bytes);
    return file;
  }
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}

class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final int sizeBytes;

  String get displayName {
    final n = name
        .replaceFirst('yomi_backup_', '')
        .replaceAll('.json', '');
    return n.replaceAll('_', '  ').trim();
  }

  String get sizeDisplay {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

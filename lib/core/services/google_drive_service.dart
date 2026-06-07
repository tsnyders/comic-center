import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

final _googleSignIn = GoogleSignIn(
  scopes: [drive.DriveApi.driveFileScope],
);

class DriveBackupFile {
  DriveBackupFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime modifiedTime;
  final int sizeBytes;

  String get displayName {
    final dt = modifiedTime.toLocal();
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String get sizeDisplay {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers, this._inner);

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleDriveService {
  static Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();

  static Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  static Future<void> signOut() => _googleSignIn.signOut();

  static Future<drive.DriveApi> _api() async {
    final user = _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently() ??
        await _googleSignIn.signIn();
    if (user == null) throw Exception('Not signed in');
    final headers = await user.authHeaders;
    return drive.DriveApi(_AuthClient(headers, http.Client()));
  }

  static Future<String> _backupFolderId(drive.DriveApi api) async {
    const folderName = 'Yomi Backups';
    final list = await api.files.list(
      q: "name='$folderName' and mimeType='application/vnd.google-apps.folder' "
          "and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = await api.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder',
      $fields: 'id',
    );
    return folder.id!;
  }

  static Future<void> uploadBackup(File file, String fileName) async {
    final api = await _api();
    final folderId = await _backupFolderId(api);
    await api.files.create(
      drive.File()
        ..name = fileName
        ..parents = [folderId],
      uploadMedia: drive.Media(
        file.openRead(),
        await file.length(),
        contentType: 'application/octet-stream',
      ),
    );
  }

  static Future<List<DriveBackupFile>> listBackups() async {
    final api = await _api();
    final folderId = await _backupFolderId(api);
    final list = await api.files.list(
      q: "'$folderId' in parents and trashed=false",
      orderBy: 'modifiedTime desc',
      spaces: 'drive',
      $fields: 'files(id,name,modifiedTime,size)',
    );
    return (list.files ?? []).map((f) {
      return DriveBackupFile(
        id: f.id ?? '',
        name: f.name ?? '',
        modifiedTime: f.modifiedTime ?? DateTime.now(),
        sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
      );
    }).toList();
  }

  static Future<File> downloadBackup(String fileId, String localPath) async {
    final api = await _api();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final file = File(localPath);
    final sink = file.openWrite();
    await media.stream.pipe(sink);
    await sink.close();
    return file;
  }
}

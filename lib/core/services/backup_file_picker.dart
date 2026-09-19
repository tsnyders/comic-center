import 'dart:io';

import 'package:flutter/services.dart';

/// Android Storage Access Framework bridge. The returned file is a private
/// temporary copy; callers must delete it after importing or cancelling.
abstract final class BackupFilePicker {
  static const _channel = MethodChannel('yomi/platform');

  static Future<File?> pick({bool tachiyomi = false}) async {
    final path = await _channel.invokeMethod<String>('pickBackup', {
      'tachiyomi': tachiyomi,
    });
    return path == null ? null : File(path);
  }

  /// Save an exported Yomi backup to a user-selected system location.
  static Future<bool> save(File file) async =>
      await _channel.invokeMethod<bool>('saveBackup', {
        'path': file.path,
        'name': file.uri.pathSegments.last,
      }) ??
      false;
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String version;
  final String downloadUrl;
  final String releaseNotes;
}

class UpdateService {
  static const _channel = MethodChannel('yomi/platform');
  static const _owner = 'tsnyders';
  static const _repo = 'comic-center';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 5),
  ));

  static Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      final data = response.data as Map<String, dynamic>;
      final tag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (tag.isEmpty || !_isNewer(tag, currentVersion)) return null;

      final assets = (data['assets'] as List<dynamic>?) ?? [];
      final apk = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String).endsWith('.apk'),
            orElse: () => {},
          );
      final url = apk['browser_download_url'] as String?;
      if (url == null) return null;

      return UpdateInfo(
        version: tag,
        downloadUrl: url,
        releaseNotes: data['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> downloadAndInstall(
    String apkUrl, {
    required void Function(double) onProgress,
  }) async {
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {}
    dir ??= await getTemporaryDirectory();

    final path = '${dir.path}/yomi_update.apk';
    await _dio.download(
      apkUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }

  static bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}

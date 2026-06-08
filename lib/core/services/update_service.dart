import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.publishedAt,
    this.apkUrl,
    this.isPrerelease = false,
  });

  final String tag;
  final String name;
  final String body;
  final String publishedAt;
  final String? apkUrl;
  final bool isPrerelease;

  DateTime? get publishedAtDate => DateTime.tryParse(publishedAt);
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UpdateService {
  static const _repo    = 'tsnyders/comic-center';
  static const _channel = MethodChannel('yomi/platform');

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 5),
  ));

  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://api.github.com/repos/$_repo/releases/latest',
      );
      return _parseRelease(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw UpdateCheckException(
        e.message ?? 'Network error while checking for updates',
      );
    } catch (e) {
      throw UpdateCheckException(e.toString());
    }
  }

  static Future<List<ReleaseInfo>> fetchReleases() async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://api.github.com/repos/$_repo/releases',
        queryParameters: {'per_page': 30},
      );
      final list = resp.data as List;
      return list
          .map((e) => _parseRelease(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw UpdateCheckException(
        e.message ?? 'Network error while fetching changelog',
      );
    } catch (e) {
      throw UpdateCheckException(e.toString());
    }
  }

  static ReleaseInfo _parseRelease(Map<String, dynamic> d) {
    final assets = (d['assets'] as List?) ?? [];
    final apkUrl = assets
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] as String).toLowerCase().endsWith('.apk'))
        .map((a) => a['browser_download_url'] as String)
        .firstOrNull;
    return ReleaseInfo(
      tag         : d['tag_name']     as String? ?? '',
      name        : d['name']         as String? ?? '',
      body        : d['body']         as String? ?? '',
      publishedAt : d['published_at'] as String? ?? '',
      apkUrl      : apkUrl,
      isPrerelease: d['prerelease']   as bool?   ?? false,
    );
  }

  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod<void>('openUrl', {'url': url});
    } catch (_) {}
  }

  /// Downloads the APK at [apkUrl] and triggers the system package installer.
  /// Progress is reported via [onProgress] (0.0 → 1.0).
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
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Thrown when we cannot reach the update server or parse its response.
/// Distinct from returning null (which means "already on latest version").
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UpdateService {
  static const _repo    = 'tsnyders/comic-center';
  static const _channel = MethodChannel('yomi/platform');

  /// In-app APK download + install is only possible on Android. On iOS the
  /// App Store / TestFlight owns updates, so the UI falls back to opening the
  /// GitHub release page instead.
  static bool get supportsInAppUpdate => Platform.isAndroid;

  /// Canonical web URL for a given release tag (used by the iOS "View Release"
  /// fallback and anywhere a release needs to open in the browser).
  static String releaseUrl(String tag) =>
      'https://github.com/$_repo/releases/tag/$tag';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 5),
  ));

  /// Returns the latest release if it is newer than the installed build,
  /// or null if already up to date (or no releases exist yet).
  /// Throws [UpdateCheckException] on network/parse failures.
  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://api.github.com/repos/$_repo/releases/latest',
      );
      final release = _parseRelease(resp.data as Map<String, dynamic>);

      final info         = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final releaseBuild = _parseBuildNumber(release.tag);

      if (releaseBuild <= currentBuild) return null;
      return release;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw UpdateCheckException(
        e.message ?? 'Network error while checking for updates',
      );
    } catch (e) {
      throw UpdateCheckException(e.toString());
    }
  }

  /// Returns up to 30 most-recent releases, newest first.
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

  /// Open a URL in the system browser (cross-platform via url_launcher).
  static Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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

  /// Extracts the trailing integer from a tag like "v1.0-beta.45" → 45.
  static int _parseBuildNumber(String tag) {
    final match = RegExp(r'\.(\d+)$').firstMatch(tag);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

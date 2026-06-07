import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

// ── Update service ────────────────────────────────────────────────────────────

class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.publishedAt,
    this.apkUrl,
  });

  final String  tag;
  final String  name;
  final String  body;
  final String  publishedAt;
  final String? apkUrl;
}

/// Thrown when we cannot reach the update server or parse its response.
/// Distinct from returning null (which means "no releases published yet").
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
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Returns the latest release from GitHub.
  /// Returns null if no releases have been published yet (HTTP 404).
  /// Throws [UpdateCheckException] for network/parse failures.
  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://api.github.com/repos/$_repo/releases/latest',
      );
      final d = resp.data as Map<String, dynamic>;
      final assets = (d['assets'] as List?) ?? [];
      final apkUrl = assets
          .cast<Map<String, dynamic>>()
          .where((a) => (a['name'] as String).toLowerCase().endsWith('.apk'))
          .map((a) => a['browser_download_url'] as String)
          .firstOrNull;

      return ReleaseInfo(
        tag         : d['tag_name'] as String? ?? '',
        name        : d['name']       as String? ?? '',
        body        : d['body']       as String? ?? '',
        publishedAt : d['published_at'] as String? ?? '',
        apkUrl      : apkUrl,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // 404 means no releases exist yet — that is not a network error.
        return null;
      }
      throw UpdateCheckException(
        e.message ?? 'Network error while checking for updates',
      );
    } catch (e) {
      throw UpdateCheckException(e.toString());
    }
  }

  /// Open a URL via the native Android intent (VIEW action).
  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod<void>('openUrl', {'url': url});
    } catch (_) {
      // Platform channel not configured — silently ignore.
    }
  }
}

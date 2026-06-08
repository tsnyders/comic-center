import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Tracks whether a "What's New" dialog should be shown on this launch.
/// Seeded before [runApp] via [ProviderScope.overrides].
final showWhatsNewProvider = Provider<bool>((ref) => false);

/// Detects whether the app has been updated since the user last launched it.
/// Stores the last-seen version in a small file in the app's documents dir.
class WhatsNewService {
  static const _kCurrentVersion = '1.0.0';
  static const _fileName = '.last_seen_version';

  /// Returns true (and updates the stored version) if this is the first launch
  /// on [_kCurrentVersion]. Returns false on subsequent launches.
  static Future<bool> checkAndMark() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');

      String? stored;
      if (await file.exists()) {
        stored = (await file.readAsString()).trim();
      }

      final isNew = stored != _kCurrentVersion;
      if (isNew) {
        await file.writeAsString(_kCurrentVersion);
      }
      return isNew;
    } catch (_) {
      return false;
    }
  }

  static String get currentVersion => _kCurrentVersion;
}

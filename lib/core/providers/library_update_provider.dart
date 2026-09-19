import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/library_update_service.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'source_registry_provider.dart';

/// `(done, total)` while a manual library update runs; null when idle.
class LibraryUpdateNotifier extends Notifier<(int, int)?> {
  @override
  (int, int)? build() => null;

  /// Returns null without doing anything when an update is already running.
  Future<LibraryUpdateResult?> run() async {
    if (state != null) return null;
    state = (0, 0);
    try {
      return await updateLibrary(
        ref.read(isarProvider),
        ref.read(sourceRegistryProvider),
        onProgress: (done, total) => state = (done, total),
        autoDownload: ref.read(autoDownloadNewChaptersProvider),
      );
    } finally {
      state = null;
    }
  }
}

final libraryUpdateProvider =
    NotifierProvider<LibraryUpdateNotifier, (int, int)?>(
        LibraryUpdateNotifier.new);

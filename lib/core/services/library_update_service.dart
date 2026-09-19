import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:workmanager/workmanager.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';
import '../extensions/source_interface.dart';
import '../providers/browse_provider.dart';
import 'app_logger.dart';
import 'extension_manager.dart';

/// WorkManager task name handled by `downloadCallbackDispatcher`.
const libraryUpdateTask = 'yomi.library.update';
const _libraryUpdateWork = 'yomi-library-update';

class LibraryUpdateResult {
  const LibraryUpdateResult({
    required this.newChapters,
    required this.updatedTitles,
    required this.errors,
  });

  final int newChapters;

  /// Titles that received at least one new chapter.
  final int updatedTitles;

  /// Manga id → error for titles whose refresh failed.
  final Map<int, Object> errors;
}

/// Refreshes chapters for every in-library title, three at a time. A failing
/// title lands in [LibraryUpdateResult.errors] and the run continues.
Future<LibraryUpdateResult> updateLibrary(
  Isar isar,
  List<MangaSource> sources, {
  void Function(int done, int total)? onProgress,
}) async {
  final mangas =
      await isar.mangaEntrys.filter().inLibraryEqualTo(true).findAll();
  final bySource = {for (final s in sources) s.id: s};
  final queue = mangas.iterator;
  final errors = <int, Object>{};
  var done = 0, newChapters = 0, updatedTitles = 0;
  onProgress?.call(0, mangas.length);

  Future<void> worker() async {
    while (queue.moveNext()) {
      final manga = queue.current;
      try {
        final source = bySource[manga.sourceId];
        if (source == null) {
          throw StateError('Source "${manga.sourceId}" is not installed');
        }
        final chapters = isar.chapterEntrys.filter().mangaIdEqualTo(manga.id);
        final before = await chapters.count();
        await refreshMangaChapters(
          isar: isar,
          source: source,
          mangaId: manga.id,
          sourceMangaId: manga.sourceMangaId,
        );
        final added = await chapters.count() - before;
        if (added > 0) {
          newChapters += added;
          updatedTitles++;
        }
      } catch (error, stackTrace) {
        errors[manga.id] = error;
        AppLogger.instance.error(
            'Library update failed for "${manga.title}"', error, stackTrace);
      }
      onProgress?.call(++done, mangas.length);
    }
  }

  await Future.wait([for (var i = 0; i < 3; i++) worker()]);
  return LibraryUpdateResult(
    newChapters: newChapters,
    updatedTitles: updatedTitles,
    errors: errors,
  );
}

/// Background-isolate entry: refresh the library and summarise new chapters
/// in one notification.
Future<bool> runLibraryUpdateTask(Isar isar) async {
  final result =
      await updateLibrary(isar, await ExtensionManager.loadInstalled(isar));
  if (result.newChapters > 0) await LibraryUpdateService.notify(result);
  return true;
}

abstract final class LibraryUpdateService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // ic_launcher_sumi is referenced from the manifest, so R8's resource
  // shrinker keeps it.
  static Future<void> _init() => _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher_sumi'),
        ),
      );

  /// Settings toggle: on → ask for notifications and schedule; off → cancel.
  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    if (!enabled) return cancel();
    await _init();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await schedule();
  }

  /// Idempotent: an existing 12 h schedule is kept.
  static Future<void> schedule() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      _libraryUpdateWork,
      libraryUpdateTask,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(_libraryUpdateWork);
  }

  /// "12 new chapters in 4 titles". Tapping opens the app (plugin default).
  static Future<void> notify(LibraryUpdateResult result) async {
    await _init();
    final n = result.newChapters, t = result.updatedTitles;
    await _plugin.show(
      id: 0,
      title: 'New chapters',
      body:
          '$n new chapter${n == 1 ? '' : 's'} in $t title${t == 1 ? '' : 's'}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'yomi_library_updates',
          'Library updates',
          channelDescription: 'New chapters found for titles in your library',
        ),
      ),
    );
  }
}

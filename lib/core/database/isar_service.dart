import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/chapter_entry.dart';
import 'models/download_entry.dart';
import 'models/manga_entry.dart';
import 'models/source_entry.dart';

abstract final class IsarService {
  static Future<Isar> init() async {
    final dir = await _resolveDir();
    return Isar.open(
      [
        MangaEntrySchema,
        ChapterEntrySchema,
        SourceEntrySchema,
        DownloadEntrySchema,
      ],
      directory: dir,
    );
  }

  static Future<String> _resolveDir() async {
    // On Linux running as root the XDG documents dir may be unavailable.
    // Fall back to a temp directory so the app always starts.
    try {
      final d = await getApplicationDocumentsDirectory();
      return d.path;
    } catch (_) {
      final tmp = Directory('/tmp/comic_center_data');
      await tmp.create(recursive: true);
      return tmp.path;
    }
  }
}

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/chapter_entry.dart';
import 'models/download_entry.dart';
import 'models/manga_entry.dart';
import 'models/source_entry.dart';

abstract final class IsarService {
  static Future<Isar> init() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [
        MangaEntrySchema,
        ChapterEntrySchema,
        SourceEntrySchema,
        DownloadEntrySchema,
      ],
      directory: dir.path,
    );
  }
}

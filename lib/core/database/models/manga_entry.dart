import 'package:isar/isar.dart';

part 'manga_entry.g.dart';

@Collection()
class MangaEntry {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String title;

  /// Unique ID string from the source (e.g. MangaDex UUID)
  @Index(unique: true, replace: true)
  late String sourceKey; // "{sourceId}::{mangaId}"

  late String sourceId;
  late String sourceMangaId;
  late String sourceUrl;

  String? coverUrl;
  String? author;
  String? artist;
  String? description;

  @Index()
  List<String> genres = [];

  /// "ongoing" | "completed" | "hiatus" | "cancelled" | "unknown"
  String status = 'unknown';

  @Index()
  bool inLibrary = false;

  DateTime? lastUpdated;
  DateTime? addedToLibrary;

  int unreadCount = 0;
  int chapterCount = 0;

  List<String> categories = [];

  // Reading progress
  String? lastReadChapterId;
  double? lastReadChapterNumber;
  int lastReadPage = 0;
  DateTime? lastReadAt;
}

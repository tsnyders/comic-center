import 'package:isar/isar.dart';

part 'chapter_entry.g.dart';

@Collection()
class ChapterEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late int mangaId;

  late String sourceChapterId;
  late String title;

  double? number;
  double? volume;
  String? scanlator;
  String? language;

  @Index()
  bool isRead = false;

  @Index()
  bool isDownloaded = false;

  String? downloadPath;
  int pageCount = 0;
  int lastPageRead = 0;

  DateTime? uploadDate;
  DateTime? readAt;
  DateTime? downloadedAt;
}

import 'package:isar/isar.dart';

part 'download_entry.g.dart';

const preparingDownloadPages = 'Preparing pages…';
const waitingForDownloadPages = 'Open Yomi to prepare this chapter';

/// Download status constants
abstract final class DownloadStatus {
  static const pending = 'pending';
  static const downloading = 'downloading';
  static const paused = 'paused';
  static const completed = 'completed';
  static const failed = 'failed';
}

@Collection()
class DownloadEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late int chapterId;

  @Index()
  late int mangaId;

  late String mangaTitle;
  late String chapterTitle;
  late double chapterNumber;

  @Index()
  String status = DownloadStatus.pending;

  int totalPages = 0;
  int downloadedPages = 0;

  /// Foreground-resolved pages, reusable by the background isolate and retries.
  List<String> pageUrls = [];

  String? downloadPath;
  DateTime? queuedAt;
  DateTime? startedAt;
  DateTime? completedAt;

  String? errorMessage;
  int retryCount = 0;

  double get progress => totalPages == 0 ? 0.0 : downloadedPages / totalPages;
}

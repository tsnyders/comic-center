import 'package:isar/isar.dart';

part 'source_entry.g.dart';

@Collection()
class SourceEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String sourceId;

  late String name;
  late String baseUrl;
  late String language;
  late String version;

  bool isEnabled = true;
  bool hasNsfw = false;

  /// Path to cached icon on disk
  String? iconPath;

  DateTime? installedAt;
  DateTime? lastCheckedAt;
}

class ChapterInfo {
  const ChapterInfo({
    required this.id,
    required this.title,
    this.number,
    this.volume,
    this.scanlator,
    this.language,
    this.uploadDate,
    this.url,
  });

  final String id;
  final String title;
  final double? number;
  final double? volume;
  final String? scanlator;
  final String? language;
  final DateTime? uploadDate;
  final String? url;
}

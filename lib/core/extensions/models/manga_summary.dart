/// Lightweight result returned by source list/search queries.
class MangaSummary {
  const MangaSummary({
    required this.id,
    required this.title,
    this.coverUrl,
    this.url,
  });

  final String id;
  final String title;
  final String? coverUrl;
  final String? url;
}

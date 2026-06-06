/// Full metadata returned when the user opens a title.
class MangaDetail {
  const MangaDetail({
    required this.id,
    required this.title,
    this.coverUrl,
    this.author,
    this.artist,
    this.description,
    this.genres = const [],
    this.status = 'unknown',
    this.url,
  });

  final String id;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? artist;
  final String? description;
  final List<String> genres;
  final String status;
  final String? url;
}

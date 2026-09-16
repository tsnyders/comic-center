/// A genre that a source can browse through its own catalogue endpoint.
///
/// [id] is opaque and belongs to the source; [name] is shown to the reader.
class GenreOption {
  const GenreOption({required this.id, required this.name});

  final String id;
  final String name;
}

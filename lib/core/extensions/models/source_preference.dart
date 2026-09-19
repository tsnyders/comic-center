/// A per-source setting shown on the source settings screen and read by the
/// source at request time through `SourcePrefs`.
sealed class SourcePreference {
  const SourcePreference({required this.key, required this.title});

  /// Stored under `source.<sourceId>.<key>`.
  final String key;
  final String title;
}

class TogglePreference extends SourcePreference {
  const TogglePreference({
    required super.key,
    required super.title,
    this.defaultValue = false,
  });
  final bool defaultValue;
}

class TextPreference extends SourcePreference {
  const TextPreference({
    required super.key,
    required super.title,
    this.defaultValue = '',
  });
  final String defaultValue;
}

class SelectPreference extends SourcePreference {
  const SelectPreference({
    required super.key,
    required super.title,
    required this.options,
    required this.values,
    required this.defaultValue,
  });
  final List<String> options;
  final List<String> values;
  final String defaultValue;
}

class MultiSelectPreference extends SourcePreference {
  const MultiSelectPreference({
    required super.key,
    required super.title,
    required this.options,
    required this.values,
    required this.defaultValue,
  });
  final List<String> options;
  final List<String> values;
  final List<String> defaultValue;
}

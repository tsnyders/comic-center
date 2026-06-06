/// Base class for all source filters.
sealed class SourceFilter {
  const SourceFilter({required this.name});
  final String name;
}

class TextFilter extends SourceFilter {
  const TextFilter({required super.name, this.value = ''});
  final String value;
}

class SelectFilter extends SourceFilter {
  const SelectFilter({
    required super.name,
    required this.options,
    this.selectedIndex = 0,
  });
  final List<String> options;
  final int selectedIndex;
}

class TriStateFilter extends SourceFilter {
  const TriStateFilter({required super.name, this.state = TriState.ignore});
  final TriState state;
}

enum TriState { ignore, include, exclude }

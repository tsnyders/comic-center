/// Base class for all source filters. Filters are immutable; the `with*`
/// helpers return an updated copy so the filter sheet can edit a draft list.
sealed class SourceFilter {
  const SourceFilter({required this.name});
  final String name;
}

class TextFilter extends SourceFilter {
  const TextFilter({required super.name, this.value = ''});
  final String value;

  TextFilter withValue(String value) => TextFilter(name: name, value: value);
}

class SelectFilter extends SourceFilter {
  const SelectFilter({
    required super.name,
    required this.options,
    this.values,
    this.selectedIndex = 0,
  });
  final List<String> options;

  /// Source-native value per option; defaults to the option label.
  final List<String>? values;
  final int selectedIndex;

  String get value => (values ?? options)[selectedIndex];

  SelectFilter withIndex(int index) => SelectFilter(
      name: name, options: options, values: values, selectedIndex: index);
}

class TriStateFilter extends SourceFilter {
  const TriStateFilter({
    required super.name,
    String? value,
    this.state = TriState.ignore,
  }) : _value = value;
  final String? _value;
  final TriState state;

  /// Source-native value; defaults to [name].
  String get value => _value ?? name;

  TriStateFilter withState(TriState state) =>
      TriStateFilter(name: name, value: _value, state: state);
}

class SortFilter extends SourceFilter {
  const SortFilter({
    required super.name,
    required this.options,
    this.values,
    this.selectedIndex = 0,
    this.ascending = false,
    this.directional = true,
  });
  final List<String> options;
  final List<String>? values;
  final int selectedIndex;
  final bool ascending;

  /// False when the source has no asc/desc switch for its sort keys.
  final bool directional;

  String get value => (values ?? options)[selectedIndex];

  SortFilter withIndex(int index) => _copy(selectedIndex: index);
  SortFilter withAscending(bool ascending) => _copy(ascending: ascending);

  SortFilter _copy({int? selectedIndex, bool? ascending}) => SortFilter(
        name: name,
        options: options,
        values: values,
        selectedIndex: selectedIndex ?? this.selectedIndex,
        ascending: ascending ?? this.ascending,
        directional: directional,
      );
}

/// A named set of [TriStateFilter]s (tags, statuses, ratings).
class GroupFilter extends SourceFilter {
  const GroupFilter({
    required super.name,
    required this.items,
    this.excludable = true,
  });
  final List<TriStateFilter> items;

  /// False when the source only supports "include" (no exclude state).
  final bool excludable;

  Iterable<String> get included =>
      items.where((i) => i.state == TriState.include).map((i) => i.value);
  Iterable<String> get excluded =>
      items.where((i) => i.state == TriState.exclude).map((i) => i.value);

  GroupFilter withItem(int index, TriStateFilter item) => GroupFilter(
        name: name,
        items: [...items]..[index] = item,
        excludable: excludable,
      );
}

enum TriState { ignore, include, exclude }

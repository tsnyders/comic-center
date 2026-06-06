import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

/// Overridden in [main.dart] via [ProviderScope.overrides] after Isar
/// has been initialised asynchronously.
final isarProvider = Provider<Isar>(
  (_) => throw UnimplementedError('isarProvider must be overridden in main()'),
);

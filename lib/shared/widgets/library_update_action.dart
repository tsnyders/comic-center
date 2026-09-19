import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/library_update_provider.dart';
import 'text_action.dart';

/// "Update library" header action; reads "3/42" while an update runs.
class LibraryUpdateAction extends ConsumerWidget {
  const LibraryUpdateAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(libraryUpdateProvider);
    return TextAction(
      label:
          progress == null ? 'Update library' : '${progress.$1}/${progress.$2}',
      onTap: progress == null
          ? () => ref.read(libraryUpdateProvider.notifier).run()
          : null,
    );
  }
}

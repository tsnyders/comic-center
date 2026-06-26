import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/root/root_scaffold.dart';

class YomiApp extends ConsumerWidget {
  const YomiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);

    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );

    return CupertinoApp(
      title: 'Yomi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.cupertino(brightness),
      home: const RootScaffold(),
    );
  }
}

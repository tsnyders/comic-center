import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/download_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/device_profile.dart';
import 'core/services/widget_service.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/yomi_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/root/root_scaffold.dart';
import 'shared/widgets/sumi.dart';

class YomiApp extends ConsumerWidget {
  const YomiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(yomiThemeProvider);
    final onboarded = ref.watch(onboardingDoneProvider);

    // Initialize widget service so it listens to library updates
    ref.watch(widgetServiceProvider);
    // Keep the exact two-minute completed-download cleanup timer alive while
    // the UI process is running. WorkManager provides the closed-app fallback.
    ref.watch(downloadManagerProvider);

    SystemChrome.setSystemUIOverlayStyle(
      theme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    // Theme / accent change: every colour crossfades over --dur-base (260ms)
    // with no layout movement. The tween lerps the six roles and the scope
    // publishes the in-between values to `context.yc`.
    return TweenAnimationBuilder<YomiColors>(
      tween: YomiColorsTween(end: theme.colors),
      duration:
          DeviceProfile.current.reducedMotion ? Duration.zero : AppMotion.base,
      curve: AppMotion.snap,
      builder: (context, colors, _) => YomiThemeScope(
        theme: theme,
        colors: colors,
        child: CupertinoApp(
          title: 'Yomi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.cupertino(theme, colors),
          // Washi grain sits over every route, pointer-transparent.
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [child ?? const SizedBox.shrink(), const WashiGrain()],
          ),
          home: onboarded ? const RootScaffold() : const OnboardingScreen(),
        ),
      ),
    );
  }
}

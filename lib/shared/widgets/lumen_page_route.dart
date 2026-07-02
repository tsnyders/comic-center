import 'package:flutter/cupertino.dart';

import '../../core/services/device_profile.dart';

/// LUMEN page transition — the incoming page fades and rises a few percent
/// while shared-element Heroes (e.g. a cover) fly over the top. Calmer and more
/// cinematic than the default iOS slide; pairs with the cover Hero rather than
/// competing with it.
///
/// On reduced-motion devices the route cuts straight to the destination:
/// the 420ms fade/slide (plus the Hero flight it hosts) is the single most
/// visible source of dropped frames on budget hardware, because it composites
/// both full screens simultaneously while the destination is still loading
/// its images.
class LumenPageRoute<T> extends PageRouteBuilder<T> {
  LumenPageRoute({required WidgetBuilder builder, super.fullscreenDialog})
      : super(
          transitionDuration: DeviceProfile.current.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 420),
          reverseTransitionDuration: DeviceProfile.current.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            if (DeviceProfile.current.reducedMotion) return child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.2, 0.8, 0.2, 1.0),
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

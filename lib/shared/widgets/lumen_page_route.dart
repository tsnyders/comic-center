import 'package:flutter/cupertino.dart';

/// LUMEN page transition — the incoming page fades and rises a few percent
/// while shared-element Heroes (e.g. a cover) fly over the top. Calmer and more
/// cinematic than the default iOS slide; pairs with the cover Hero rather than
/// competing with it.
class LumenPageRoute<T> extends PageRouteBuilder<T> {
  LumenPageRoute({required WidgetBuilder builder, super.fullscreenDialog})
      : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
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

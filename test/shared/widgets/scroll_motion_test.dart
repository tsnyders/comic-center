import 'package:cached_network_image/cached_network_image.dart';
import 'package:comic_center/core/services/device_profile.dart';
import 'package:comic_center/core/theme/app_spacing.dart';
import 'package:comic_center/shared/widgets/cover_image.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: const MediaQueryData(), child: child),
      );
}

void main() {
  late DeviceProfile previousProfile;
  setUp(() {
    previousProfile = DeviceProfile.current;
    DeviceProfile.current =
        const DeviceProfile(reducedMotion: false, lowSpec: false);
  });
  tearDown(() => DeviceProfile.current = previousProfile);

  testWidgets('unmount cancels a delayed entrance without retaining its timer',
      (tester) async {
    await tester.pumpWidget(const _Frame(
      child: SumiRise(delay: Duration(minutes: 1), child: Text('Delayed')),
    ));
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    // Flutter's test teardown also asserts that no delayed timer remains.
  });

  testWidgets('a new entrance trigger cancels the previous delayed start',
      (tester) async {
    Widget entrance(int trigger) => _Frame(
          child: SumiRise(
            trigger: trigger,
            delay: const Duration(seconds: 1),
            child: const Text('Delayed'),
          ),
        );
    await tester.pumpWidget(entrance(0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(entrance(1));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('only the first six items retain the entrance animation',
      (tester) async {
    await tester.pumpWidget(_Frame(
      child: Column(children: [
        for (var i = 0; i < 20; i++)
          SumiStagger(index: i, child: Text('Item $i')),
      ]),
    ));
    expect(find.byType(SumiRise), findsNWidgets(6));
    final firstFade =
        find.ancestor(of: find.text('Item 0'), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(firstFade).opacity, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(firstFade).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(firstFade).opacity, lessThan(1));
    for (var i = AppMotion.staggerMax; i < 20; i++) {
      expect(
          find.ancestor(
              of: find.text('Item $i'), matching: find.byType(SumiRise)),
          findsNothing);
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('items at and beyond the cap render immediately without a ticker',
      (tester) async {
    await tester.pumpWidget(const _Frame(
        child: Column(children: [
      SumiStagger(index: 6, child: Text('Cap')),
      SumiStagger(index: 150, child: Text('Later chapter')),
    ])));
    expect(find.byType(SumiRise), findsNothing);
    expect(find.byType(AnimatedBuilder), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('Later chapter').hitTestable(), findsOneWidget);
  });

  testWidgets('scrolling later rows into view does not start entrance fades',
      (tester) async {
    await tester.pumpWidget(_Frame(
        child: ListView.builder(
      itemExtent: 60,
      itemCount: 100,
      itemBuilder: (_, i) => SumiStagger(index: i, child: Text('Chapter $i')),
    )));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    expect(find.byType(SumiRise), findsNothing);
  });

  testWidgets('reduced motion skips even the initial stagger', (tester) async {
    await tester.pumpWidget(const _Frame(
        child: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: SumiStagger(index: 0, child: Text('Immediate')),
    )));
    expect(find.byType(SumiRise), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('twenty loading covers have at most four repeating tickers',
      (tester) async {
    await tester.pumpWidget(_loadingCovers(20));
    expect(find.byType(AnimatedBuilder), findsNWidgets(4));
    expect(tester.binding.transientCallbackCount, 4);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('loading-19')),
            matching: find.byType(AnimatedBuilder)),
        findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 4);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    // Finishing/removing earlier loads returns slots to later loads.
    await tester.pumpWidget(_loadingCovers(4));
    expect(find.byType(AnimatedBuilder), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('loading covers honour system and device reduced motion',
      (tester) async {
    await tester.pumpWidget(_loadingCovers(20, disableAnimations: true));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(AnimatedBuilder), findsNothing);
    DeviceProfile.current =
        const DeviceProfile(reducedMotion: true, lowSpec: false);
    await tester.pumpWidget(_loadingCovers(20));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(AnimatedBuilder), findsNothing);
  });
}

// Build the actual loading builder, without HTTP/cache timing in widget tests.
Widget _loadingCovers(int count, {bool disableAnimations = false}) => _Frame(
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(builder: (context) {
          final image = const CoverImage(url: 'https://example.test/cover.jpg')
              .build(context) as CachedNetworkImage;
          return Column(children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                key: ValueKey('loading-$i'),
                height: 20,
                width: 20,
                child: image.placeholder!(context, image.imageUrl),
              ),
          ]);
        }),
      ),
    );

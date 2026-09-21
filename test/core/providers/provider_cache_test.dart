import 'package:comic_center/core/providers/provider_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('count eviction keeps only three unwatched provider states',
      (tester) async {
    final cache = ProviderCache(maximumEntries: 3);
    final disposed = <int>[];
    final provider = Provider.autoDispose.family<int, int>((ref, key) {
      cache.keepAlive(ref, const Duration(minutes: 2));
      ref.onDispose(() => disposed.add(key));
      return key;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (var i = 0; i < 20; i++) {
      final subscription = container.listen(provider(i), (_, __) {});
      subscription.close();
      await tester.pump(Duration.zero);
    }
    expect(disposed, List.generate(17, (i) => i));
    expect(container.getAllProviderElements(), hasLength(3));
    await tester.pump(const Duration(minutes: 2));
    await tester.pump(Duration.zero);
    expect(container.getAllProviderElements(), isEmpty);
  });

  testWidgets('eviction and TTL do not dispose current or prefetched chapters',
      (tester) async {
    final cache = ProviderCache(maximumEntries: 3);
    final provider = Provider.autoDispose.family<int, int>((ref, key) {
      cache.keepAlive(ref, const Duration(minutes: 2));
      return key;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final current = container.listen(provider(0), (_, __) {});
    final next = container.listen(provider(1), (_, __) {});
    for (var i = 2; i < 10; i++) {
      container.listen(provider(i), (_, __) {}).close();
      await tester.pump(Duration.zero);
    }
    expect(container.exists(provider(0)), isTrue);
    expect(container.exists(provider(1)), isTrue);
    expect(container.getAllProviderElements(), hasLength(5));
    await tester.pump(const Duration(minutes: 2));
    await tester.pump(Duration.zero);
    expect(container.getAllProviderElements(), hasLength(2));
    current.close();
    next.close();
    await tester.pump(Duration.zero);
    expect(container.getAllProviderElements(), isEmpty);
  });

  testWidgets('invalidation removes its slot and pending expiry timer',
      (tester) async {
    final cache = ProviderCache(maximumEntries: 2);
    var builds = 0;
    final provider = Provider.autoDispose.family<int, int>((ref, key) {
      cache.keepAlive(ref, const Duration(minutes: 2));
      return ++builds;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(provider(0), (_, __) {}).close();
    await tester.pump(Duration.zero);
    container.invalidate(provider(0));
    await tester.pump(Duration.zero);
    container.listen(provider(1), (_, __) {}).close();
    container.listen(provider(2), (_, __) {}).close();
    await tester.pump(Duration.zero);
    expect(container.exists(provider(0)), isFalse);
    expect(container.exists(provider(1)), isTrue);
    expect(container.exists(provider(2)), isTrue);
    expect(builds, 3);
    container.dispose();
    // A disposed container must not leave the two-minute timers pending.
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TTL caching for autoDispose providers.
///
/// `autoDispose` alone means "drop the state as soon as nobody is listening" —
/// which fixes unbounded growth but forces a refetch on every screen visit.
/// [cacheFor] keeps the state alive for a bounded window after it is created,
/// so navigating away and back within the TTL is instant and free of network
/// traffic, while stale data still ages out and memory stays bounded.
extension CacheFor on Ref<Object?> {
  /// Keep this provider's state alive for [duration] from the moment it was
  /// built, even with no listeners. After the TTL the normal autoDispose
  /// behaviour resumes (disposed immediately if unwatched, or on the next
  /// listener removal).
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

/// A count and TTL bound shared by one provider family in a ProviderContainer.
/// Releasing a keep-alive link never disposes a provider with active listeners.
class ProviderCache {
  ProviderCache({required this.maximumEntries}) : assert(maximumEntries > 0);

  final int maximumEntries;
  final _entries = <KeepAliveLink, Timer>{};

  void keepAlive(Ref<Object?> ref, Duration duration) {
    final link = ref.keepAlive();
    _entries[link] = Timer(duration, () => _release(link));
    ref.onDispose(() => _release(link));
    while (_entries.length > maximumEntries) {
      _release(_entries.keys.first);
    }
  }

  void _release(KeepAliveLink link) {
    _entries.remove(link)?.cancel();
    link.close();
  }
}

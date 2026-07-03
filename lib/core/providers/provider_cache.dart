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

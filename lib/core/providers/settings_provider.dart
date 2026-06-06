import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DownloadLocation { local, googleDrive }

/// Persists only for the current session. The user selects their preferred
/// download destination in Settings; it defaults to on-device storage.
final downloadLocationProvider =
    StateProvider<DownloadLocation>((_) => DownloadLocation.local);

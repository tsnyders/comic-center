import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DownloadLocation { local, googleDrive }

final downloadLocationProvider =
    StateProvider<DownloadLocation>((_) => DownloadLocation.local);

// Controls app-wide brightness. Defaults to dark.
final brightnessProvider = StateProvider<Brightness>((_) => Brightness.dark);

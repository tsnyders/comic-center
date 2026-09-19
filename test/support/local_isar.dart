import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar/isar.dart';

/// Points Isar at the native library bundled with `isar_flutter_libs` so
/// `flutter test` can open a real database on the host without a download.
Future<void> initializeLocalIsar() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final decoded =
      jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages = decoded['packages'] as List<dynamic>;
  final libs = packages.cast<Map<String, dynamic>>().firstWhere(
        (package) => package['name'] == 'isar_flutter_libs',
      );
  final root = config.uri.resolve(libs['rootUri'] as String).toFilePath();
  final library = Platform.isWindows
      ? File('$root/windows/isar.dll')
      : Platform.isLinux
          ? File('$root/linux/libisar.so')
          : File('$root/macos/libisar.dylib');
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}

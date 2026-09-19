import 'dart:io';

import 'package:comic_center/features/settings/backup_restore_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/services/tachiyomi_backup_test.dart' show backupFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final calls = <MethodCall>[];
  String? selected;
  setUp(() async {
    calls.clear();
    selected = null;
    dir = await Directory.systemTemp.createTemp('yomi_picker_test_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path);
    messenger.setMockMethodCallHandler(const MethodChannel('yomi/platform'),
        (call) async {
      calls.add(call);
      return selected;
    });
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(
          child: CupertinoApp(home: BackupRestoreScreen())));
      for (var i = 0;
          i < 50 &&
              find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
      'restore offers all three sources and cancel keeps library untouched',
      (tester) async {
    await open(tester);
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('System storage'), findsOneWidget);
    await tester.tap(find.text('Import from Tachiyomi'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'pickBackup');
    expect(calls.single.arguments, {'tachiyomi': true});
    expect(find.text('Import backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system storage uses the general file picker', (tester) async {
    await open(tester);
    await tester.tap(find.text('System storage'));
    await tester.pumpAndSettle();
    expect(calls.single.arguments, {'tachiyomi': false});
  });

  testWidgets(
      'Tachiyomi preview shows counts and cancelling cleans temporary file',
      (tester) async {
    final file = File('${dir.path}/selected.backup');
    await tester.runAsync(
        () => file.writeAsBytes(backupFixture(sourceName: 'Missing source')));
    selected = file.path;
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import from Tachiyomi'));
      // Wait for the file read and background decode to reach the preview.
      for (var i = 0;
          i < 50 && find.text('Import backup').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    // The import activity indicator intentionally stays active behind preview.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import backup'), findsOneWidget);
    expect(find.textContaining('1 titles'), findsOneWidget);
    expect(find.textContaining('Missing source'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 50 && await file.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(await tester.runAsync(file.exists), false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid file reports an error before offering import',
      (tester) async {
    final file = File('${dir.path}/invalid.backup');
    await tester.runAsync(() => file.writeAsString('not a backup'));
    selected = file.path;
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import from Tachiyomi'));
      for (var i = 0;
          i < 50 && find.text('Could not restore').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Could not restore'), findsOneWidget);
    expect(find.text('Import backup'), findsNothing);
    expect(await tester.runAsync(file.exists), false);
  });
}

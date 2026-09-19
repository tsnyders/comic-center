import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'app_logger.dart';
import 'backup_service.dart';
import 'google_drive_service.dart';

const autoBackupTask = 'yomi.backup.auto';
const _autoBackupWork = 'yomi-backup-auto';

/// Scheduled backups: an Android WorkManager periodic task that exports the
/// library, keeps the newest three local files and uploads to Drive when an
/// account is connected. [runScheduled] executes in the download background
/// isolate, which hands it an open [Isar]; SharedPreferences is opened by
/// [BackupService] itself.
abstract final class BackupScheduler {
  /// Registers the periodic task every [frequency], or cancels it when null.
  static Future<void> apply(Duration? frequency) async {
    if (!Platform.isAndroid) return;
    if (frequency == null) {
      await Workmanager().cancelByUniqueName(_autoBackupWork);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _autoBackupWork,
      autoBackupTask,
      frequency: frequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(requiresBatteryNotLow: true),
    );
  }

  /// Task body. Returns false so WorkManager retries when the export fails;
  /// a failed Drive upload is logged and retried at the next period.
  static Future<bool> runScheduled(Isar isar) async {
    final docs = await getApplicationDocumentsDirectory();
    // Mirrors _CategoryStore in library_provider.dart, which is private.
    final categoriesFile = File('${docs.path}/yomi_categories.json');
    final categories = await categoriesFile.exists()
        ? (jsonDecode(await categoriesFile.readAsString()) as List)
            .cast<String>()
        : <String>[];
    final backup =
        await BackupService.export(isar: isar, categories: categories);
    await BackupService.prune();
    try {
      if (await GoogleDriveService.signInSilently() != null) {
        await GoogleDriveService.uploadBackup(backup.file);
      }
    } catch (error, stackTrace) {
      AppLogger.instance
          .error('Scheduled backup: Drive upload failed', error, stackTrace);
    }
    return true;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../database/models/manga_entry.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/yomi_theme.dart';

const _widgetPayloadKey = 'yomi_widget_payload';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  final service = WidgetService();

  void push(AsyncValue<List<MangaEntry>> library, YomiTheme theme) {
    final mangas = library.valueOrNull;
    if (mangas != null) unawaited(service.updateWidgets(theme, mangas));
  }

  ref.listen(
    libraryStreamProvider,
    (_, next) => push(next, ref.read(yomiThemeProvider)),
    fireImmediately: true,
  );
  ref.listen(
    yomiThemeProvider,
    (_, next) => push(ref.read(libraryStreamProvider), next),
  );

  return service;
});

/// Builds the complete, platform-neutral home-widget payload.
///
/// Keeping this pure makes the theme resolution and manga mapping testable
/// without invoking a platform channel.
Map<String, Object?> buildWidgetPayload(
  YomiTheme theme,
  List<MangaEntry> mangas,
) {
  final colors = theme.colors;
  // ponytail: derive this ceiling from launcher capacity if the widget gains
  // a paged large-screen collection instead of a bounded recent shelf.
  final recent = mangas.take(12).map(_libraryMangaPayload).toList();
  final read = mangas.where((manga) => manga.lastReadAt != null).toList()
    ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));

  return {
    'look': theme.look.name,
    'dark': theme.isDark,
    'bg': colors.bg.toARGB32(),
    'card': colors.card.toARGB32(),
    'fg': colors.fg.toARGB32(),
    'fg2': colors.fg2.toARGB32(),
    'line': colors.line.toARGB32(),
    'ac': colors.ac.toARGB32(),
    'onAc': colors.onAccent.toARGB32(),
    'mangas': recent,
    'continueReading':
        read.isEmpty ? null : _continueReadingPayload(read.first),
  };
}

Map<String, Object?> _libraryMangaPayload(MangaEntry manga) => {
      'id': manga.id,
      'title': manga.title,
      'coverUrl': manga.coverUrl,
      'unreadCount': manga.unreadCount,
      'sourceId': manga.sourceId,
    };

Map<String, Object?> _continueReadingPayload(MangaEntry manga) => {
      'id': manga.id,
      'title': manga.title,
      'coverUrl': manga.coverUrl,
      'lastReadChapterNumber': manga.lastReadChapterNumber,
      'lastReadPage': manga.lastReadPage,
      'unreadCount': manga.unreadCount,
    };

class WidgetService {
  static const _libraryWidgetName = 'LibraryWidgetProvider';
  static const _continueReadingWidgetName = 'ContinueReadingWidgetProvider';

  Future<void> _writes = Future<void>.value();

  Future<void> updateWidgets(YomiTheme theme, List<MangaEntry> mangas) {
    final encoded = jsonEncode(buildWidgetPayload(theme, mangas));
    _writes = _writes.then((_) async {
      await HomeWidget.saveWidgetData<String>(_widgetPayloadKey, encoded);
      await Future.wait([
        HomeWidget.updateWidget(androidName: _libraryWidgetName),
        HomeWidget.updateWidget(androidName: _continueReadingWidgetName),
      ]);
    });
    return _writes;
  }
}

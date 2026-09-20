import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/services/widget_service.dart';
import 'package:comic_center/core/theme/yomi_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildWidgetPayload maps the resolved theme and manga state', () {
    final recent = MangaEntry()
      ..id = 7
      ..title = 'Recent title'
      ..sourceId = 'source'
      ..sourceMangaId = 'recent'
      ..sourceKey = 'source::recent'
      ..sourceUrl = 'https://example.test/recent'
      ..coverUrl = 'https://example.test/recent.jpg'
      ..unreadCount = 3;
    final reading = MangaEntry()
      ..id = 9
      ..title = 'Reading title'
      ..sourceId = 'source'
      ..sourceMangaId = 'reading'
      ..sourceKey = 'source::reading'
      ..sourceUrl = 'https://example.test/reading'
      ..lastReadAt = DateTime.utc(2026, 9, 20)
      ..lastReadChapterNumber = 12.5
      ..lastReadPage = 4
      ..unreadCount = 2;
    const theme = YomiTheme(
      look: YomiLook.pastel,
      mode: Brightness.dark,
      accentIndex: 2,
    );

    final payload = buildWidgetPayload(theme, [recent, reading]);

    expect(payload, containsPair('look', 'pastel'));
    expect(payload, containsPair('dark', true));
    expect(payload, containsPair('bg', theme.colors.bg.toARGB32()));
    expect(payload, containsPair('card', theme.colors.card.toARGB32()));
    expect(payload, containsPair('fg', theme.colors.fg.toARGB32()));
    expect(payload, containsPair('fg2', theme.colors.fg2.toARGB32()));
    expect(payload, containsPair('line', theme.colors.line.toARGB32()));
    expect(payload, containsPair('ac', theme.colors.ac.toARGB32()));

    final mangas = payload['mangas']! as List<Map<String, Object?>>;
    expect(mangas.first, {
      'id': 7,
      'title': 'Recent title',
      'coverUrl': 'https://example.test/recent.jpg',
      'unreadCount': 3,
      'sourceId': 'source',
    });
    expect(payload['continueReading'], {
      'id': 9,
      'title': 'Reading title',
      'coverUrl': null,
      'lastReadChapterNumber': 12.5,
      'lastReadPage': 4,
      'unreadCount': 2,
    });
  });
}

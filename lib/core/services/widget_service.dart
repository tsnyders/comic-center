import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../providers/library_provider.dart';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  final service = WidgetService();
  
  // Listen to the library stream to update the widget automatically
  ref.listen(libraryStreamProvider, (previous, next) {
    if (next.hasValue && next.value != null) {
      service.updateWidgets(next.value!);
    }
  });
  
  return service;
});

class WidgetService {
  static const String _libraryWidgetName = 'LibraryWidgetProvider';
  static const String _continueReadingWidgetName = 'ContinueReadingWidgetProvider';
  
  Future<void> updateWidgets(List<dynamic> mangas) async {
    // 1. Recently Updated (Top 3)
    final recentMangas = mangas.take(3).toList();
    
    final List<Map<String, dynamic>> widgetData = recentMangas.map((m) {
      return {
        'id': m.id,
        'title': m.title,
        'coverUrl': m.coverUrl,
        'unreadCount': m.unreadCount,
        'sourceId': m.sourceId,
      };
    }).toList();
    
    await HomeWidget.saveWidgetData<String>('recently_updated_mangas', jsonEncode(widgetData));
    await HomeWidget.updateWidget(androidName: _libraryWidgetName);

    // 2. Continue Reading
    final readMangas = mangas.where((m) => m.lastReadAt != null).toList();
    if (readMangas.isNotEmpty) {
      readMangas.sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));
      final lastRead = readMangas.first;
      
      final Map<String, dynamic> continueReadingData = {
        'id': lastRead.id,
        'title': lastRead.title,
        'coverUrl': lastRead.coverUrl,
        'lastReadChapterNumber': lastRead.lastReadChapterNumber,
      };
      
      await HomeWidget.saveWidgetData<String>('continue_reading_manga', jsonEncode(continueReadingData));
      await HomeWidget.updateWidget(androidName: _continueReadingWidgetName);
    }
  }
}

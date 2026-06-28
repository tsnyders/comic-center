import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../providers/library_provider.dart';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  final service = WidgetService();
  
  // Listen to the library stream to update the widget automatically
  ref.listen(libraryStreamProvider, (previous, next) {
    if (next.hasValue && next.value != null) {
      service.updateRecentlyUpdatedWidget(next.value!);
    }
  });
  
  return service;
});

class WidgetService {
  static const String _androidWidgetName = 'LibraryWidgetProvider';
  
  Future<void> updateRecentlyUpdatedWidget(List<dynamic> mangas) async {
    // Sort by lastUpdatedDesc (should already be sorted by provider, but we take top 4)
    final recentMangas = mangas.take(4).toList();
    
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
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }
}

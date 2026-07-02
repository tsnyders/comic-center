-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-keep class org.conscrypt.** { *; }

# ── Keep rules for R8 (isMinifyEnabled) ──────────────────────────────────────
# Flutter embedding + generated plugin registrant. The Flutter tool injects its
# own rules, but keeping these explicitly guards against edge cases.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# App's own Kotlin components (AppWidgetProviders + RemoteViewsService). These
# are instantiated by the framework by name, and their layouts are referenced
# only from widget-info XML, so keep them and their members intact.
-keep class com.comiccenter.comic_center.** { *; }

# home_widget plugin — invoked reflectively from the widget host process.
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

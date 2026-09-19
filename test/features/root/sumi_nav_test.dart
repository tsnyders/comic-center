import 'package:comic_center/core/theme/yomi_theme.dart';
import 'package:comic_center/features/root/root_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

// Five tabs must fit the narrowest common phone in every look. Release builds
// strip the overflow assert, so an overflow here would ship as clipped labels.
void main() {
  for (final look in YomiLook.values) {
    testWidgets('five tabs fit a 360px $look bar', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final theme = YomiTheme(look: look);
      await tester.pumpWidget(CupertinoApp(
        home: YomiThemeScope(
          theme: theme,
          colors: theme.colors,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SumiNav(index: 2, onTap: (_) {}),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      for (final label in ['Discover', 'Updates', 'Library', 'History',
          'Settings']) {
        expect(
            find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label == label),
            findsOneWidget);
      }
    });
  }
}

import 'package:comic_center/core/browser/browser_challenge_sheet.dart';
import 'package:comic_center/core/theme/yomi_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'challenge sheet renders testable chrome around its browser child',
      (tester) async {
    var cancelled = false;
    const theme = YomiTheme();
    await tester.pumpWidget(
      CupertinoApp(
        home: YomiThemeScope(
          theme: theme,
          colors: theme.colors,
          child: BrowserChallengeSheet(
            onCancel: () => cancelled = true,
            child: const Text('WebView placeholder'),
          ),
        ),
      ),
    );

    expect(find.text('Site check'), findsOneWidget);
    expect(find.text('Complete the check below to continue.'), findsOneWidget);
    expect(find.text('WebView placeholder'), findsOneWidget);
    expect(find.byKey(BrowserChallengeSheet.contentKey), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}

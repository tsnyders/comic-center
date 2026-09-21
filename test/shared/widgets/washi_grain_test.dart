import 'dart:ui' as ui;

import 'package:comic_center/core/theme/yomi_theme.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cached grain preserves the original pixels over light and dark',
      (tester) async {
    const beforeKey = Key('before');
    const afterKey = Key('after');
    const theme = YomiTheme();
    const previousGrain = DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0x00000000),
        backgroundBlendMode: BlendMode.overlay,
        image: DecorationImage(
          image: AssetImage('assets/images/washi_grain.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.35,
          filterQuality: FilterQuality.none,
        ),
      ),
      child: SizedBox.expand(),
    );
    Widget sample(Key key, Widget grain) => RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(fit: StackFit.expand, children: [
              const Row(children: [
                Expanded(child: ColoredBox(color: Color(0xFF0B0B0A))),
                Expanded(child: ColoredBox(color: Color(0xFFF2EDE3))),
              ]),
              grain,
            ]),
          ),
        );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: YomiThemeScope(
        theme: theme,
        colors: theme.colors,
        child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
          sample(beforeKey, previousGrain),
          sample(afterKey, const WashiGrain()),
        ])),
      ),
    ));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/washi_grain.png'),
        tester.element(find.byType(WashiGrain))));
    await tester.pump();
    final pixels = await tester.runAsync(() async {
      final result = <List<int>>[];
      for (final key in [beforeKey, afterKey]) {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        result.add(bytes!.buffer.asUint8List().toList());
        image.dispose();
      }
      return result;
    });
    // More than the two flat backdrop colors: the asset really was decoded.
    final colors = <String>{};
    for (var i = 0; i < pixels!.first.length; i += 4) {
      colors.add(pixels.first.sublist(i, i + 4).join(','));
    }
    expect(colors.length, greaterThan(2));
    var changedBytes = 0;
    for (var i = 0; i < pixels.first.length; i++) {
      if (pixels.first[i] != pixels.last[i]) changedBytes++;
    }
    expect(changedBytes, 0);
  });
}

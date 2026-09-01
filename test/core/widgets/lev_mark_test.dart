import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/widgets/lev_mark.dart';

/// The mark on screen has to be the mark on the launcher icon.
void main() {
  testWidgets('it takes the size it is given', (tester) async {
    await tester.pumpWidget(
      const Center(child: LevMark(size: 28, color: Color(0xFF2E6B78))),
    );

    expect(tester.getSize(find.byType(LevMark)), const Size(28, 28));
  });

  test('small sizes get the heavier micro drawing', () {
    // The two geometries differ in stroke weight, and at 18 or 20 pixels the
    // regular 3.4 stroke thins out until the mark reads as a smudge. The sizes
    // the app actually uses sit on the intended side of the line: the wordmark
    // and the support card are micro, the rail and the splash are not.
    expect(LevMark.isMicro(21), isTrue);
    expect(LevMark.isMicro(28), isFalse);
    expect(LevMark.isMicro(LevMark.microBelow), isFalse);

    expect(LevMark.assetFor(21), endsWith('lev-mark-micro.svg'));
    expect(LevMark.assetFor(28), endsWith('lev-mark.svg'));
  });

  test('both marks are shipped, and are the design\'s own files', () {
    for (final size in [20.0, 30.0]) {
      final file = File(LevMark.assetFor(size));
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

      final svg = file.readAsStringSync();
      // Two open strokes, not one closed outline: the shape of the whole logo
      // is that the paths do not meet. A file with one path, or with a `fill`
      // on the strokes, is not this mark.
      expect(RegExp(r'<path ').allMatches(svg), hasLength(2));
      expect(svg, contains('fill="none"'));
      expect(svg, contains('stroke-linecap="round"'));
      // `currentColor` is what `LevMark`'s colour filter stands in for. A file
      // with a hardcoded stroke colour would still render — tinted — but the
      // next person to swap it in would not know why.
      expect(svg, contains('stroke="currentColor"'));
    }
  });

  test('no Material heart is left anywhere under lib/', () {
    // `Icons.favorite_border` is a *closed* outline; the logo is two open
    // strokes that stop short of meeting. They are near enough to pass a glance
    // and wrong enough to notice beside the launcher icon, which is exactly how
    // this got shipped once already.
    final offences = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('lev_mark.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('Icons.favorite')) {
          offences.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offences, isEmpty, reason: 'use LevMark:\n${offences.join('\n')}');
  });
}

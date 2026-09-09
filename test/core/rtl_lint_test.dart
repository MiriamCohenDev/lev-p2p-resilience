import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A static sweep for the two mistakes that break Hebrew silently.
///
/// Both compile, both look correct in English, and both strand content on the
/// wrong edge under RTL — which is exactly the class of defect that only shows
/// up when someone actually runs the app in Hebrew. The design system's own
/// checklist asks for this sweep; doing it as a test means it happens on every
/// change rather than once.
void main() {
  /// Side-specific padding. `EdgeInsetsDirectional` is the replacement.
  final directionalPadding = RegExp(r'EdgeInsets(\.only|\.fromLTRB)');

  /// Side-specific alignment. `AlignmentDirectional` is the replacement.
  final directionalAlignment =
      RegExp(r'Alignment\.(centerLeft|centerRight|topLeft|topRight|'
          r'bottomLeft|bottomRight)');

  late List<File> sources;

  setUpAll(() {
    sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Generated code is not ours to style, and drift's and the l10n
        // generator's output contains neither layout nor alignment anyway.
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.contains('app_localizations'))
        .toList();
  });

  /// Reports every offending line, not merely the first — a failure that names
  /// one file at a time turns a sweep into a dozen runs.
  void sweep(RegExp pattern, String replacement) {
    final offences = <String>[];

    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A line that has opted out on purpose says so.
        if (line.contains('rtl-ok')) continue;
        if (pattern.hasMatch(line)) {
          offences.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason: 'use $replacement instead, or mark the line `// rtl-ok`:\n'
          '${offences.join('\n')}',
    );
  }

  test('no side-specific padding under lib/', () {
    sweep(directionalPadding, 'EdgeInsetsDirectional');
  });

  test('no side-specific alignment under lib/', () {
    sweep(directionalAlignment, 'AlignmentDirectional');
  });
}

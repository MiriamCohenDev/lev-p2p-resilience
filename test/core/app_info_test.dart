import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/app_info.dart';

void main() {
  String declaredVersion() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);

    expect(declared, isNotNull, reason: 'pubspec.yaml has no version');
    return declared!;
  }

  test('the version shown in Settings matches pubspec.yaml', () {
    // `1.0.0+1` — the half before the `+`.
    expect(AppInfo.version, declaredVersion().split('+').first);
  });

  test('the build number matches pubspec.yaml too', () {
    // Shown beside the version because LEV travels as a file: with no store and
    // no crash reporting, this pair is all a bug report has to name a binary by.
    // A stale number here would make it name the wrong one.
    final parts = declaredVersion().split('+');
    expect(parts, hasLength(2), reason: 'pubspec.yaml version has no +build');
    expect(AppInfo.buildNumber, parts[1]);
  });

  test('the copyable stamp is built from both', () {
    expect(AppInfo.buildStamp, contains(AppInfo.version));
    expect(AppInfo.buildStamp, contains(AppInfo.buildNumber));
  });
}

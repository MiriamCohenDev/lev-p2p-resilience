import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/app_info.dart';

void main() {
  test('the version shown in Settings matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);

    expect(declared, isNotNull, reason: 'pubspec.yaml has no version');

    // `1.0.0+1` — the build number is not shown to the user.
    expect(AppInfo.version, declared!.split('+').first);
  });
}

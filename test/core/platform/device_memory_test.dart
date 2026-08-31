import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/platform/device_memory.dart';

/// These run against the real machine, because there is nothing to mock: the
/// point of the code is that it reads the actual platform, and a test that
/// substituted the platform would only be testing itself.
void main() {
  test('reads a plausible figure on this platform', () {
    final megabytes = totalPhysicalMemoryMb();

    // The host running these tests is a developer machine or CI, both of which
    // have RAM. A null here means the platform branch is broken, not that the
    // machine has none.
    expect(
      megabytes,
      isNotNull,
      reason: 'no RAM figure on ${Platform.operatingSystem}',
    );

    // Bounds rather than a value, because the value is whatever this machine
    // has. They are wide enough to pass anywhere and tight enough to catch the
    // failure that actually happens: a unit mix-up. Reading `/proc/meminfo`'s
    // kilobytes as bytes, or `ullTotalPhys`'s bytes as megabytes, lands orders
    // of magnitude outside this range — and a gate of `minRamMb: 1536` would
    // then either admit every device or reject every device, silently.
    expect(megabytes, greaterThan(256));
    expect(megabytes, lessThan(4 * 1024 * 1024));
  });

  test('is stable across calls', () {
    // Physical RAM does not change while the app runs. If two calls disagree,
    // something is reading available memory rather than total — which would make
    // the min-spec gate depend on what else the user happens to have open.
    expect(totalPhysicalMemoryMb(), totalPhysicalMemoryMb());
  });
}
